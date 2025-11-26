const std = @import("std");
const token = @import("../token.zig");
const ast = @import("../ast.zig");
const Parser = @import("../parser.zig").Parser;
const literals = @import("literals.zig");
const expressions = @import("expressions.zig");

pub fn parseBindingPattern(parser: *Parser) ?ast.NodeIndex {
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

fn parseBindingIdentifier(parser: *Parser) ?ast.NodeIndex {
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

    if (!parser.ensureValidIdentifier(current, "as an identifier", "Choose a different name", .{})) {
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

// array destructuring pattern: [a, b, ...rest]
fn parseArrayPattern(parser: *Parser) ?ast.NodeIndex {
    const start = parser.current_token.span.start;
    if (!parser.expect(
        .LeftBracket,
        "Expected '[' to start array destructuring pattern",
        "Array destructuring uses bracket syntax: [a, b] = array",
    )) return null;

    const checkpoint = parser.scratch_a.begin();

    while (parser.current_token.type != .RightBracket and parser.current_token.type != .EOF) {
        // rest element: ...rest
        if (parser.current_token.type == .Spread) {
            const rest = parseRestElement(parser) orelse {
                parser.scratch_a.reset(checkpoint);
                return null;
            };
            parser.scratch_a.append(rest);

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
        if (parser.current_token.type == .Comma) {
            parser.scratch_a.append(ast.null_node);
            parser.advance();
        } else {
            const element = parseArrayPatternElement(parser) orelse {
                parser.scratch_a.reset(checkpoint);
                return null;
            };
            parser.scratch_a.append(element);

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
        .{ .array_pattern = .{ .elements = parser.addExtra(parser.scratch_a.take(checkpoint)) } },
        .{ .start = start, .end = end },
    );
}

fn parseArrayPatternElement(parser: *Parser) ?ast.NodeIndex {
    const pattern = parseBindingPattern(parser) orelse return null;

    // default values: [a = 1]
    if (parser.current_token.type == .Assign) {
        return parseAssignmentPatternDefault(parser, pattern);
    }

    return pattern;
}

fn parseRestElement(parser: *Parser) ?ast.NodeIndex {
    const start = parser.current_token.span.start;
    if (!parser.expect(
        .Spread,
        "Expected '...' for rest element",
        "Use '...' followed by an identifier to collect remaining elements.",
    )) return null;
    const argument = parseBindingPattern(parser) orelse return null;
    return parser.addNode(.{
        .rest_element = .{ .argument = argument },
    }, .{ .start = start, .end = parser.getSpan(argument).end });
}

// parse object destructuring pattern: {a, b: c, ...rest}
fn parseObjectPattern(parser: *Parser) ?ast.NodeIndex {
    const start = parser.current_token.span.start;
    if (!parser.expect(
        .LeftBrace,
        "Expected '{' to start object destructuring pattern",
        "Object destructuring uses brace syntax: {a, b} = object",
    )) return null;

    const checkpoint = parser.scratch_a.begin();

    while (parser.current_token.type != .RightBrace and parser.current_token.type != .EOF) {
        // rest element: ...rest
        if (parser.current_token.type == .Spread) {
            const rest = parseObjectRestElement(parser) orelse {
                parser.scratch_a.reset(checkpoint);
                return null;
            };
            parser.scratch_a.append(rest);

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
        parser.scratch_a.append(property);

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
        .{ .object_pattern = .{ .properties = parser.addExtra(parser.scratch_a.take(checkpoint)) } },
        .{ .start = start, .end = end },
    );
}

// parse object pattern property: {key: value} or {key} shorthand
fn parseObjectPatternProperty(parser: *Parser) ?ast.NodeIndex {
    const start = parser.current_token.span.start;
    var computed = false;
    var key: ast.NodeIndex = undefined;
    var key_span: ast.Span = undefined;
    var identifier_token: token.Token = undefined;

    // computed property names: [expr]
    if (parser.current_token.type == .LeftBracket) {
        computed = true;
        parser.advance();
        key = expressions.parseExpression(parser, 0) orelse return null;
        key_span = .{ .start = start, .end = parser.getSpan(key).end };

        if (parser.current_token.type != .RightBracket) {
            parser.err(
                start,
                parser.current_token.span.start,
                "Unclosed computed property name in destructuring",
                "Add a closing bracket ']' after the expression used as the property name.",
            );
            return null;
        }

        key_span.end = parser.current_token.span.end;
        parser.advance();
    } else if (parser.current_token.type.isIdentifierLike()) {
        identifier_token = parser.current_token;
        key = parser.addNode(
            .{
                .identifier_name = .{
                    .name_start = parser.current_token.span.start,
                    .name_len = @intCast(parser.current_token.lexeme.len),
                },
            },
            parser.current_token.span,
        );
        key_span = parser.current_token.span;
        parser.advance();
    } else if (parser.current_token.type.isNumericLiteral()) {
        key = literals.parseNumericLiteral(parser) orelse return null;
        key_span = parser.getSpan(key);
    } else if (parser.current_token.type == .StringLiteral) {
        key = literals.parseStringLiteral(parser) orelse return null;
        key_span = parser.getSpan(key);
    } else {
        parser.err(
            parser.current_token.span.start,
            parser.current_token.span.end,
            parser.formatMessage("Unexpected token '{s}' in destructuring pattern", .{parser.current_token.lexeme}),
            "Destructuring properties must start with an identifier, string, number, or computed property name ([expr]).",
        );
        return null;
    }

    // check for shorthand: {x} instead of {x: x}
    const is_shorthand = parser.current_token.type == .Comma or
        parser.current_token.type == .RightBrace or
        parser.current_token.type == .Assign;

    var value: ast.NodeIndex = undefined;
    if (is_shorthand) {
        const data = parser.getData(key);
        if (data != .identifier_name) {
            parser.err(
                key_span.start,
                key_span.end,
                "Computed property names cannot use shorthand syntax",
                "Use the full syntax with a colon: [expr]: value",
            );
            return null;
        }

        if (!parser.ensureValidIdentifier(identifier_token, "in shorthand", "Use full form", .{})) {
            return null;
        }

        value = parser.addNode(
            .{
                .binding_identifier = .{
                    .name_start = data.identifier_name.name_start,
                    .name_len = data.identifier_name.name_len,
                },
            },
            key_span,
        );

        // default value: {x = 1}
        if (parser.current_token.type == .Assign) {
            value = parseAssignmentPatternDefault(parser, value) orelse return null;
        }
    } else {
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
        value = parseBindingPattern(parser) orelse return null;

        // default value with default: {x: y = 1}
        if (parser.current_token.type == .Assign) {
            value = parseAssignmentPatternDefault(parser, value) orelse return null;
        }
    }

    return parser.addNode(
        .{
            .binding_property = .{
                .key = key,
                .value = value,
                .shorthand = is_shorthand,
                .computed = computed,
            },
        },
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
        .{ .rest_element = .{ .argument = argument } },
        .{ .start = start, .end = parser.getSpan(argument).end },
    );
}

// default value in destructuring: {x = 1}, [y = 2]
fn parseAssignmentPatternDefault(parser: *Parser, left: ast.NodeIndex) ?ast.NodeIndex {
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
