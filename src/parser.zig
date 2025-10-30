const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Lexer = @import("lexer.zig").Lexer;
const AstNode = @import("ast.zig").AstNode;
const Program = @import("ast.zig").Program;

pub const Parser = struct {
    lexer: *Lexer,
    current_token: Token,
    /// expects arena allocator
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, lexer: *Lexer) !Parser {
        return Parser{
            .lexer = lexer,
            .current_token = try lexer.nextToken(),
            .allocator = allocator
        };
    }

    pub fn parse(self: *Parser) !AstNode {
        var body: std.ArrayList(AstNode) = .empty;

        while (self.current_token.type != .EOF) {
            const stmt = try self.parseStatement();
            try body.append(self.allocator, stmt);
        }

        return AstNode{ .program = Program{
            .body = try body.toOwnedSlice(self.allocator),
        } };
    }

    fn parseStatement(self: *Parser) !AstNode {
        return switch (self.current_token.type) {
            else => unreachable,
        };
    }
};
