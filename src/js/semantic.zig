const ast = @import("ast.zig");
const std = @import("std");
const util = @import("util");

const ProgramScope = struct {};

const FunctionScope = struct {
    // FormalParamaters
    has_use_strict: bool,
    is_simple_paramerters: bool
};

const ScopeData = union(enum) {
    program: ProgramScope,
    function: FunctionScope
};

const Scope = struct {
    data: ScopeData,
    variables: util.StringInterner.String
};

pub const Semantic = struct {
    scopes: std.MultiArrayList(Scope),
};
