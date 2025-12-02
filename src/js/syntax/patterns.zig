const std = @import("std");
const Parser = @import("../parser.zig").Parser;
const token = @import("../token.zig");
const ast = @import("../ast.zig");

const literals = @import("literals.zig");
const expressions = @import("expressions.zig");

pub inline fn parseBindingPattern(parser: *Parser) ?ast.NodeIndex {
    if (parser.current_token.type.isIdentifierLike()) {
        return parseBindingIdentifier(parser);
    }

    return switch (parser.current_token.type) {
        .LeftBracket => parseArrayPattern(parser),
        .LeftBrace => parseObjectPattern(parser),
        else => {
            parser.err(
                parser.current_token.span.start,
                parser.current_token.span.end,
                parser.formatMessage("Unexpected token '{s}' in binding pattern", .{parser.current_token.lexeme}),
                "Expected an identifier, array pattern ([a, b]), or object pattern ({a, b}).",
            );
            return null;
        },
    };
}

pub inline fn parseBindingIdentifier(parser: *Parser) ?ast.NodeIndex {
    if (!parser.current_token.type.isIdentifierLike()) {
        parser.err(
            parser.current_token.span.start,
            parser.current_token.span.end,
            parser.formatMessage("Expected identifier, found '{s}'", .{parser.current_token.lexeme}),
            "A variable name must be a valid JavaScript identifier.",
        );
        return null;
    }

    const current = parser.current_token;

    if (isReserved(parser, current, "as an identifier", "Choose a different name", .{})) {
        return null;
    }

    parser.advance();

    return parser.addNode(
        .{
            .binding_identifier = .{
                .name_start = current.span.start,
                .name_len = @intCast(current.lexeme.len),
            },
        },
        current.span,
    );
}

fn parseArrayPattern(parser: *Parser) ?ast.NodeIndex {
    const start = parser.current_token.span.start;
    if (!parser.expect(
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
            rest = parseBindingRestElement(parser) orelse {
                parser.scratch_a.reset(checkpoint);
                return null;
            };

            // rest must be last element
            if (parser.current_token.type == .Comma) {
                parser.err(
                    parser.getSpan(rest).start,
                    parser.current_token.span.end,
                    "Rest element must be the last element in array destructuring",
                    "Move the '...rest' pattern to the end, or remove trailing elements.",
                );
                parser.scratch_a.reset(checkpoint);
                return null;
            }
            break;
        }

        // holes: [a, , b]
        if (token_type == .Comma) {
            parser.scratch_a.append(parser.allocator(), ast.null_node);
            parser.advance();
        } else {
            const element = parseArrayPatternElement(parser) orelse {
                parser.scratch_a.reset(checkpoint);
                return null;
            };
            parser.scratch_a.append(parser.allocator(), element);

            if (parser.current_token.type == .Comma) parser.advance() else break;
        }
    }

    if (parser.current_token.type != .RightBracket) {
        parser.err(
            start,
            parser.current_token.span.end,
            "Unclosed array destructuring pattern",
            "Add a closing bracket ']' to complete the pattern, or check for missing commas between elements.",
        );
        parser.scratch_a.reset(checkpoint);
        return null;
    }

    const end = parser.current_token.span.end;
    parser.advance();

    return parser.addNode(
        .{ .array_pattern = .{
            .elements = parser.addExtra(parser.scratch_a.take(checkpoint)),
            .rest = rest,
        } },
        .{ .start = start, .end = end },
    );
}

inline fn parseArrayPatternElement(parser: *Parser) ?ast.NodeIndex {
    const pattern = parseBindingPattern(parser) orelse return null;

    // default values: [a = 1]
    if (parser.current_token.type == .Assign) {
        return parseAssignmentPattern(parser, pattern);
    }

    return pattern;
}

pub fn parseBindingRestElement(parser: *Parser) ?ast.NodeIndex {
    const start = parser.current_token.span.start;
    if (!parser.expect(
        .Spread,
        "Expected '...' for rest element",
        "Use '...' followed by an identifier to collect remaining elements.",
    )) return null;
    const argument = parseBindingPattern(parser) orelse return null;
    return parser.addNode(.{
        .binding_rest_element = .{ .argument = argument },
    }, .{ .start = start, .end = parser.getSpan(argument).end });
}

