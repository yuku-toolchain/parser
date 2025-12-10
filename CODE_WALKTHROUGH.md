# Code Walkthrough: ESTree Unicode & Escape Handling

This document explains **exactly** what each function does with real examples.

---

## Function 1: `buildUtf16PosMap` - Position Conversion

**Location:** `src/util/utf.zig:56`

**Purpose:** Convert byte positions → UTF-16 code unit positions

**How it works:**

```zig
pub fn buildUtf16PosMap(allocator: std.mem.Allocator, source: []const u8) ![]u32 {
    // Allocate array: one entry per byte + one for EOF
    var map = try allocator.alloc(u32, source.len + 1);
    var byte_pos: usize = 0;      // Current byte position
    var utf16_pos: u32 = 0;       // Current UTF-16 position

    while (byte_pos < source.len) {
        // Map this byte to current UTF-16 position
        map[byte_pos] = utf16_pos;
        
        // How many bytes is this UTF-8 character?
        const len = std.unicode.utf8ByteSequenceLength(source[byte_pos]) catch 1;
        
        // Advance UTF-16 position:
        // - 4-byte sequences = emoji/surrogate pair = 2 UTF-16 code units
        // - Everything else = 1 UTF-16 code unit
        utf16_pos += if (len == 4) 2 else 1;
        
        // All bytes in this multi-byte sequence map to the SAME UTF-16 position
        // Example: '中' = 3 bytes, all map to same position
        for (1..len) |i| {
            if (byte_pos + i < source.len) 
                map[byte_pos + i] = utf16_pos;
        }
        
        // Move to next character
        byte_pos += len;
    }
    
    // EOF position
    map[source.len] = utf16_pos;
    return map;
}
```

**Example: Source = `"('‪')"`**

```
Step-by-step execution:

Initial: byte_pos=0, utf16_pos=0

Iteration 1: byte_pos=0, char='('
  map[0] = 0
  len = 1 (ASCII)
  utf16_pos = 0 + 1 = 1
  byte_pos = 0 + 1 = 1

Iteration 2: byte_pos=1, char='''
  map[1] = 1
  len = 1 (ASCII)
  utf16_pos = 1 + 1 = 2
  byte_pos = 1 + 1 = 2

Iteration 3: byte_pos=2, char='‪' (U+202A)
  map[2] = 2
  len = 3 (3-byte UTF-8: E2 80 AA)
  utf16_pos = 2 + 1 = 3  (not 4-byte, so +1)
  map[3] = 3  (middle byte)
  map[4] = 3  (last byte)
  byte_pos = 2 + 3 = 5

Iteration 4: byte_pos=5, char='''
  map[5] = 3
  len = 1
  utf16_pos = 3 + 1 = 4
  byte_pos = 5 + 1 = 6

Iteration 5: byte_pos=6, char=')'
  map[6] = 4
  len = 1
  utf16_pos = 4 + 1 = 5
  byte_pos = 6 + 1 = 7

Final: map[7] = 5 (EOF)

Result map:
  [0] = 0  // '('
  [1] = 1  // '''
  [2] = 2  // start of '‪'
  [3] = 2  // middle of '‪'
  [4] = 2  // end of '‪'
  [5] = 3  // '''
  [6] = 4  // ')'
  [7] = 5  // EOF
```

**Usage in ESTree:**
```zig
// Parser gives us byte position 1-6 for "'‪'"
span.start = 1  // byte position
span.end = 6    // byte position

// Convert to UTF-16:
fieldPos("start", 1) → pos_map[1] = 1  ✓
fieldPos("end", 6) → pos_map[6] = 4    ✓

// ESTree output:
{"start": 1, "end": 4}  // UTF-16 positions!
```

---

## Function 2: `parseOctal` - Octal Escape Parsing

**Location:** `src/util/utf.zig:38`

**Purpose:** Parse `\211` → code point 137 (U+0089)

**How it works:**

```zig
pub fn parseOctal(input: []const u8, start: usize) struct { value: u21, end: usize } {
    var value: u16 = 0;
    var i = start;
    
    // Max digits: 3 if first digit is 0-3, else 2
    // \377 = max (255), \3777 would be invalid
    const max: usize = if (input[start] <= '3') 3 else 2;
    var count: usize = 0;
    
    while (i < input.len and count < max) : (i += 1) {
        if (input[i] >= '0' and input[i] <= '7') {
            // Base-8 conversion: multiply by 8, add digit
            value = value * 8 + (input[i] - '0');
            count += 1;
        } else break;  // Non-octal digit stops parsing
    }
    
    return .{ .value = value, .end = i };
}
```

**Examples:**

