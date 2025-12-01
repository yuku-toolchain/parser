const ast = @import("../ast.zig");
const Parser = @import("../parser.zig").Parser;

const patterns = @import("patterns.zig");

pub fn parseFunction(parser: *Parser, is_async: bool, is_expression: bool) ?ast.NodeIndex {
    const start = parser.current_token.span.start;

    if (is_async and !parser.expect(
        .Async,
        "Expected 'async' keyword",
        "Async functions must start with the 'async' keyword.",
    )) return null;

    if (!parser.expect(
        .Function,
        "Expected 'function' keyword",
        "Use 'function name() {}' to declare a function.",
    )) return null;

    const function_type: ast.FunctionType = if (is_expression) .FunctionExpression else .FunctionDeclaration;

    var is_generator = false;

    if (parser.current_token.type == .Star) {
        is_generator = true;
        parser.advance();
    }

    const id = if (parser.current_token.type.isIdentifierLike())
        patterns.parseBindingIdentifier(parser) orelse ast.null_node
    else
        ast.null_node;

    if (!is_expression and id == ast.null_node) {
        parser.err(
            parser.current_token.span.start,
            parser.current_token.span.end,
            "Function declaration requires a name",
            "Add a name after 'function', e.g. 'function myFunc() {}'.",
        );
        return null;
    }

    const params = parseFormalParamaters(parser) orelse return null;

    if (!parser.expect(
        .LeftBrace,
        "Expected '{' to start function body",
        "Function bodies must be enclosed in braces: function name() { ... }",
    )) return null;

    const body = parseFunctionBody(parser);

    // end of right brace
    const end = parser.current_token.span.end;

    if (!parser.expect(
        .RightBrace,
        "Expected '}' to close function body",
        "Add a closing brace '}' to complete the function, or check for unbalanced braces inside.",
    )) return null;

    return parser.addNode(.{
        .function = .{
            .type = function_type,
            .id = id,
            .generator = is_generator,
            .async = is_async,
            .params = params,
            .body = body,
        },
    }, .{
        .start = start,
        .end = end,
    });
}

pub fn parseFunctionBody(parser: *Parser) ast.NodeIndex {
    const body_data = parser.parseBody();

    return parser.addNode(.{ .function_body = .{ .statements = body_data.statements, .directives = body_data.directives } }, body_data.span);
}

pub fn parseFormalParamaters(parser: *Parser) ?ast.NodeIndex {
    if (!parser.expect(
        .LeftParen,
        "Expected '(' to start parameter list",
        "Function parameters must be enclosed in parentheses: function name(a, b) {}",
    )) return null;

    const start = parser.current_token.span.start;
    var end: u32 = parser.current_token.span.end;

    const params_checkpoint = parser.scratch_a.begin();

    var rest = ast.null_node;

    while (true) {
        if (parser.current_token.type == .Comma) {
            parser.advance();
        }

        if (parser.current_token.type == .RightParen or parser.current_token.type == .EOF) break;

        if (parser.current_token.type == .Spread) {
            rest = patterns.parseBindingRestElement(parser) orelse ast.null_node;
            end = parser.getSpan(rest).end;

            if (parser.current_token.type == .Comma) {
                parser.err(
                    parser.getSpan(rest).start,
                    parser.current_token.span.end,
                    "Rest parameter must be the last parameter",
                    "Move the '...rest' parameter to the end of the parameter list, or remove trailing parameters.",
                );

                return null;
            }
        } else {
            const param = parseFormalParamater(parser) orelse break;

            end = parser.getSpan(param).end;

            parser.scratch_a.append(parser.allocator(), param);
        }
    }

    if (!parser.expect(
        .RightParen,
        "Expected ')' to close parameter list",
        "Add a closing parenthesis ')' after the parameters, or check for missing commas between parameters.",
    )) return null;

    return parser.addNode(.{ .formal_parameters = .{ .items = parser.addExtra(parser.scratch_a.take(params_checkpoint)), .rest = rest } }, .{ .start = start, .end = end });
}

pub fn parseFormalParamater(parser: *Parser) ?ast.NodeIndex {
    var pattern = patterns.parseBindingPattern(parser) orelse return null;

    if (parser.current_token.type == .Assign) {
        pattern = patterns.parseAssignmentPattern(parser, pattern) orelse return null;
    }

    return parser.addNode(.{ .formal_parameter = .{ .pattern = pattern } }, parser.getSpan(pattern));
}
