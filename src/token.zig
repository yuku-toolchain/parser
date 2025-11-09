const std = @import("std");

pub const Mask = struct {
    pub const IsNumericLiteral: u32 = 1 << 12;
};

pub const TokenType = enum(u32) {
    NumericLiteral = 1 | Mask.IsNumericLiteral,
    HexLiteral = 2 | Mask.IsNumericLiteral,
    OctalLiteral = 3 | Mask.IsNumericLiteral,
    BinaryLiteral = 4 | Mask.IsNumericLiteral,
    BigIntLiteral = 5 | Mask.IsNumericLiteral,

    StringLiteral = 6,
    RegexLiteral = 7,

    NoSubstitutionTemplate = 8,
    TemplateHead = 9,
    TemplateMiddle = 10,
    TemplateTail = 11,

    True = 12,
    False = 13,
    NullLiteral = 14,

    Plus = 15, // +
    Minus = 16, // -
    Star = 17, // *
    Slash = 18, // /
    Percent = 19, // %
    Exponent = 20, // **

    Assign = 21, // =
    PlusAssign = 22, // +=
    MinusAssign = 23, // -=
    StarAssign = 24, // *=
    SlashAssign = 25, // /=
    PercentAssign = 26, // %=
    ExponentAssign = 27, // **=

    Increment = 28, // ++
    Decrement = 29, // --

    Equal = 30, // ==
    NotEqual = 31, // !=
    StrictEqual = 32, // ===
    StrictNotEqual = 33, // !==
    LessThan = 34, // <
    GreaterThan = 35, // >
    LessThanEqual = 36, // <=
    GreaterThanEqual = 37, // >=

    LogicalAnd = 38, // &&
    LogicalOr = 39, // ||
    LogicalNot = 40, // !

    BitwiseAnd = 41, // &
    BitwiseOr = 42, // |
    BitwiseXor = 43, // ^
    BitwiseNot = 44, // ~
    LeftShift = 45, // <<
    RightShift = 46, // >>
    UnsignedRightShift = 47, // >>>

    BitwiseAndAssign = 48, // &=
    BitwiseOrAssign = 49, // |=
    BitwiseXorAssign = 50, // ^=
    LeftShiftAssign = 51, // <<=
    RightShiftAssign = 52, // >>=
    UnsignedRightShiftAssign = 53, // >>>=

    NullishCoalescing = 54, // ??
    NullishAssign = 55, // ??=
    LogicalAndAssign = 56, // &&=
    LogicalOrAssign = 57, // ||=
    OptionalChaining = 58, // ?.

    LeftParen = 59, // (
    RightParen = 60, // )
    LeftBrace = 61, // {
    RightBrace = 62, // }
    LeftBracket = 63, // [
    RightBracket = 64, // ]
    Semicolon = 65, // ;
    Comma = 66, // ,
    Dot = 67, // .
    Spread = 68, // ...
    Arrow = 69, // =>
    Question = 70, // ?
    Colon = 71, // :

    If = 72,
    Else = 73,
    Switch = 74,
    Case = 75,
    Default = 76,
    For = 77,
    While = 78,
    Do = 79,
    Break = 80,
    Continue = 81,

    Function = 82,
    Return = 83,
    Async = 84,
    Await = 85,
    Yield = 86,

    Var = 87,
    Let = 88,
    Const = 89,
    Using = 90,

    Class = 91,
    Extends = 92,
    Super = 93,
    Static = 94,
    Enum = 95,
    Public = 96,
    Private = 97,
    Protected = 98,
    Interface = 99,
    Implements = 100,

    Import = 101,
    Export = 102,
    From = 103,
    As = 104,

    Try = 105,
    Catch = 106,
    Finally = 107,
    Throw = 108,

    New = 109,
    This = 110,
    Typeof = 111,
    Instanceof = 112,
    In = 113,
    Of = 114,
    Delete = 115,
    Void = 116,
    With = 117,
    Debugger = 118,

    Identifier = 119,
    PrivateIdentifier = 120,

    EOF = 121, // end of file

    pub fn is(self: TokenType, mask: u32) bool {
        return (@intFromEnum(self) & mask) != 0;
    }
};

pub const Span = struct {
    start: usize,
    end: usize,
};

pub const Token = struct {
    lexeme: []const u8,
    span: Span,
    type: TokenType,

    pub inline fn eof(pos: usize) Token {
        return Token{ .lexeme = "", .span = .{ .start = pos, .end = pos }, .type = .EOF };
    }
};

pub const CommentType = enum {
    SingleLine, // // comment
    MultiLine, // /* comment */
};

pub const Comment = struct {
    content: []const u8,
    span: Span,
    type: CommentType,
};
