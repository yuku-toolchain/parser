const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const Token = @import("token.zig").Token;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const content = "const";

    var lexer = try Lexer.init(allocator, content);

    var parser = try Parser.init(allocator, &lexer);

    const ast = try parser.parse();

    std.debug.print("{any}", .{ast});
}
