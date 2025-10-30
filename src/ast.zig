const std = @import("std");

pub const AstNode = union(enum) {
    program: Program,
};

pub const Program = struct {
    type: []const u8 = "Program",
    body: []AstNode,
};