fn parseObjectPattern(parser: *Parser) ?ast.NodeIndex {
    const start = parser.current_token.span.start;
    if (!parser.expect(
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
            rest = parseObjectRestElement(parser) orelse {
                parser.scratch_a.reset(checkpoint);
                return null;
            };

            // rest must be last property
            if (parser.current_token.type == .Comma) {
                parser.err(
                    parser.getSpan(rest).start,
                    parser.current_token.span.end,
                    "Rest element must be the last property in object destructuring",
                    "Move the '...rest' pattern to the end, or remove trailing properties.",
                );
                parser.scratch_a.reset(checkpoint);
                return null;
            }
            break;
        }

        const property = parseObjectPatternProperty(parser) orelse {
            parser.scratch_a.reset(checkpoint);
            return null;
        };
        parser.scratch_a.append(parser.allocator(), property);

        if (parser.current_token.type == .Comma) parser.advance() else break;
    }

    if (parser.current_token.type != .RightBrace) {
        parser.err(
            start,
            parser.current_token.span.end,
            "Unclosed object destructuring pattern",
            "Add a closing brace '}' to complete the pattern, or check for missing commas between properties.",
        );
        parser.scratch_a.reset(checkpoint);
        return null;
    }

    const end = parser.current_token.span.end;
    parser.advance();

    return parser.addNode(
        .{ .object_pattern = .{
            .properties = parser.addExtra(parser.scratch_a.take(checkpoint)),
            .rest = rest,
        } },
        .{ .start = start, .end = end },
    );
}

fn parseObjectPatternProperty(parser: *Parser) ?ast.NodeIndex {
    const current = parser.current_token;
    const start = current.span.start;
    const token_type = current.type;

    if (token_type.isIdentifierLike()) {
        const name_start = current.span.start;
        const name_len: u16 = @intCast(current.lexeme.len);
        const key_span = current.span;

        parser.advance();

        const next_type = parser.current_token.type;
        const is_shorthand = next_type == .Comma or next_type == .RightBrace or next_type == .Assign;

        if (is_shorthand) {
            // shorthand: {x} or {x = default}
            if (isReserved(parser, current, "in shorthand", "Use full form", .{})) {
                return null;
            }

            var value = parser.addNode(
                .{ .binding_identifier = .{ .name_start = name_start, .name_len = name_len } },
                key_span,
            );

            // default value: {x = 1}
            if (next_type == .Assign) {
                value = parseAssignmentPattern(parser, value) orelse return null;
            }

            // for shorthand, key and value share the same identifier data
            const key = parser.addNode(
                .{ .identifier_name = .{ .name_start = name_start, .name_len = name_len } },
                key_span,
            );

            return parser.addNode(
                .{ .binding_property = .{ .key = key, .value = value, .shorthand = true, .computed = false } },
                .{ .start = start, .end = parser.getSpan(value).end },
            );
        } else {
            // non-shorthand: {x: y} or {x: y = default}
            if (next_type != .Colon) {
                parser.err(
                    key_span.start,
                    parser.current_token.span.start,
                    "Missing colon in object destructuring property",
                    "Use 'key: binding' to rename the variable, or just 'key' for shorthand when using the same name.",
                );
                return null;
            }

            const key = parser.addNode(
                .{ .identifier_name = .{ .name_start = name_start, .name_len = name_len } },
                key_span,
            );

            parser.advance();
            var value = parseBindingPattern(parser) orelse return null;

            if (parser.current_token.type == .Assign) {
                value = parseAssignmentPattern(parser, value) orelse return null;
            }

            return parser.addNode(
                .{ .binding_property = .{ .key = key, .value = value, .shorthand = false, .computed = false } },
                .{ .start = start, .end = parser.getSpan(value).end },
            );
        }
    }

    // computed property names: [expr]
    if (token_type == .LeftBracket) {
        parser.advance();
        const key = expressions.parseExpression(parser, 0) orelse return null;

        if (parser.current_token.type != .RightBracket) {
            parser.err(
                start,
                parser.current_token.span.start,
                "Unclosed computed property name in destructuring",
                "Add a closing bracket ']' after the expression used as the property name.",
            );
            return null;
        }

        const key_end = parser.current_token.span.end;
        parser.advance();

        if (parser.current_token.type != .Colon) {
            parser.err(
                start,
                key_end,
                "Computed property names cannot use shorthand syntax",
                "Use the full syntax with a colon: [expr]: value",
            );
            return null;
        }

        parser.advance();
        var value = parseBindingPattern(parser) orelse return null;

        if (parser.current_token.type == .Assign) {
            value = parseAssignmentPattern(parser, value) orelse return null;
        }

        return parser.addNode(
            .{ .binding_property = .{ .key = key, .value = value, .shorthand = false, .computed = true } },
            .{ .start = start, .end = parser.getSpan(value).end },
        );
    }

    // numeric or string literal keys
    var key: ast.NodeIndex = undefined;
    if (token_type.isNumericLiteral()) {
        key = literals.parseNumericLiteral(parser) orelse return null;
    } else if (token_type == .StringLiteral) {
        key = literals.parseStringLiteral(parser) orelse return null;
    } else {
        parser.err(
            current.span.start,
            current.span.end,
            parser.formatMessage("Unexpected token '{s}' in destructuring pattern", .{current.lexeme}),
            "Destructuring properties must start with an identifier, string, number, or computed property name ([expr]).",
        );
        return null;
    }

    const key_span = parser.getSpan(key);

    if (parser.current_token.type != .Colon) {
        parser.err(
            key_span.start,
            parser.current_token.span.start,
            "Missing colon in object destructuring property",
            "Use 'key: binding' to rename the variable, or just 'key' for shorthand when using the same name.",
        );
        return null;
    }

    parser.advance();
    var value = parseBindingPattern(parser) orelse return null;

    if (parser.current_token.type == .Assign) {
        value = parseAssignmentPattern(parser, value) orelse return null;
    }

    return parser.addNode(
        .{ .binding_property = .{ .key = key, .value = value, .shorthand = false, .computed = false } },
        .{ .start = start, .end = parser.getSpan(value).end },
    );
}

