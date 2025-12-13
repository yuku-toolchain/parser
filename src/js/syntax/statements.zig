const std = @import("std");
const ast = @import("../ast.zig");
const Parser = @import("../parser.zig").Parser;
const Error = @import("../parser.zig").Error;

const expressions = @import("expressions.zig");
const variables = @import("variables.zig");
const functions = @import("functions.zig");

pub fn parseStatement(parser: *Parser) Error!?ast.NodeIndex {
    return switch (parser.current_token.type) {
        .@"var", .@"const", .let, .using => variables.parseVariableDeclaration(parser),
        .function => functions.parseFunction(parser, .{}, null),
        .async => blk: {
            const start = parser.current_token.span.start;
            try parser.advance(); // consume 'async'
            break :blk try functions.parseFunction(parser, .{ .is_async = true }, start);
        },
        .declare => blk: {
            if (!parser.isTs()) {
                break :blk try parseExpressionStatementOrDirective(parser);
            }
            const start = parser.current_token.span.start;
            try parser.advance(); // consume 'declare'
            break :blk try functions.parseFunction(parser, .{ .is_declare = true }, start);
        },
        .left_brace => parseBlockStatement(parser),
        .@"if" => parseIfStatement(parser),
        .@"switch" => parseSwitchStatement(parser),

        else => parseExpressionStatementOrDirective(parser),
    };
}

pub fn parseExpressionStatementOrDirective(parser: *Parser) Error!?ast.NodeIndex {
    const expression = try expressions.parseExpression(parser, 0, .{}) orelse return null;

    const expression_span = parser.getSpan(expression);

    const token_after_expression = parser.current_token;

    if (token_after_expression.type != .semicolon and !canInsertSemicolon(parser)) {
        try parser.report(.{ .start = expression_span.end, .end = expression_span.end }, "Expected a semicolon or an implicit semicolon after a statement, but found none", .{ .help = "Try inserting a semicolon here" });
        return null;
    }

    const expression_data = parser.getData(expression);

    const start = expression_span.start;
    const end = try parser.eatSemicolon(expression_span.end);

    // it's a directive
    if (expression_data == .string_literal) {
        const value_start = expression_data.string_literal.raw_start + 1;
        const value_len: u16 = expression_data.string_literal.raw_len - 2;

        return try parser.addNode(.{
            .directive = .{
                .expression = expression,
                .value_start = value_start,
                .value_len = value_len,
            },
        }, .{ .start = start, .end = end });
    }

    return try parser.addNode(
        .{ .expression_statement = .{ .expression = expression } },
        .{ .start = start, .end = end },
    );
}

/// https://tc39.es/ecma262/#prod-BlockStatement
pub fn parseBlockStatement(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;

    if (!try parser.expect(
        .left_brace,
        "Expected '{' to start block statement",
        "Block statements must be enclosed in braces: { ... }",
    )) return null;

    const body = try parser.parseBody(.right_brace);

    const end = parser.current_token.span.end;

    if (!try parser.expect(
        .right_brace,
        "Expected '}' to close block statement",
        "Add a closing brace '}' to complete the block statement, or check for unbalanced braces inside.",
    )) return null;

    return try parser.addNode(.{ .block_statement = .{ .body = body } }, .{ .start = start, .end = end });
}

/// https://tc39.es/ecma262/#sec-switch-statement
pub fn parseSwitchStatement(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;
    try parser.advance(); // consume 'switch'

    if (!try parser.expect(.left_paren, "Expected '(' after 'switch'", null)) return null;

    const discriminant = try expressions.parseExpression(parser, 0, .{}) orelse {
        try parser.report(parser.current_token.span, "Expected expression in switch", .{});
        return null;
    };

    if (!try parser.expect(.right_paren, "Expected ')' after switch expression", null)) return null;
    if (!try parser.expect(.left_brace, "Expected '{' to start switch body", null)) return null;

    const cases = try parseSwitchCases(parser);

    const end = parser.current_token.span.end;
    if (!try parser.expect(.right_brace, "Expected '}' to close switch body", null)) return null;

    return try parser.addNode(.{
        .switch_statement = .{
            .discriminant = discriminant,
            .cases = cases,
        },
    }, .{ .start = start, .end = end });
}

fn parseSwitchCases(parser: *Parser) Error!ast.IndexRange {
    const checkpoint = parser.scratch_a.begin();

    while (parser.current_token.type == .case or parser.current_token.type == .default) {
        const case_node = try parseSwitchCase(parser) orelse continue;
        try parser.scratch_a.append(parser.allocator(), case_node);
    }

    return parser.addExtra(parser.scratch_a.take(checkpoint));
}

fn parseSwitchCase(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;
    const is_default = parser.current_token.type == .default;

    try parser.advance(); // consume 'case' or 'default'

    var test_expr: ast.NodeIndex = ast.null_node;
    if (!is_default) {
        test_expr = try expressions.parseExpression(parser, 0, .{}) orelse {
            try parser.report(parser.current_token.span, "Expected expression after 'case'", .{});
            return null;
        };
    }

    const colon_end = parser.current_token.span.end;
    if (!try parser.expect(.colon, "Expected ':' after case", null)) return null;

    const consequent = try parseCaseConsequent(parser);
    const end = if (consequent.len > 0)
        parser.getSpan(parser.getExtra(consequent)[consequent.len - 1]).end
    else
        colon_end;

    return try parser.addNode(.{
        .switch_case = .{
            .@"test" = test_expr,
            .consequent = consequent,
        },
    }, .{ .start = start, .end = end });
}

fn parseCaseConsequent(parser: *Parser) Error!ast.IndexRange {
    const checkpoint = parser.scratch_b.begin();

    while (parser.current_token.type != .case and
        parser.current_token.type != .default and
        parser.current_token.type != .right_brace and
        parser.current_token.type != .eof)
    {
        if (try parseStatement(parser)) |stmt| {
            try parser.scratch_b.append(parser.allocator(), stmt);
        } else {
            break;
        }
    }

    return parser.addExtra(parser.scratch_b.take(checkpoint));
}

/// https://tc39.es/ecma262/#sec-if-statement
pub fn parseIfStatement(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;
    try parser.advance(); // consume 'if'

    if (!try parser.expect(.left_paren, "Expected '(' after 'if'", null)) return null;

    const test_expr = try expressions.parseExpression(parser, 0, .{}) orelse {
        try parser.report(parser.current_token.span, "Expected expression in if condition", .{});
        return null;
    };

    if (!try parser.expect(.right_paren, "Expected ')' after if condition", null)) return null;

    const consequent = try parseStatement(parser) orelse {
        try parser.report(parser.current_token.span, "Expected statement after if condition", .{});
        return null;
    };

    var end = parser.getSpan(consequent).end;
    var alternate: ast.NodeIndex = ast.null_node;

    if (parser.current_token.type == .@"else") {
        try parser.advance(); // consume 'else'
        alternate = try parseStatement(parser) orelse {
            try parser.report(parser.current_token.span, "Expected statement after 'else'", .{});
            return null;
        };
        end = parser.getSpan(alternate).end;
    }

    return try parser.addNode(.{
        .if_statement = .{
            .@"test" = test_expr,
            .consequent = consequent,
            .alternate = alternate,
        },
    }, .{ .start = start, .end = end });
}

pub inline fn canInsertSemicolon(parser: *Parser) bool {
    const current_token = parser.current_token;
    return current_token.type == .eof or current_token.has_line_terminator_before or current_token.type == .right_brace;
}
