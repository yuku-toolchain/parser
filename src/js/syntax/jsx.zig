const ast = @import("../ast.zig");
const Parser = @import("../parser.zig").Parser;
const Error = @import("../parser.zig").Error;

pub fn parseJsxElement(parser: *Parser) Error!?ast.NodeIndex {
    _ = try parseJsxOpeningElement(parser) orelse return null;

    return null;
}

pub fn parseJsxOpeningElement(parser: *Parser) Error!?ast.NodeIndex {
    try parser.advance() orelse return null; // consome '<'

    parser.lexer.state.in_jsx_identifier = true;

    if(parser.current_token.type == .jsx_identifier) {}

    return null;
}
