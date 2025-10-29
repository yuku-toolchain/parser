const std = @import("std");

pub const CodePoint = struct { len: u3, value: u21 };

pub fn codePointAt(str: []const u8, i: usize) CodePoint {
    const len = std.unicode.utf8ByteSequenceLength(str[i]) catch unreachable;
    const codepoint = switch (len) {
        1 => str[i],
        2 => std.unicode.utf8Decode2(.{ str[i], str[i + 1] }),
        3 => std.unicode.utf8Decode3(.{ str[i], str[i + 1], str[i + 2] }),
        4 => std.unicode.utf8Decode4(.{ str[i], str[i + 1], str[i + 2], str[i + 3] }),
        else => unreachable,
    };
    return .{ .len = @intCast(len), .value = codepoint catch unreachable };
}

pub inline fn isOctalDigit(digit: u8) bool {
    return digit >= '0' and digit <= '7';
}
