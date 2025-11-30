const ast = @import("../ast.zig");
const Parser = @import("../parser.zig").Parser;

const patterns = @import("patterns.zig");

pub fn parseFunction(parser: *Parser, is_async: bool, is_expression: bool) ?ast.NodeIndex {
    const start = parser.current_token.span.start;

    if (is_async and !parser.expect(.Async, "...", "...")) return null;

    if (!parser.expect(.Function, "...", "...")) return null;

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

    if (is_expression and id == ast.null_node) {
        parser.err(parser.current_token.span.start, parser.current_token.span.end, "...", "...");
        return null;
    }

    const params = parseFormalParamaters(parser) orelse return null;

    // add body parsing

    return parser.addNode(.{
        .function = .{
            .type = function_type,
            .id = id,
            .generator = is_generator,
            .async = is_async,
            .params = params,
            .body = 0, // implement body tomorrow xD
        },
    }, .{
        .start = start,
        .end = 0, // add end after implementing body, which will be the end of body
    });
}

pub fn parseFormalParamaters(parser: *Parser) ?ast.NodeIndex {
    if (!parser.expect(.LeftParen, "...", "...")) return null;

    const start = parser.current_token.span.start;
    var end: u32 = parser.current_token.span.end;

    const params_checkpoint = parser.scratch_a.begin();

    var rest = ast.null_node;

    while (true) {
        const current_token_type = parser.current_token.type;

        if (current_token_type == .RightParen or current_token_type == .EOF) break;

        if (current_token_type == .Spread) {
            rest = patterns.parseBindingRestElement(parser) orelse ast.null_node;
            end = parser.getSpan(rest).end;

            if (parser.current_token.type == .Comma) {
                parser.err(
                    parser.getSpan(rest).start,
                    parser.current_token.span.end,
                    "...",
                    "...",
                );

                return null;
            }
        } else {
            const param = parseFormalParamater(parser) orelse break;

            end = parser.getSpan(param).end;

            parser.scratch_a.append(parser.allocator(), param);
        }

        if (current_token_type == .Comma) {
            parser.advance();
        }
    }

    if (!parser.expect(.RightParen, "...", "...")) return null;

    return parser.addNode(.{ .formal_parameters = .{ .items = parser.addExtra(parser.scratch_a.take(params_checkpoint)), .rest = rest } }, .{ .start = start, .end = end });
}

pub fn parseFormalParamater(parser: *Parser) ?ast.NodeIndex {
    var pattern = patterns.parseBindingPattern(parser) orelse return null;

    if (parser.current_token.type == .Assign) {
        pattern = patterns.parseAssignmentPattern(parser, pattern) orelse return null;
    }

    return parser.addNode(.{ .formal_parameter = .{ .pattern = pattern } }, parser.getSpan(pattern));
}