```
Example 1: "\211"
  input = "211", start = 0
  max = 3 (first digit '2' <= '3')
  
  i=0: '2' → value = 0*8 + 2 = 2, count=1
  i=1: '1' → value = 2*8 + 1 = 17, count=2
  i=2: '1' → value = 17*8 + 1 = 137, count=3
  i=3: stop (count == max)
  
  Result: {value: 137 (U+0089), end: 3}

Example 2: "\77"
  input = "77", start = 0
  max = 2 (first digit '7' > '3')
  
  i=0: '7' → value = 0*8 + 7 = 7, count=1
  i=1: '7' → value = 7*8 + 7 = 63, count=2
  i=2: stop (count == max)
  
  Result: {value: 63 (U+003F = '?'), end: 2}

Example 3: "\0"
  input = "0", start = 0
  max = 3
  
  i=0: '0' → value = 0*8 + 0 = 0, count=1
  i=1: stop (next char is not octal or end of input)
  
  Result: {value: 0 (U+0000 = null), end: 1}
```

---

## Function 3: `hexVal` - Hex Digit Conversion

**Location:** `src/util/utf.zig:52`

**Purpose:** Convert hex digit character → number (0-15)

**How it works:**

```zig
pub fn hexVal(c: u8) ?u8 {
    return if (c >= '0' and c <= '9') 
        c - '0'           // '0'-'9' → 0-9
    else if (c >= 'a' and c <= 'f') 
        c - 'a' + 10      // 'a'-'f' → 10-15
    else if (c >= 'A' and c <= 'F') 
        c - 'A' + 10      // 'A'-'F' → 10-15
    else 
        null;             // Invalid hex digit
}
```

**Examples:**

```
hexVal('0') → 0
hexVal('9') → 9
hexVal('A') → 10
hexVal('F') → 15
hexVal('a') → 10
hexVal('f') → 15
hexVal('X') → null (invalid)
hexVal('G') → null (invalid)
```

**Usage in hex escape:**
```zig
// Parse "\x41"
hexVal('4') → 4   (high nibble)
hexVal('1') → 1   (low nibble)
code_point = (4 << 4) | 1 = 64 + 1 = 65 = U+0041 = 'A'
```

---

## Function 4: `decodeEscapes` - Main Escape Decoder

**Location:** `src/js/estree.zig:729`

**Purpose:** Convert escaped string → actual UTF-8 bytes

**How it works:**

```zig
fn decodeEscapes(input: []const u8, out: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    var i: usize = 0;
    
    while (i < input.len) {
        // Normal character (not escaped)
        if (input[i] != '\\') {
            try out.append(allocator, input[i]);
            i += 1;
            continue;
        }

        // Found backslash - process escape sequence
        i += 1;  // Skip backslash
        if (i >= input.len) {
            try out.append(allocator, '\\');  // Lone backslash
            break;
        }

        switch (input[i]) {
            // Simple escapes
            'n' => { try out.append(allocator, '\n'); i += 1; },
            'r' => { try out.append(allocator, '\r'); i += 1; },
            't' => { try out.append(allocator, '\t'); i += 1; },
            'b' => { try out.append(allocator, 0x08); i += 1; },
            'f' => { try out.append(allocator, 0x0C); i += 1; },
            'v' => { try out.append(allocator, 0x0B); i += 1; },
            
            // Octal escape: \0 or \1-7
            '0' => {
                if (i + 1 < input.len and input[i + 1] >= '0' and input[i + 1] <= '9') {
                    // \0 followed by digit = octal escape
                    const r = util.Utf.parseOctal(input, i);
                    try appendUtf8(out, allocator, r.value);
                    i = r.end;
                } else {
                    // \0 alone = null character
                    try out.append(allocator, 0);
                    i += 1;
                }
            },
            '1'...'7' => {
                // \1-\7 = octal escape
                const r = util.Utf.parseOctal(input, i);
                try appendUtf8(out, allocator, r.value);
                i = r.end;
            },
            
            // Hex escape: \xHH
            'x' => {
                i += 1;  // Skip 'x'
                if (i + 2 <= input.len) {
                    if (util.Utf.hexVal(input[i])) |hi| {
                        if (util.Utf.hexVal(input[i + 1])) |lo| {
                            // Valid hex escape
                            const cp = (@as(u21, hi) << 4) | lo;
                            try appendUtf8(out, allocator, cp);
                            i += 2;
                            continue;
                        }
                    }
                }
                // Invalid - output 'x' as literal
                try out.append(allocator, 'x');
            },
            
            // Unicode escape: \uHHHH or \u{H...}
            'u' => {
                i += 1;  // Skip 'u'
                
                if (i < input.len and input[i] == '{') {
                    // \u{H...} format
                    i += 1;  // Skip '{'
                    var cp: u21 = 0;
                    var has_digits = false;
                    
                    // Parse hex digits until '}'
                    while (i < input.len and input[i] != '}') {
                        if (util.Utf.hexVal(input[i])) |d| {
                            cp = (cp << 4) | d;  // Shift left 4 bits, add digit
                            has_digits = true;
                            i += 1;
                        } else break;
                    }
                    
                    if (has_digits and i < input.len and input[i] == '}') {
                        i += 1;  // Skip '}'
                        try appendUtf8(out, allocator, cp);
                    } else {
                        // Invalid - output 'u' as literal
                        try out.append(allocator, 'u');
                    }
                } else if (i + 4 <= input.len) {
                    // \uHHHH format (exactly 4 hex digits)
                    var cp: u21 = 0;
                    var valid = true;
                    
                    for (0..4) |j| {
                        if (util.Utf.hexVal(input[i + j])) |d| {
                            cp = (cp << 4) | d;
                        } else {
                            valid = false;
                            break;
                        }
                    }
                    
                    if (valid) {
                        i += 4;
                        try appendUtf8(out, allocator, cp);
                    } else {
                        try out.append(allocator, 'u');
                    }
                } else {
                    try out.append(allocator, 'u');
                }
            },
            
            // Line continuation: \ followed by newline
            '\r' => {
                i += 1;
                if (i < input.len and input[i] == '\n') i += 1;  // Skip CRLF
            },
            '\n' => i += 1,  // Skip LF
            
            // Identity escape: \' \", etc.
            else => |c| {
                try out.append(allocator, c);
                i += 1;
            },
        }
    }
}
```

