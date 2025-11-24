const std = @import("std");
const token = @import("../token.zig");
const ast = @import("../ast.zig");
const Parser = @import("../parser.zig").Parser;

const expressions = @import("expressions.zig");
const patterns = @import("patterns.zig");

pub fn parseVariableDeclaration(parser: *Parser) ?*ast.Statement {
    const start = parser.current_token.span.start;
    const kind = parseVariableDeclarationKind(parser) orelse return null;

    var declarators = std.ArrayList(*ast.VariableDeclarator).empty;
    parser.ensureCapacity(&declarators, 4);

    // parse first declarator
    const first_decl = parseVariableDeclarator(parser, kind) orelse return null;
    parser.append(&declarators, first_decl);

    var end = first_decl.span.end;

    // parse additional declarators
    while (parser.current_token.type == .Comma) {
        parser.advance();
        const decl = parseVariableDeclarator(parser, kind) orelse return null;
        end = decl.span.end;
        parser.append(&declarators, decl);
    }

    end = parser.eatSemi(end);

    const declarations = parser.dupe(*ast.VariableDeclarator, declarators.items);

    const var_decl = ast.VariableDeclaration{
        .kind = kind,
        .declarations = declarations,
        .span = .{ .start = start, .end = end },
    };

    return parser.createNode(ast.Statement, .{ .variable_declaration = var_decl });
}

inline fn parseVariableDeclarationKind(parser: *Parser) ?ast.VariableDeclaration.VariableDeclarationKind {
    const tok = parser.current_token.type;
    parser.advance();

    return switch (tok) {
        .Let => .let,
        .Const => .@"const",
        .Var => .@"var",
        .Using => .using,
        .Await => blk: {
            if (parser.current_token.type == .Using) {
                parser.advance();
                break :blk .@"await using";
            }
            return null;
        },
        else => null,
    };
}

fn parseVariableDeclarator(
    parser: *Parser,
    kind: ast.VariableDeclaration.VariableDeclarationKind,
) ?*ast.VariableDeclarator {
    const start = parser.current_token.span.start;
    const id = patterns.parseBindingPattern(parser) orelse return null;

    var init_expr: ?*ast.Expression = null;
    var end = id.getSpan().end;

    if (parser.current_token.type == .Assign) {
        parser.advance();
        if (expressions.parseExpression(parser, 0)) |expr| {
            init_expr = expr;
            end = expr.getSpan().end;
        }
    } else if (patterns.isDestructuringPattern(parser, id)) {
        const id_span = id.getSpan();
        parser.err(
            id_span.start,
            id_span.end,
            "Missing initializer in destructuring declaration",
            "Destructuring patterns must be initialized. Add '= <value>' after the pattern",
        );
        return null;
    } else if (kind == .@"const" or kind == .using or kind == .@"await using") {
        const id_span = id.getSpan();

        const kind_str = switch (kind) {
            .@"const" => "'const'",
            .using => "'using'",
            .@"await using" => "'await using'",
            else => unreachable,
        };

        parser.err(
            id_span.start,
            id_span.end,
            parser.formatMessage(
                "Missing initializer in {s} declaration",
                .{kind_str},
            ),
            "Add '= <value>' after the variable name to initialize it",
        );
        return null;
    }

    return parser.createNode(ast.VariableDeclarator, .{
        .id = id,
        .init = init_expr,
        .span = .{ .start = start, .end = end },
    });
}