fn parseObjectRestElement(parser: *Parser) ?ast.NodeIndex {
    const start = parser.current_token.span.start;
    parser.advance();

    const argument = parseBindingPattern(parser) orelse return null;

    // object rest can only be simple identifier
    if (parser.getData(argument) != .binding_identifier) {
        parser.err(
            parser.getSpan(argument).start,
            parser.getSpan(argument).end,
            "Object rest element must be a simple identifier",
            "Unlike array rest, object rest (...rest) cannot use nested destructuring patterns.",
        );
        return null;
    }

    return parser.addNode(
        .{ .binding_rest_element = .{ .argument = argument } },
        .{ .start = start, .end = parser.getSpan(argument).end },
    );
}

pub fn parseAssignmentPattern(parser: *Parser, left: ast.NodeIndex) ?ast.NodeIndex {
    const start = parser.getSpan(left).start;
    if (parser.current_token.type != .Assign) return left;

    parser.advance();

    const right = expressions.parseExpression(parser, 0) orelse return null;

    return parser.addNode(
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

inline fn isReserved(
    parser: *Parser,
    tok: token.Token,
    comptime as_what: []const u8,
    comptime help: []const u8,
    help_args: anytype,
) bool {
    if (parser.strict_mode and tok.type == .Identifier) {
        if (std.mem.eql(u8, tok.lexeme, "eval") or std.mem.eql(u8, tok.lexeme, "arguments")) {
            parser.err(tok.span.start, tok.span.end, parser.formatMessage("'{s}' cannot be used {s} in strict mode", .{ tok.lexeme, as_what }), help);
            return true;
        }
    }

    if (parser.strict_mode and tok.type.isStrictModeReserved()) {
        parser.err(tok.span.start, tok.span.end, parser.formatMessage("'{s}' is reserved in strict mode and cannot be used {s}", .{ tok.lexeme, as_what }), help);
        return true;
    }

    if (tok.type == .Await and (parser.context.in_async or parser.source_type == .Module)) {
        parser.err(tok.span.start, tok.span.end, parser.formatMessage("'await' is reserved {s} and cannot be used {s}", .{ if (parser.context.in_async) "in async functions" else "at the top level of modules", as_what }), help);
        return true;
    }

    if (tok.type == .Yield and (parser.context.in_generator or parser.source_type == .Module)) {
        parser.err(tok.span.start, tok.span.end, parser.formatMessage("'yield' is reserved {s} and cannot be used {s}", .{ if (parser.context.in_generator) "in generator functions" else "at the top level of modules", as_what }), help);
        return true;
    }

    if (tok.type.isStrictReserved()) {
        parser.err(tok.span.start, tok.span.end, parser.formatMessage("'{s}' is a reserved word and cannot be used {s}", .{ tok.lexeme, as_what }), parser.formatMessage(help, help_args));
        return true;
    }

    return false;
}