**Example: `"A\\x42\\u0043\\n"`**

```
Input: "A\x42\u0043\n"
       A  \x42  \u0043  \n

Step-by-step:

i=0: 'A' → append 'A', i=1
      Output: ['A']

i=1: '\\' → escape detected, i=2
i=2: 'x' → hex escape, i=3
i=3-4: '4', '2' → hexVal('4')=4, hexVal('2')=2
      cp = (4 << 4) | 2 = 64 + 2 = 66 = U+0042 = 'B'
      appendUtf8(U+0042) → append 'B', i=5
      Output: ['A', 'B']

i=5: '\\' → escape detected, i=6
i=6: 'u' → unicode escape, i=7
i=7-10: '0','0','4','3' → parse hex
      cp = 0*16^3 + 0*16^2 + 4*16 + 3 = 67 = U+0043 = 'C'
      appendUtf8(U+0043) → append 'C', i=11
      Output: ['A', 'B', 'C']

i=11: '\\' → escape detected, i=12
i=12: 'n' → newline escape
      append '\n', i=13
      Output: ['A', 'B', 'C', '\n']

Result: "ABC\n"
```

---

## Function 5: `appendUtf8` - Code Point to UTF-8

**Location:** `src/js/estree.zig:850`

**Purpose:** Convert Unicode code point → UTF-8 bytes

**How it works:**

```zig
fn appendUtf8(out: *std.ArrayList(u8), allocator: std.mem.Allocator, cp: u21) !void {
    var buf: [4]u8 = undefined;  // Max UTF-8 sequence is 4 bytes
    
    // Encode code point as UTF-8
    const len = std.unicode.utf8Encode(cp, &buf) catch {
        // Invalid code point → replacement character
        try out.appendSlice(allocator, "\u{FFFD}");
        return;
    };
    
    // Append the UTF-8 bytes
    try out.appendSlice(allocator, buf[0..len]);
}
```

**Examples:**

```
appendUtf8(U+0041 = 'A'):
  utf8Encode → [0x41] (1 byte)
  append [0x41]
  Result: 'A'

appendUtf8(U+4E2D = '中'):
  utf8Encode → [0xE4, 0xB8, 0xAD] (3 bytes)
  append [0xE4, 0xB8, 0xAD]
  Result: '中' (3 UTF-8 bytes)

appendUtf8(U+1F600 = '😀'):
  utf8Encode → [0xF0, 0x9F, 0x98, 0x80] (4 bytes)
  append [0xF0, 0x9F, 0x98, 0x80]
  Result: '😀' (4 UTF-8 bytes)

appendUtf8(U+110000):  // Invalid (max is U+10FFFF)
  utf8Encode fails
  append "\u{FFFD}" (replacement character)
  Result: '�'
```

---

## Function 6: `writeDecodedString` - String Value Serialization

**Location:** `src/js/estree.zig:720`

**Purpose:** Write decoded string value to JSON

**How it works:**

