const std = @import("std");
const Parser = @import("../parser.zig").Parser;
const Error = @import("../parser.zig").Error;
const ast = @import("../ast.zig");

const literals = @import("literals.zig");
const expressions = @import("expressions.zig");

pub inline fn parseBindingPattern(parser: *Parser) Error!?ast.NodeIndex {
    if (parser.current_token.type.isIdentifierLike()) {
        return parseBindingIdentifier(parser);
    }

    return switch (parser.current_token.type) {
        .LeftBracket => parseArrayPattern(parser),
        .LeftBrace => parseObjectPattern(parser),
        else => {
            try parser.reportFmt(
                parser.current_token.span,
                "Unexpected token '{s}' in binding pattern",
                .{parser.current_token.lexeme},
                .{ .help = "Expected an identifier, array pattern ([a, b]), or object pattern ({a, b})." },
            );
            return null;
        },
    };
}

pub inline fn parseBindingIdentifier(parser: *Parser) Error!?ast.NodeIndex {
    if (!parser.current_token.type.isIdentifierLike()) {
        try parser.reportFmt(
            parser.current_token.span,
            "Expected identifier, found '{s}'",
            .{parser.current_token.lexeme},
            .{ .help = "A variable name must be a valid JavaScript identifier." },
        );
        return null;
    }

    const current = parser.current_token;
    try parser.advance();

    return try parser.addNode(
        .{
            .binding_identifier = .{
                .name_start = current.span.start,
                .name_len = @intCast(current.lexeme.len),
            },
        },
        current.span,
    );
}

fn parseArrayPattern(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;
    if (!try parser.expect(
        .LeftBracket,
        "Expected '[' to start array destructuring pattern",
        "Array destructuring uses bracket syntax: [a, b] = array",
    )) return null;

    const checkpoint = parser.scratch_a.begin();
    var rest: ast.NodeIndex = ast.null_node;

    while (true) {
        const token_type = parser.current_token.type;
        if (token_type == .RightBracket or token_type == .EOF) break;

        // rest element: ...rest
        if (token_type == .Spread) {
            rest = try parseBindingRestElement(parser) orelse {
                parser.scratch_a.reset(checkpoint);
                return null;
            };

            // rest must be last element
            if (parser.current_token.type == .Comma) {
                try parser.report(
                    .{ .start = parser.getSpan(rest).start, .end = parser.current_token.span.end },
                    "Rest element must be the last element in array destructuring",
                    .{ .help = "Move the '...rest' pattern to the end, or remove trailing elements." },
                );
                parser.scratch_a.reset(checkpoint);
                return null;
            }
            break;
        }

        // holes: [a, , b]
        if (token_type == .Comma) {
            try parser.scratch_a.append(parser.allocator(), ast.null_node);
            try parser.advance();
        } else {
            const element = try parseArrayPatternElement(parser) orelse {
                parser.scratch_a.reset(checkpoint);
                return null;
            };
            try parser.scratch_a.append(parser.allocator(), element);

            if (parser.current_token.type == .Comma) try parser.advance() else break;
        }
    }

    if (parser.current_token.type != .RightBracket) {
        try parser.report(
            parser.current_token.span,
            "Unclosed array destructuring pattern",
            .{
                .help = "Add a closing bracket ']' to complete the pattern, or check for missing commas between elements.",
                .labels = try parser.makeLabels(&.{
                    parser.label(.{ .start = start, .end = start + 1 }, "opened here"),
                }),
            },
        );
        parser.scratch_a.reset(checkpoint);
        return null;
    }

    const end = parser.current_token.span.end;
    try parser.advance();

    return try parser.addNode(
        .{ .array_pattern = .{
            .elements = try parser.addExtra(parser.scratch_a.take(checkpoint)),
            .rest = rest,
        } },
        .{ .start = start, .end = end },
    );
}

inline fn parseArrayPatternElement(parser: *Parser) Error!?ast.NodeIndex {
    const pattern = try parseBindingPattern(parser) orelse return null;

    // default values: [a = 1]
    if (parser.current_token.type == .Assign) {
        return parseAssignmentPattern(parser, pattern);
    }

    return pattern;
}

