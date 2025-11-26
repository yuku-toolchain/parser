const std = @import("std");
const ast = @import("../ast.zig");
const Parser = @import("../parser.zig").Parser;
const expressions = @import("expressions.zig");
const patterns = @import("patterns.zig");

// parse variable declarations: var/let/const/using/await using
pub fn parseVariableDeclaration(parser: *Parser) ?ast.NodeIndex {
    const start = parser.current_token.span.start;
    const kind = parseVariableKind(parser) orelse return null;

    const checkpoint = parser.scratch_a.begin();

    const first_declarator = parseVariableDeclarator(parser, kind) orelse {
        parser.scratch_a.reset(checkpoint);
        return null;
    };
    parser.scratch_a.append(first_declarator);
    var end = parser.getSpan(first_declarator).end;

    // parse additional declarators: let a, b, c;
    while (parser.current_token.type == .Comma) {
        parser.advance();
        const declarator = parseVariableDeclarator(parser, kind) orelse {
            parser.scratch_a.reset(checkpoint);
            return null;
        };
        parser.scratch_a.append(declarator);
        end = parser.getSpan(declarator).end;
    }

    return parser.addNode(
        .{
            .variable_declaration = .{
                .declarators = parser.addExtra(parser.scratch_a.take(checkpoint)),
                .kind = kind,
            },
        },
        .{ .start = start, .end = parser.eatSemicolon(end) },
    );
}

inline fn parseVariableKind(parser: *Parser) ?ast.VariableKind {
    const token_type = parser.current_token.type;
    parser.advance();

    return switch (token_type) {
        .Let => .Let,
        .Const => .Const,
        .Var => .Var,
        .Using => .Using,

        // handle 'await using' for explicit resource management
        .Await => if (parser.current_token.type == .Using) blk: {
            parser.advance();
            break :blk .AwaitUsing;
        } else null,

        else => null,
    };
}

fn parseVariableDeclarator(parser: *Parser, kind: ast.VariableKind) ?ast.NodeIndex {
    const start = parser.current_token.span.start;
    const id = patterns.parseBindingPattern(parser) orelse return null;

    var init: ast.NodeIndex = ast.null_node;
    var end = parser.getSpan(id).end;

    // parse initializer if present
    if (parser.current_token.type == .Assign) {
        parser.advance();
        if (expressions.parseExpression(parser, 0)) |expression| {
            init = expression;
            end = parser.getSpan(expression).end;
        }
    } else if (patterns.isDestructuringPattern(parser, id)) {
        // destructuring always requires initializer
        parser.err(parser.getSpan(id).start, parser.getSpan(id).end, "Destructuring requires initializer", null);
        return null;
    } else if (kind == .Const or kind == .Using or kind == .AwaitUsing) {
        // const/using/await using always require initializer
        parser.err(parser.getSpan(id).start, parser.getSpan(id).end, parser.formatMessage("{s} requires initializer", .{@tagName(kind)}), null);
        return null;
    }

    return parser.addNode(
        .{ .variable_declarator = .{ .id = id, .init = init } },
        .{ .start = start, .end = end },
    );
}
