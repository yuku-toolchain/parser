const std = @import("std");
const js = @import("js");

const wasm_allocator = std.heap.wasm_allocator;

pub export fn alloc(size: usize) ?[*]u8 {
    const buf = wasm_allocator.alloc(u8, size) catch return null;
    return buf.ptr;
}

pub export fn free(ptr: [*]u8, size: usize) void {
    wasm_allocator.free(ptr[0..size]);
}

pub export fn parse(source_bytes: [*]const u8, len: u32, source_type: u32, lang: u32) ?[*:0]const u8 {
    const source: []const u8 = source_bytes[0..len];

    const st: js.SourceType = if (source_type == 0) .script else .module;
    const l: js.Lang = switch (lang) {
        0 => .js,
        1 => .ts,
        2 => .jsx,
        3 => .tsx,
        4 => .dts,
        else => .js,
    };

    const options = js.Options{
        .source_type = st,
        .lang = l,
    };

    var parse_tree = js.parse(wasm_allocator, source, options) catch return null;
    defer parse_tree.deinit();

    const json_str = js.estree.toJSON(&parse_tree, wasm_allocator, .{}) catch return null;
    const json_str_z = nullTerminate(json_str) catch return null;

    return json_str_z.ptr;
}

pub export fn freeJson(json_ptr: [*:0]const u8) void {
    const len = std.mem.len(json_ptr);
    wasm_allocator.free(json_ptr[0..len]);
}

/// null-terminate a slice of bytes
/// this modifies the slice in-place by reallocating
fn nullTerminate(source: []u8) std.mem.Allocator.Error![:0]u8 {
    const source_len = source.len;
    const source_with_null = try wasm_allocator.realloc(source, source_len + 1);
    source_with_null[source_len] = 0;
    return @ptrCast(source_with_null[0 .. source_len + 1]);
}
