pub const Mask = struct {
    pub const IsNumericLiteral: u32 = 1 << 12;
    pub const IsBinaryOp: u32 = 1 << 13;
    pub const IsLogicalOp: u32 = 1 << 14;
    pub const IsUnaryOp: u32 = 1 << 15;
    pub const IsAssignmentOp: u32 = 1 << 16;
    pub const IsIdentifierLike: u32 = 1 << 17;

    pub const PrecShift: u32 = 7;
    pub const PrecOverlap: u32 = 31;
};

pub const TokenType = enum(u32) {
    NumericLiteral = 1 | Mask.IsNumericLiteral, // e.g., "123", "45.67"
    HexLiteral = 2 | Mask.IsNumericLiteral, // e.g., "0xFF", "0x1A"
    OctalLiteral = 3 | Mask.IsNumericLiteral, // e.g., "0o777", "0o12"
    BinaryLiteral = 4 | Mask.IsNumericLiteral, // e.g., "0b1010", "0b11"
    BigIntLiteral = 5 | Mask.IsNumericLiteral, // e.g., "123n", "456n"

    StringLiteral = 6, // e.g., "'hello'", "\"world\""
    RegexLiteral = 7, // e.g., "/abc/g", "/[0-9]+/i"

    NoSubstitutionTemplate = 8, // e.g., "`hello`"
    TemplateHead = 9, // e.g., "`hello ${"
    TemplateMiddle = 10, // e.g., "} world ${"
    TemplateTail = 11, // e.g., "} end`"

    True = 12 | Mask.IsIdentifierLike, // "true"
    False = 13 | Mask.IsIdentifierLike, // "false"
    NullLiteral = 14 | Mask.IsIdentifierLike, // "null"

    Plus = 15 | (11 << Mask.PrecShift) | Mask.IsBinaryOp | Mask.IsUnaryOp, // "+"
    Minus = 16 | (11 << Mask.PrecShift) | Mask.IsBinaryOp | Mask.IsUnaryOp, // "-"
    Star = 17 | (12 << Mask.PrecShift) | Mask.IsBinaryOp, // "*"
    Slash = 18 | (12 << Mask.PrecShift) | Mask.IsBinaryOp, // "/"
    Percent = 19 | (12 << Mask.PrecShift) | Mask.IsBinaryOp, // "%"
    Exponent = 20 | (13 << Mask.PrecShift) | Mask.IsBinaryOp, // "**"

    Assign = 21 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // "="
    PlusAssign = 22 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // "+="
    MinusAssign = 23 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // "-="
    StarAssign = 24 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // "*="
    SlashAssign = 25 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // "/="
    PercentAssign = 26 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // "%="
    ExponentAssign = 27 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // "**="

    Increment = 28 | (15 << Mask.PrecShift), // "++"
    Decrement = 29 | (15 << Mask.PrecShift), // "--"

    Equal = 30 | (8 << Mask.PrecShift) | Mask.IsBinaryOp, // "=="
    NotEqual = 31 | (8 << Mask.PrecShift) | Mask.IsBinaryOp, // "!="
    StrictEqual = 32 | (8 << Mask.PrecShift) | Mask.IsBinaryOp, // "==="
    StrictNotEqual = 33 | (8 << Mask.PrecShift) | Mask.IsBinaryOp, // "!=="
    LessThan = 34 | (9 << Mask.PrecShift) | Mask.IsBinaryOp, // "<"
    GreaterThan = 35 | (9 << Mask.PrecShift) | Mask.IsBinaryOp, // ">"
    LessThanEqual = 36 | (9 << Mask.PrecShift) | Mask.IsBinaryOp, // "<="
    GreaterThanEqual = 37 | (9 << Mask.PrecShift) | Mask.IsBinaryOp, // ">="

    LogicalAnd = 38 | (4 << Mask.PrecShift) | Mask.IsLogicalOp, // "&&"
    LogicalOr = 39 | (3 << Mask.PrecShift) | Mask.IsLogicalOp, // "||"
    LogicalNot = 40 | (14 << Mask.PrecShift) | Mask.IsUnaryOp, // "!"

    BitwiseAnd = 41 | (7 << Mask.PrecShift) | Mask.IsBinaryOp, // "&"
    BitwiseOr = 42 | (5 << Mask.PrecShift) | Mask.IsBinaryOp, // "|"
    BitwiseXor = 43 | (6 << Mask.PrecShift) | Mask.IsBinaryOp, // "^"
    BitwiseNot = 44 | (14 << Mask.PrecShift) | Mask.IsUnaryOp, // "~"
    LeftShift = 45 | (10 << Mask.PrecShift) | Mask.IsBinaryOp, // "<<"
    RightShift = 46 | (10 << Mask.PrecShift) | Mask.IsBinaryOp, // ">>"
    UnsignedRightShift = 47 | (10 << Mask.PrecShift) | Mask.IsBinaryOp, // ">>>"

    BitwiseAndAssign = 48 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // "&="
    BitwiseOrAssign = 49 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // "|="
    BitwiseXorAssign = 50 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // "^="
    LeftShiftAssign = 51 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // "<<="
    RightShiftAssign = 52 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // ">>="
    UnsignedRightShiftAssign = 53 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // ">>>="

    NullishCoalescing = 54 | (3 << Mask.PrecShift) | Mask.IsLogicalOp, // "??"
    NullishAssign = 55 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // "??="
    LogicalAndAssign = 56 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // "&&="
    LogicalOrAssign = 57 | (2 << Mask.PrecShift) | Mask.IsAssignmentOp, // "||="
    OptionalChaining = 58, // "?."

    LeftParen = 59, // "("
    RightParen = 60, // ")"
    LeftBrace = 61, // "{"
    RightBrace = 62, // "}"
    LeftBracket = 63, // "["
    RightBracket = 64, // "]"
    Semicolon = 65, // ";"
    Comma = 66, // ","
    Dot = 67, // "."
    Spread = 68, // "..."
    Arrow = 69, // "=>"
    Question = 70, // "?"
    Colon = 71, // ":"

    If = 72 | Mask.IsIdentifierLike, // "if"
    Else = 73 | Mask.IsIdentifierLike, // "else"
    Switch = 74 | Mask.IsIdentifierLike, // "switch"
    Case = 75 | Mask.IsIdentifierLike, // "case"
    Default = 76 | Mask.IsIdentifierLike, // "default"
    For = 77 | Mask.IsIdentifierLike, // "for"
    While = 78 | Mask.IsIdentifierLike, // "while"
    Do = 79 | Mask.IsIdentifierLike, // "do"
    Break = 80 | Mask.IsIdentifierLike, // "break"
    Continue = 81 | Mask.IsIdentifierLike, // "continue"

    Function = 82 | Mask.IsIdentifierLike, // "function"
    Return = 83 | Mask.IsIdentifierLike, // "return"
    Async = 84 | Mask.IsIdentifierLike, // "async"
    Await = 85 | Mask.IsIdentifierLike, // "await"
    Yield = 86 | Mask.IsIdentifierLike, // "yield"

    Var = 87 | Mask.IsIdentifierLike, // "var"
    Let = 88 | Mask.IsIdentifierLike, // "let"
    Const = 89 | Mask.IsIdentifierLike, // "const"
    Using = 90 | Mask.IsIdentifierLike, // "using"

    Class = 91 | Mask.IsIdentifierLike, // "class"
    Extends = 92 | Mask.IsIdentifierLike, // "extends"
    Super = 93 | Mask.IsIdentifierLike, // "super"
    Static = 94 | Mask.IsIdentifierLike, // "static"
    Enum = 95 | Mask.IsIdentifierLike, // "enum"
    Public = 96 | Mask.IsIdentifierLike, // "public"
    Private = 97 | Mask.IsIdentifierLike, // "private"
    Protected = 98 | Mask.IsIdentifierLike, // "protected"
    Interface = 99 | Mask.IsIdentifierLike, // "interface"
    Implements = 100 | Mask.IsIdentifierLike, // "implements"

    Import = 101 | Mask.IsIdentifierLike, // "import"
    Export = 102 | Mask.IsIdentifierLike, // "export"
    From = 103 | Mask.IsIdentifierLike, // "from"
    As = 104 | Mask.IsIdentifierLike, // "as"

    Try = 105 | Mask.IsIdentifierLike, // "try"
    Catch = 106 | Mask.IsIdentifierLike, // "catch"
    Finally = 107 | Mask.IsIdentifierLike, // "finally"
    Throw = 108 | Mask.IsIdentifierLike, // "throw"

    New = 109 | Mask.IsIdentifierLike, // "new"
    This = 110 | Mask.IsIdentifierLike, // "this"
    Typeof = 111 | (14 << Mask.PrecShift) | Mask.IsUnaryOp | Mask.IsIdentifierLike, // "typeof"
    Instanceof = 112 | (9 << Mask.PrecShift) | Mask.IsBinaryOp | Mask.IsIdentifierLike, // "instanceof"
    In = 113 | (9 << Mask.PrecShift) | Mask.IsBinaryOp | Mask.IsIdentifierLike, // "in"
    Of = 114 | Mask.IsIdentifierLike, // "of"
    Delete = 115 | (14 << Mask.PrecShift) | Mask.IsUnaryOp | Mask.IsIdentifierLike, // "delete"
    Void = 116 | (14 << Mask.PrecShift) | Mask.IsUnaryOp | Mask.IsIdentifierLike, // "void"
    With = 117 | Mask.IsIdentifierLike, // "with"
    Debugger = 118 | Mask.IsIdentifierLike, // "debugger"

    Identifier = 119 | Mask.IsIdentifierLike, // e.g., "myVar", "foo", "_bar"
    PrivateIdentifier = 120, // e.g., "#privateField", "#method"

    // typescript
    Declare = 121 | Mask.IsIdentifierLike, // "declare"

    EOF = 122, // end of file

    pub fn precedence(self: TokenType) u5 {
        return @intCast((@intFromEnum(self) >> Mask.PrecShift) & Mask.PrecOverlap);
    }

    pub fn is(self: TokenType, mask: u32) bool {
        return (@intFromEnum(self) & mask) != 0;
    }

    pub fn isNumericLiteral(self: TokenType) bool {
        return self.is(Mask.IsNumericLiteral);
    }

    pub fn isBinaryOperator(self: TokenType) bool {
        return self.is(Mask.IsBinaryOp);
    }

    pub fn isLogicalOperator(self: TokenType) bool {
        return self.is(Mask.IsLogicalOp);
    }

    pub fn isUnaryOperator(self: TokenType) bool {
        return self.is(Mask.IsUnaryOp);
    }

    pub fn isAssignmentOperator(self: TokenType) bool {
        return self.is(Mask.IsAssignmentOp);
    }

    /// returns true for identifier-like tokens.
    /// includes: identifiers, all keywords, literal keywords.
    pub fn isIdentifierLike(self: TokenType) bool {
        return self.is(Mask.IsIdentifierLike);
    }

    pub fn toString(self: TokenType) ?[]const u8 {
        return switch (self) {
            .True => "true",
            .False => "false",
            .NullLiteral => "null",

            .Plus => "+",
            .Minus => "-",
            .Star => "*",
            .Slash => "/",
            .Percent => "%",
            .Exponent => "**",

            .Assign => "=",
            .PlusAssign => "+=",
            .MinusAssign => "-=",
            .StarAssign => "*=",
            .SlashAssign => "/=",
            .PercentAssign => "%=",
            .ExponentAssign => "**=",

            .Increment => "++",
            .Decrement => "--",

            .Equal => "==",
            .NotEqual => "!=",
            .StrictEqual => "===",
            .StrictNotEqual => "!==",
            .LessThan => "<",
            .GreaterThan => ">",
            .LessThanEqual => "<=",
            .GreaterThanEqual => ">=",

            .LogicalAnd => "&&",
            .LogicalOr => "||",
            .LogicalNot => "!",

            .BitwiseAnd => "&",
            .BitwiseOr => "|",
            .BitwiseXor => "^",
            .BitwiseNot => "~",
            .LeftShift => "<<",
            .RightShift => ">>",
            .UnsignedRightShift => ">>>",

            .BitwiseAndAssign => "&=",
            .BitwiseOrAssign => "|=",
            .BitwiseXorAssign => "^=",
            .LeftShiftAssign => "<<=",
            .RightShiftAssign => ">>=",
            .UnsignedRightShiftAssign => ">>>=",

            .NullishCoalescing => "??",
            .NullishAssign => "??=",
            .LogicalAndAssign => "&&=",
            .LogicalOrAssign => "||=",
            .OptionalChaining => "?.",

            .LeftParen => "(",
            .RightParen => ")",
            .LeftBrace => "{",
            .RightBrace => "}",
            .LeftBracket => "[",
            .RightBracket => "]",
            .Semicolon => ";",
            .Comma => ",",
            .Dot => ".",
            .Spread => "...",
            .Arrow => "=>",
            .Question => "?",
            .Colon => ":",

            .If => "if",
            .Else => "else",
            .Switch => "switch",
            .Case => "case",
            .Default => "default",
            .For => "for",
            .While => "while",
            .Do => "do",
            .Break => "break",
            .Continue => "continue",

            .Function => "function",
            .Return => "return",
            .Async => "async",
            .Await => "await",
            .Yield => "yield",

            .Var => "var",
            .Let => "let",
            .Const => "const",
            .Using => "using",

            .Class => "class",
            .Extends => "extends",
            .Super => "super",
            .Static => "static",
            .Enum => "enum",
            .Public => "public",
            .Private => "private",
            .Protected => "protected",
            .Interface => "interface",
            .Implements => "implements",

            .Import => "import",
            .Export => "export",
            .From => "from",
            .As => "as",

            .Try => "try",
            .Catch => "catch",
            .Finally => "finally",
            .Throw => "throw",

            .New => "new",
            .This => "this",
            .Typeof => "typeof",
            .Instanceof => "instanceof",
            .In => "in",
            .Of => "of",
            .Delete => "delete",
            .Void => "void",
            .With => "with",
            .Debugger => "debugger",

            .Declare => "declare",

            .EOF,
            .NumericLiteral,
            .HexLiteral,
            .OctalLiteral,
            .BinaryLiteral,
            .BigIntLiteral,
            .StringLiteral,
            .RegexLiteral,
            .NoSubstitutionTemplate,
            .TemplateHead,
            .TemplateMiddle,
            .TemplateTail,
            .Identifier,
            .PrivateIdentifier,
            => null,
        };
    }
};

pub const Span = struct {
    start: u32,
    end: u32,
};

pub const Token = struct {
    span: Span,
    type: TokenType,
    lexeme: []const u8,
    has_line_terminator_before: bool,

    pub inline fn eof(pos: u32) Token {
        return Token{ .lexeme = "", .span = .{ .start = pos, .end = pos }, .type = .EOF, .has_line_terminator_before = false };
    }

    // used for pratt parsing in expressions
    pub fn leftBindingPower(self: *const Token) u5 {
        // handle: [no LineTerminator here] ++ --
        if ((self.type == .Increment or self.type == .Decrement) and self.has_line_terminator_before) {
            return 0; // can't be infix, start new expression
        }

        if (self.type.isBinaryOperator() or self.type.isLogicalOperator() or
            self.type.isAssignmentOperator() or self.type == .Increment or self.type == .Decrement)
        {
            return self.type.precedence();
        }

        return 0; // can't be infix
    }
};