pub fn parseBindingRestElement(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;
    if (!try parser.expect(
        .Spread,
        "Expected '...' for rest element",
        "Use '...' followed by an identifier to collect remaining elements.",
    )) return null;
    const argument = try parseBindingPattern(parser) orelse return null;
    return try parser.addNode(.{
        .binding_rest_element = .{ .argument = argument },
    }, .{ .start = start, .end = parser.getSpan(argument).end });
}

fn parseObjectPattern(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;
    if (!try parser.expect(
        .LeftBrace,
        "Expected '{' to start object destructuring pattern",
        "Object destructuring uses brace syntax: {a, b} = object",
    )) return null;

    const checkpoint = parser.scratch_a.begin();
    var rest: ast.NodeIndex = ast.null_node;

    while (true) {
        const token_type = parser.current_token.type;
        if (token_type == .RightBrace or token_type == .EOF) break;

        // rest element: ...rest
        if (token_type == .Spread) {
            rest = try parseObjectRestElement(parser) orelse {
                parser.scratch_a.reset(checkpoint);
                return null;
            };

            // rest must be last property
            if (parser.current_token.type == .Comma) {
                try parser.report(
                    .{ .start = parser.getSpan(rest).start, .end = parser.current_token.span.end },
                    "Rest element must be the last property in object destructuring",
                    .{ .help = "Move the '...rest' pattern to the end, or remove trailing properties." },
                );
                parser.scratch_a.reset(checkpoint);
                return null;
            }
            break;
        }

        const property = try parseObjectPatternProperty(parser) orelse {
            parser.scratch_a.reset(checkpoint);
            return null;
        };
        try parser.scratch_a.append(parser.allocator(), property);

        if (parser.current_token.type == .Comma) try parser.advance() else break;
    }

    if (parser.current_token.type != .RightBrace) {
        try parser.report(
            parser.current_token.span,
            "Unclosed object destructuring pattern",
            .{
                .help = "Add a closing brace '}' to complete the pattern, or check for missing commas between properties.",
                .labels = try parser.makeLabels(&.{
                    parser.label(.{ .start = start, .end = start + 1 }, "opened here"),
                }),
            },
        );
        parser.scratch_a.reset(checkpoint);
        return null;
    }

    const end = parser.current_token.span.end;
    try parser.advance();

    return try parser.addNode(
        .{ .object_pattern = .{
            .properties = try parser.addExtra(parser.scratch_a.take(checkpoint)),
            .rest = rest,
        } },
        .{ .start = start, .end = end },
    );
}

