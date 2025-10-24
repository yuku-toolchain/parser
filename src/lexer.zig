const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

pub const Lexer = struct {
    source: []const u8,
    position: usize,

    pub fn init(source: []const u8) Lexer {
        return .{
            .source = source,
            .position = 0,
        };
    }

    pub fn nextToken(self: *Lexer) !Token {
        self.skipWhitespace();

        if (self.isAtEnd()) {
            return self.createEmptyToken(TokenType.EOF);
        }

        const current_char = self.currentChar();

        return switch (current_char) {
            '+' => self.scanPlus(),
            '0'...'9' => self.scanNumber(),
            else => self.consumeSingleCharToken(TokenType.Invalid),
        };
    }

    fn scanPlus(self: *Lexer) Token {
        const next_char = self.peekAhead(1);

        return switch (next_char) {
            '+' => self.consumeMultiCharToken(.Increment, 2),
            '=' => self.consumeMultiCharToken(.PlusAssign, 2),
            else => self.consumeSingleCharToken(.Plus),
        };
    }

    fn scanNumber(self: *Lexer) Token {
        const start = self.position;

        self.consumeWhile(std.ascii.isDigit);

        if (self.currentChar() == '.' and
            !self.isAtEndWithOffset(1) and
            std.ascii.isDigit(self.peekAhead(1)))
        {
            self.advanceBy(1);
            self.consumeWhile(std.ascii.isDigit);
        }

        const end = self.position;
        return self.createToken(.NumericLiteral, self.source[start..end], start, end);
    }

    fn skipWhitespace(self: *Lexer) void {
        while (!self.isAtEnd()) {
            const current_char = self.currentChar();
            switch (current_char) {
                ' ', '\t', '\r' => self.advanceBy(1),
                else => break,
            }
        }
    }

    fn consumeSingleCharToken(self: *Lexer, token_type: TokenType) Token {
        const start = self.position;
        self.advanceBy(1);
        const lexeme = self.source[start..self.position];
        return self.createToken(token_type, lexeme, start, self.position);
    }

    fn consumeMultiCharToken(self: *Lexer, token_type: TokenType, length: u8) Token {
        const start = self.position;
        self.advanceBy(length);
        const end = self.position;
        return self.createToken(token_type, self.source[start..end], start, end);
    }

    fn createEmptyToken(self: *Lexer, token_type: TokenType) Token {
        return self.createToken(token_type, "", self.position, self.position);
    }

    fn createToken(self: *Lexer, token_type: TokenType, lexeme: []const u8, start: usize, end: usize) Token {
        _ = self;
        return Token{
            .type = token_type,
            .lexeme = lexeme,
            .span = .{ .start = start, .end = end },
        };
    }

    fn advanceBy(self: *Lexer, offset: u8) void {
        self.position += offset;
    }

    fn currentChar(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.position];
    }

    fn peekAhead(self: *Lexer, offset: u8) u8 {
        if (self.isAtEndWithOffset(offset)) return 0;
        return self.source[self.position + offset];
    }

    fn consumeWhile(self: *Lexer, predicate: fn (u8) bool) void {
        while (!self.isAtEnd() and predicate(self.currentChar())) {
            self.advanceBy(1);
        }
    }

    fn isAtEnd(self: *Lexer) bool {
        return self.position >= self.source.len;
    }

    fn isAtEndWithOffset(self: *Lexer, offset: u8) bool {
        return (self.position + offset) >= self.source.len;
    }
};
