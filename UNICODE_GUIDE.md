# Complete Guide: Unicode, Encodings, and ESTree Serialization

## Table of Contents
1. [What is Unicode?](#what-is-unicode)
2. [Character Encodings: UTF-8 vs UTF-16](#character-encodings)
3. [Why JavaScript Uses UTF-16](#why-javascript-uses-utf-16)
4. [Why ESTree Needs UTF-16 Positions](#why-estree-needs-utf-16-positions)
5. [JavaScript String Escape Sequences](#javascript-string-escape-sequences)
6. [What Our Code Does](#what-our-code-does)
7. [Examples](#examples)

---

## What is Unicode?

**Unicode** is a standard that assigns a unique number (called a **code point**) to every character in every writing system.

### Code Points
- Each character has a unique number: U+0041 = 'A', U+4E2D = '中', U+1F600 = '😀'
- Written as `U+` followed by hexadecimal: `U+0041`, `U+202A`, `U+1F600`
- Range: U+0000 to U+10FFFF (about 1.1 million possible characters)

### Examples
```
'A'     → U+0041 (65 decimal)
'中'    → U+4E2D (20013 decimal) 
'😀'    → U+1F600 (128512 decimal)
'‪'    → U+202A (8234 decimal) - Left-to-Right Embedding
```

---

## Character Encodings

**Encoding** = How we represent Unicode code points as bytes in memory/files.

### UTF-8 (8-bit Unicode Transformation Format)

**How it works:**
- Variable-length: 1-4 bytes per character
- ASCII (0-127) = 1 byte (backward compatible!)
- Most common encoding for files/web

**Encoding Rules:**
```
ASCII (U+0000 - U+007F):     1 byte:  0xxxxxxx
Latin-1 (U+0080 - U+07FF):   2 bytes: 110xxxxx 10xxxxxx
CJK (U+0800 - U+FFFF):       3 bytes: 1110xxxx 10xxxxxx 10xxxxxx
Emoji (U+10000 - U+10FFFF):  4 bytes: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
```

**Examples:**
```zig
'A'  → 0x41 (1 byte)
'é'  → 0xC3 0xA9 (2 bytes)
'中' → 0xE4 0xB8 0xAD (3 bytes)
'😀' → 0xF0 0x9F 0x98 0x80 (4 bytes)
```

### UTF-16 (16-bit Unicode Transformation Format)

**How it works:**
- Variable-length: 2 or 4 bytes per character
- Most characters = 2 bytes (one "code unit")
- Rare characters (U+10000+) = 4 bytes (two "code units" = surrogate pair)

**Encoding Rules:**
```
BMP (U+0000 - U+FFFF):       2 bytes: direct code point
Astral (U+10000 - U+10FFFF): 4 bytes: surrogate pair
  High surrogate:  0xD800-0xDBFF
  Low surrogate:   0xDC00-0xDFFF
```

**Examples:**
```zig
'A'  → 0x0041 (2 bytes, 1 code unit)
'中' → 0x4E2D (2 bytes, 1 code unit)
'😀' → 0xD83D 0xDE00 (4 bytes, 2 code units - surrogate pair!)
```

**Key Concept:** UTF-16 counts in "code units" (2-byte chunks), not bytes!

---

## Why JavaScript Uses UTF-16

JavaScript strings are **always UTF-16 internally**:

```javascript
'A'.length        // 1 (1 UTF-16 code unit)
'中'.length       // 1 (1 UTF-16 code unit)
'😀'.length       // 2 (2 UTF-16 code units - surrogate pair!)
```

**Why?**
- Historical: JavaScript was created when UTF-16 was popular
- String operations work on code units, not code points
- `String.prototype.slice()` uses UTF-16 positions

**Example:**
```javascript
const str = 'A中😀';
str.length           // 4 (A=1, 中=1, 😀=2)
str.slice(0, 1)      // 'A'
str.slice(1, 2)      // '中'
str.slice(2, 4)      // '😀' (needs 2 positions!)
```

---

## Why ESTree Needs UTF-16 Positions

**ESTree** is the standard AST format for JavaScript. It must match JavaScript's behavior:

```javascript
// JavaScript source: "('‪')"
// File stored as UTF-8: 7 bytes
// But JavaScript sees it as: 5 UTF-16 code units

const source = "('‪')";
source.length;  // 5 (not 7!)

// ESTree positions must match JavaScript's view:
{
  "start": 0,  // First UTF-16 code unit
  "end": 5     // After last UTF-16 code unit
}
```

**Why?**
- Tools like Babel, ESLint expect UTF-16 positions
- Positions match `String.prototype.slice()`
- Standard compliance

---

## JavaScript String Escape Sequences

When you write a string in JavaScript source code, you can use escape sequences:

### 1. Simple Escapes
```javascript
'\n'  // newline (U+000A)
'\r'  // carriage return (U+000D)
'\t'  // tab (U+0009)
'\\'  // backslash (U+005C)
"'"   // single quote (U+0027)
'"'   // double quote (U+0022)
```

### 2. Octal Escapes (deprecated, but still supported)
```javascript
'\211'  // Octal 211 = decimal 137 = U+0089
'\0'    // Null character (U+0000)
'\377'  // Octal 377 = decimal 255 = U+00FF
```

**Rules:**
- `\0` = null if not followed by digit
- `\0-7` = octal escape (1-3 digits)
- Max 3 digits if first is 0-3, else max 2 digits

### 3. Hexadecimal Escapes
```javascript
'\x41'  // U+0041 = 'A'
'\xFF'  // U+00FF = 'ÿ'
'\x89'  // U+0089 = control character
```

**Format:** `\x` followed by exactly 2 hex digits

### 4. Unicode Escapes
```javascript
'\u0041'     // U+0041 = 'A' (4 hex digits)
'\u4E2D'     // U+4E2D = '中' (4 hex digits)
'\u{1F600}'  // U+1F600 = '😀' (1-6 hex digits in braces)
'\u{41}'     // U+0041 = 'A' (can use braces for short codes)
```

**Format:**
- `\uHHHH` = exactly 4 hex digits
- `\u{H...}` = 1-6 hex digits in braces

### 5. Line Continuation
```javascript
'hello\
world'  // = 'helloworld' (backslash + newline removed)
```

---

## What Our Code Does

### Part 1: UTF-16 Position Mapping

**Problem:** Parser uses byte positions, ESTree needs UTF-16 positions.

**Solution:** Build a lookup table once, convert positions during serialization.

```zig
// File: "('‪')" = 7 bytes
// UTF-8: 28 27 E2 80 AA 27 29
//         (  '  [3-byte char]  '  )

// Build map: byte_pos → utf16_pos
buildUtf16PosMap(source):
  byte_pos 0: '(' → utf16_pos 0
  byte_pos 1: ''' → utf16_pos 1  
  byte_pos 2: start of '‪' → utf16_pos 2
  byte_pos 3: middle of '‪' → utf16_pos 2 (same!)
  byte_pos 4: end of '‪' → utf16_pos 2 (same!)
  byte_pos 5: ''' → utf16_pos 3
  byte_pos 6: ')' → utf16_pos 4
  byte_pos 7: EOF → utf16_pos 5

// When serializing:
span.start = 0 (byte) → pos_map[0] = 0 (UTF-16) ✓
span.end = 7 (byte) → pos_map[7] = 5 (UTF-16) ✓
```

**Code:**
```zig
fn buildUtf16PosMap(allocator, source) ![]u32 {
    var map = try allocator.alloc(u32, source.len + 1);
    var byte_pos: usize = 0;
    var utf16_pos: u32 = 0;

    while (byte_pos < source.len) {
        map[byte_pos] = utf16_pos;
        const len = utf8ByteSequenceLength(source[byte_pos]) catch 1;
        
        // 4-byte sequences = surrogate pair = 2 UTF-16 code units
        utf16_pos += if (len == 4) 2 else 1;
        
        // All bytes in this sequence map to same UTF-16 position
        for (1..len) |i| {
            if (byte_pos + i < source.len) 
                map[byte_pos + i] = utf16_pos;
        }
        byte_pos += len;
    }
    map[source.len] = utf16_pos; // EOF position
    return map;
}
```

### Part 2: Escape Sequence Decoding

**Problem:** JavaScript source has escape sequences, we need actual characters.

**Example:**
```javascript
// Source code: "'\\x41\\u4E2D\\u{1F600}'"
// Raw string:  "\x41\u4E2D\u{1F600}"
// Decoded:     "A中😀"
```

**What we do:**
1. Read escape sequences from source
2. Convert to Unicode code points
3. Encode code points as UTF-8 bytes
4. Store in output buffer

**Code Flow:**
```zig
decodeEscapes(input: "\\x41\\u4E2D", out) {
    i=0: '\\' → escape detected
    i=1: 'x' → hex escape
    i=2-3: '41' → parse hex → U+0041 → encode UTF-8 → append 'A'
    
    i=4: '\\' → escape detected  
    i=5: 'u' → unicode escape
    i=6-9: '4E2D' → parse hex → U+4E2D → encode UTF-8 → append '中'
}
```

**Key Functions:**

1. **parseOctal**: Convert `\211` → code point U+0089
```zig
parseOctal("211", start=0):
  value = 0
  read '2': value = 0*8 + 2 = 2
  read '1': value = 2*8 + 1 = 17
  read '1': value = 17*8 + 1 = 137
  return {value: 137, end: 3}
```

2. **hexVal**: Convert hex digit → number
```zig
hexVal('A') → 10
hexVal('F') → 15
hexVal('9') → 9
hexVal('X') → null (invalid)
```

3. **appendUtf8**: Convert code point → UTF-8 bytes
```zig
appendUtf8(U+0041):  → [0x41] (1 byte)
appendUtf8(U+4E2D):  → [0xE4, 0xB8, 0xAD] (3 bytes)
appendUtf8(U+1F600): → [0xF0, 0x9F, 0x98, 0x80] (4 bytes)
```

---

## Examples

### Example 1: Simple Unicode Character

**Source file:** `('‪')`
```
Bytes (UTF-8): 28 27 E2 80 AA 27 29
                (  '  [3-byte]  '  )
```

**Parser (byte positions):**
```zig
Program: {start: 0, end: 7}  // 7 bytes
Literal: {start: 1, end: 6}  // "'‪'" = 5 bytes
```

**ESTree (UTF-16 positions):**
```json
{
  "program": {"start": 0, "end": 5},  // 5 UTF-16 code units
  "literal": {"start": 1, "end": 4}    // "'‪'" = 3 UTF-16 code units
}
```

**Conversion:**
```zig
pos_map[0] = 0  // '('
pos_map[1] = 1  // '''
pos_map[2] = 2  // start of '‪'
pos_map[3] = 2  // middle of '‪' (same position!)
pos_map[4] = 2  // end of '‪' (same position!)
pos_map[5] = 3  // '''
pos_map[6] = 4  // ')'
pos_map[7] = 5  // EOF

// Serialization:
span.start = 1 → pos_map[1] = 1 ✓
span.end = 6 → pos_map[6] = 4 ✓
```

### Example 2: Octal Escape

**Source:** `('\2111')`
```
Raw in source: "\2111"
              \211 = octal escape
              1 = literal '1'
```

**Decoding:**
```zig
parseOctal("211", start=0):
  '2' → value = 2
  '1' → value = 2*8 + 1 = 17
  '1' → value = 17*8 + 1 = 137
  return {value: 137 (U+0089), end: 3}

appendUtf8(U+0089):
  → [0xC2, 0x89] (2 UTF-8 bytes)

Result: "\u{0089}1" = [0xC2, 0x89, 0x31]
```

**ESTree output:**
```json
{
  "value": "\u{0089}1",  // Decoded string
  "raw": "'\\2111'"      // Original source
}
```

### Example 3: Unicode Escape

**Source:** `('\u4E2D')`
```
Raw: "\u4E2D"
```

**Decoding:**
```zig
decodeEscapes("\u4E2D"):
  '\\' → escape
  'u' → unicode escape
  '4E2D' → parse hex
    4 → cp = 4
    E → cp = 4*16 + 14 = 78
    2 → cp = 78*16 + 2 = 1250
    D → cp = 1250*16 + 13 = 20013 = U+4E2D
  
  appendUtf8(U+4E2D):
    → [0xE4, 0xB8, 0xAD] (3 UTF-8 bytes)
```

**ESTree output:**
```json
{
  "value": "中",  // Decoded character
  "raw": "'\\u4E2D'"
}
```

### Example 4: Emoji (Surrogate Pair)

**Source:** `('😀')`
```
UTF-8 bytes: F0 9F 98 80 (4 bytes)
UTF-16: D83D DE00 (2 code units - surrogate pair!)
```

**Position mapping:**
```zig
byte_pos 0: '(' → utf16_pos 0
byte_pos 1: ''' → utf16_pos 1
byte_pos 2-5: '😀' (4 bytes) → utf16_pos 2,3 (2 code units!)
byte_pos 6: ''' → utf16_pos 4
byte_pos 7: ')' → utf16_pos 5
```

**ESTree:**
```json
{
  "start": 1,  // After quote
  "end": 4     // After emoji (2 UTF-16 positions!)
}
```

### Example 5: Mixed Escapes

**Source:** `"A\\x42\\u0043\\u{44}\\n\\t"`
```
Decoding:
  'A' → U+0041 → 'A'
  '\\x42' → U+0042 → 'B'
  '\\u0043' → U+0043 → 'C'
  '\\u{44}' → U+0044 → 'D'
  '\\n' → U+000A → newline
  '\\t' → U+0009 → tab

Result: "ABCD\n\t"
```

---

## Summary

1. **Unicode**: Universal character set (code points)
2. **UTF-8**: Variable-length encoding (1-4 bytes), used in files
3. **UTF-16**: Variable-length encoding (2-4 bytes), used by JavaScript
4. **Position Conversion**: Byte positions → UTF-16 positions (for ESTree)
5. **Escape Decoding**: `\x41` → U+0041 → UTF-8 bytes → 'A'

**Why we do this:**
- Parser uses bytes (efficient, direct slicing)
- ESTree uses UTF-16 (JavaScript standard)
- Conversion happens once at serialization boundary
- Escape sequences decoded to actual characters

This ensures our parser is efficient internally while producing standard-compliant ESTree output!