fn parseObjectPatternProperty(parser: *Parser) Error!?ast.NodeIndex {
    const current = parser.current_token;
    const start = current.span.start;
    const token_type = current.type;

    if (token_type.isIdentifierLike()) {
        const name_start = current.span.start;
        const name_len: u16 = @intCast(current.lexeme.len);
        const key_span = current.span;

        try parser.advance();

        const next_type = parser.current_token.type;
        const is_shorthand = next_type == .Comma or next_type == .RightBrace or next_type == .Assign;

        if (is_shorthand) {
            // shorthand: {x} or {x = default}
            var value = try parser.addNode(
                .{ .binding_identifier = .{ .name_start = name_start, .name_len = name_len } },
                key_span,
            );

            // default value: {x = 1}
            if (next_type == .Assign) {
                value = try parseAssignmentPattern(parser, value) orelse return null;
            }

            // for shorthand, key and value share the same identifier data
            const key = try parser.addNode(
                .{ .identifier_name = .{ .name_start = name_start, .name_len = name_len } },
                key_span,
            );

            return try parser.addNode(
                .{ .binding_property = .{ .key = key, .value = value, .shorthand = true, .computed = false } },
                .{ .start = start, .end = parser.getSpan(value).end },
            );
        } else {
            // non-shorthand: {x: y} or {x: y = default}
            if (next_type != .Colon) {
                try parser.report(
                    .{ .start = key_span.start, .end = parser.current_token.span.start },
                    "Missing colon in object destructuring property",
                    .{ .help = "Use 'key: binding' to rename the variable, or just 'key' for shorthand when using the same name." },
                );
                return null;
            }

            const key = try parser.addNode(
                .{ .identifier_name = .{ .name_start = name_start, .name_len = name_len } },
                key_span,
            );

            try parser.advance();
            var value = try parseBindingPattern(parser) orelse return null;

            if (parser.current_token.type == .Assign) {
                value = try parseAssignmentPattern(parser, value) orelse return null;
            }

            return try parser.addNode(
                .{ .binding_property = .{ .key = key, .value = value, .shorthand = false, .computed = false } },
                .{ .start = start, .end = parser.getSpan(value).end },
            );
        }
    }

    // computed property names: [expr]
    if (token_type == .LeftBracket) {
        try parser.advance();
        const key = try expressions.parseExpression(parser, 0) orelse return null;

        if (parser.current_token.type != .RightBracket) {
            try parser.report(
                parser.current_token.span,
                "Unclosed computed property name in destructuring",
                .{
                    .help = "Add a closing bracket ']' after the expression used as the property name.",
                    .labels = try parser.makeLabels(&.{
                        parser.label(.{ .start = start, .end = start + 1 }, "opened here"),
                    }),
                },
            );
            return null;
        }

        const key_end = parser.current_token.span.end;
        try parser.advance();

        if (parser.current_token.type != .Colon) {
            try parser.report(
                .{ .start = start, .end = key_end },
                "Computed property names cannot use shorthand syntax",
                .{ .help = "Use the full syntax with a colon: [expr]: value" },
            );
            return null;
        }

        try parser.advance();
        var value = try parseBindingPattern(parser) orelse return null;

        if (parser.current_token.type == .Assign) {
            value = try parseAssignmentPattern(parser, value) orelse return null;
        }

        return try parser.addNode(
            .{ .binding_property = .{ .key = key, .value = value, .shorthand = false, .computed = true } },
            .{ .start = start, .end = parser.getSpan(value).end },
        );
    }

    // numeric or string literal keys
    var key: ast.NodeIndex = undefined;
    if (token_type.isNumericLiteral()) {
        key = try literals.parseNumericLiteral(parser) orelse return null;
    } else if (token_type == .StringLiteral) {
        key = try literals.parseStringLiteral(parser) orelse return null;
    } else {
        try parser.reportFmt(
            current.span,
            "Unexpected token '{s}' in destructuring pattern",
            .{current.lexeme},
            .{ .help = "Destructuring properties must start with an identifier, string, number, or computed property name ([expr])." },
        );
        return null;
    }

    const key_span = parser.getSpan(key);

    if (parser.current_token.type != .Colon) {
        try parser.report(
            .{ .start = key_span.start, .end = parser.current_token.span.start },
            "Missing colon in object destructuring property",
            .{ .help = "Use 'key: binding' to rename the variable, or just 'key' for shorthand when using the same name." },
        );
        return null;
    }

    try parser.advance();
    var value = try parseBindingPattern(parser) orelse return null;

    if (parser.current_token.type == .Assign) {
        value = try parseAssignmentPattern(parser, value) orelse return null;
    }

    return try parser.addNode(
        .{ .binding_property = .{ .key = key, .value = value, .shorthand = false, .computed = false } },
        .{ .start = start, .end = parser.getSpan(value).end },
    );
}

fn parseObjectRestElement(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;
    try parser.advance();

    const argument = try parseBindingPattern(parser) orelse return null;

    // object rest can only be simple identifier
    if (parser.getData(argument) != .binding_identifier) {
        try parser.report(
            parser.getSpan(argument),
            "Object rest element must be a simple identifier",
            .{ .help = "Unlike array rest, object rest (...rest) cannot use nested destructuring patterns." },
        );
        return null;
    }

    return try parser.addNode(
        .{ .binding_rest_element = .{ .argument = argument } },
        .{ .start = start, .end = parser.getSpan(argument).end },
    );
}

pub fn parseAssignmentPattern(parser: *Parser, left: ast.NodeIndex) Error!?ast.NodeIndex {
    const start = parser.getSpan(left).start;
    if (parser.current_token.type != .Assign) return left;

    try parser.advance();

    const right = try expressions.parseExpression(parser, 0) orelse return null;

    return try parser.addNode(
        .{ .assignment_pattern = .{ .left = left, .right = right } },
        .{ .start = start, .end = parser.getSpan(right).end },
    );
}

pub fn isDestructuringPattern(parser: *Parser, index: ast.NodeIndex) bool {
    return switch (parser.getData(index)) {
        .array_pattern, .object_pattern => true,
        .assignment_pattern => |pattern| isDestructuringPattern(parser, pattern.left),
        else => false,
    };
}