```zig
fn writeDecodedString(self: *Self, s: []const u8) !void {
    // Clear scratch buffer (reused for efficiency)
    self.scratch.clearRetainingCapacity();
    
    // Decode escape sequences → UTF-8 bytes
    try decodeEscapes(s, &self.scratch, self.allocator);
    
    // Write as JSON string: "decoded_value"
    try self.writeByte('"');
    try self.writeJsonEscaped(self.scratch.items);  // Escape JSON special chars
    try self.writeByte('"');
}
```

**Example:**

```
Input: "'\\x41\\u4E2D'"
       (raw string content: "\x41\u4E2D")

Step 1: decodeEscapes("\x41\u4E2D", scratch)
  → scratch = ['A', 0xE4, 0xB8, 0xAD]  (UTF-8 bytes for "A中")

Step 2: writeJsonEscaped(scratch)
  → Escape JSON special characters
  → Output: "A中"

Step 3: Wrap in quotes
  → Final: "A中"

ESTree output:
{
  "value": "A中",      // Decoded
  "raw": "'\\x41\\u4E2D'"  // Original source
}
```

---

## Function 7: `fieldPos` - Position Conversion in ESTree

**Location:** `src/js/estree.zig:588`

**Purpose:** Convert byte position → UTF-16 position when writing ESTree

**How it works:**

```zig
fn fieldPos(self: *Self, key: []const u8, byte_pos: u32) !void {
    try self.field(key);
    
    // Lookup UTF-16 position from pre-built map
    // Clamp to valid range (safety check)
    const utf16_pos = self.pos_map[@min(byte_pos, self.pos_map.len - 1)];
    
    try self.writeInt(utf16_pos);
}
```

**Example:**

```
Source: "('‪')" (7 bytes)
pos_map = [0, 1, 2, 2, 2, 3, 4, 5]

Parser span: {start: 1, end: 6}  // byte positions

Serialization:
  fieldPos("start", 1):
    → pos_map[1] = 1
    → Write: "start": 1
    
  fieldPos("end", 6):
    → pos_map[6] = 4
    → Write: "end": 4

ESTree output:
{
  "start": 1,  // UTF-16 position
  "end": 4     // UTF-16 position
}
```

---

## Complete Flow Example

**Source file:** `test.js` = `"('\\x41\\u4E2D')"`

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: Parsing (byte positions)                          │
└─────────────────────────────────────────────────────────────┘

Lexer reads: 28 27 5C 78 34 31 5C 75 34 45 32 44 27 29
             (  '  \  x  4  1  \  u  4  E  2  D  '  )

Token: StringLiteral
  raw_start = 1
  raw_len = 13
  span = {start: 1, end: 14}  // byte positions

┌─────────────────────────────────────────────────────────────┐
│ Step 2: Build UTF-16 position map                          │
└─────────────────────────────────────────────────────────────┘

Source bytes: 28 27 5C 78 34 31 5C 75 34 45 32 44 27 29
              (  '  \  x  4  1  \  u  4  E  2  D  '  )

pos_map:
  [0] = 0   // '('
  [1] = 1   // '''
  [2] = 2   // '\'
  [3] = 3   // 'x'
  ... (all ASCII, 1:1 mapping)
  [14] = 14 // ')'
  [15] = 15 // EOF

┌─────────────────────────────────────────────────────────────┐
│ Step 3: ESTree serialization                               │
└─────────────────────────────────────────────────────────────┘

writeStringLiteral(span={start:1, end:14}):
  
  raw = source[1..14] = "'\\x41\\u4E2D'"
  
  fieldSpan(span):
    fieldPos("start", 1) → pos_map[1] = 1 → "start": 1
    fieldPos("end", 14) → pos_map[14] = 14 → "end": 14
  
  field("value"):
    writeDecodedString("\\x41\\u4E2D"):
      decodeEscapes("\\x41\\u4E2D"):
        \x41 → U+0041 → appendUtf8 → 'A'
        \u4E2D → U+4E2D → appendUtf8 → '中'
      scratch = "A中"
      writeJsonEscaped → "A中"
      Result: "value": "A中"
  
  fieldString("raw", "'\\x41\\u4E2D'"):
    Result: "raw": "'\\x41\\u4E2D'"

Final ESTree:
{
  "type": "Literal",
  "start": 1,
  "end": 14,
  "value": "A中",
  "raw": "'\\x41\\u4E2D'"
}
```

---

## Key Takeaways

1. **Byte positions** = efficient for parser (direct source slicing)
2. **UTF-16 positions** = required for ESTree (JavaScript standard)
3. **Conversion** = happens once at serialization (lookup table)
4. **Escape decoding** = converts `\x41` → actual character 'A'
5. **UTF-8 encoding** = stores decoded characters as UTF-8 bytes

This design gives us:
- ✅ Fast parsing (no conversion overhead)
- ✅ Standard-compliant ESTree output
- ✅ Correct Unicode handling
- ✅ Proper escape sequence support
