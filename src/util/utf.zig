const std = @import("std");

pub const CodePoint = struct { len: u3, value: u21 };

pub const Utf8Error = error{InvalidUtf8};

pub fn codePointAt(str: []const u8, i: u32) Utf8Error!CodePoint {
    const len = std.unicode.utf8ByteSequenceLength(str[i]) catch return error.InvalidUtf8;
    const codepoint = switch (len) {
        1 => str[i],
        2 => std.unicode.utf8Decode2(.{ str[i], str[i + 1] }),
        3 => std.unicode.utf8Decode3(.{ str[i], str[i + 1], str[i + 2] }),
        4 => std.unicode.utf8Decode4(.{ str[i], str[i + 1], str[i + 2], str[i + 3] }),
        else => unreachable,
    };
    return .{ .len = @intCast(len), .value = codepoint catch return error.InvalidUtf8 };
}

pub fn isOctalDigit(digit: u8) bool {
    return digit >= '0' and digit <= '7';
}

pub fn isMultiByteSpace(cp: u21) bool {
    return switch (cp) {
        '\u{FEFF}',
        '\u{00A0}',
        '\u{2000}',
        '\u{2001}'...'\u{200A}',
        '\u{202F}',
        '\u{205F}',
        '\u{3000}',
        '\u{1680}',
        => true,
        else => false,
    };
}

pub fn parseOctal(input: []const u8, start: usize) struct { value: u21, end: usize } {
    var value: u16 = 0;
    var i = start;
    const max: usize = if (input[start] <= '3') 3 else 2;
    var count: usize = 0;
    while (i < input.len and count < max) : (i += 1) {
        if (input[i] >= '0' and input[i] <= '7') {
            value = value * 8 + (input[i] - '0');
            count += 1;
        } else break;
    }
    return .{ .value = value, .end = i };
}

pub fn hexVal(c: u8) ?u8 {
    return if (c >= '0' and c <= '9') c - '0' else if (c >= 'a' and c <= 'f') c - 'a' + 10 else if (c >= 'A' and c <= 'F') c - 'A' + 10 else null;
}

pub fn buildUtf16PosMap(allocator: std.mem.Allocator, source: []const u8) ![]u32 {
    var map = try allocator.alloc(u32, source.len + 1);
    var byte_pos: usize = 0;
    var utf16_pos: u32 = 0;

    while (byte_pos < source.len) {
        map[byte_pos] = utf16_pos;
        const len = std.unicode.utf8ByteSequenceLength(source[byte_pos]) catch 1;
        utf16_pos += if (len == 4) 2 else 1; // surrogate pair for 4-byte sequences
        for (1..len) |i| {
            if (byte_pos + i < source.len) map[byte_pos + i] = utf16_pos;
        }
        byte_pos += len;
    }
    map[source.len] = utf16_pos;
    return map;
}
