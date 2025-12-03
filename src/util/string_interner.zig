const std = @import("std");

const Self = @This();

pub const String = struct {
    start: u32,
    end: u32,

    pub fn eql(self: String, other: String) bool {
        return self.start == other.start and self.end == other.end;
    }
};

allocator: std.mem.Allocator,
bytes: std.ArrayList(u8),
interned: std.AutoHashMap(String, void),

pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!Self {
    var self = Self{
        .allocator = allocator,
        .bytes = try std.ArrayList(u8).initCapacity(allocator, 256),
        .interned = std.AutoHashMap(String, void).empty,
    };

    try self.interned.ensureTotalCapacity(allocator, 128);
    return self;
}

pub fn deinit(self: *Self) void {
    self.bytes.deinit(self.allocator);
    self.interned.deinit(self.allocator);
}

pub fn getOrInsert(self: *Self, string: []const u8) error{ OutOfMemory, Overflow }!String {
    const KeyCtx = struct {
        bytes: []const u8,

        pub fn hash(_: @This(), key: []const u8) u64 {
            return std.hash.Wyhash.hash(0, key);
        }

        pub fn eql(this: @This(), bytes: []const u8, handle: String) bool {
            return std.mem.eql(u8, bytes, this.bytes[handle.start..handle.end]);
        }
    };

    const ctx = KeyCtx{ .bytes = self.bytes.items };

    const gop = try self.interned.getOrPutAdapted(self.allocator, string, ctx);
    if (gop.found_existing) return gop.key_ptr.*;

    const start: u32 = @intCast(self.bytes.items.len);

    self.bytes.appendSlice(self.allocator, string) catch {
        self.interned.removeByPtr(gop.key_ptr);
        return error.OutOfMemory;
    };

    const end: u32 = @intCast(self.bytes.items.len);
    const handle = String{ .start = start, .end = end };
    gop.key_ptr.* = handle;
    return handle;
}

pub fn toSlice(self: *const Self, string: String) []const u8 {
    return self.bytes.items[string.start..string.end];
}

const t = std.testing;
test {
    var table = try Self.init(t.allocator);
    defer table.deinit();

    const span = try table.getOrInsert("hello");
    try t.expectEqual(0, span.start);
    try t.expectEqual(5, span.end);

    const span2 = try table.getOrInsert("world");
    try t.expectEqual(5, span2.start);
    try t.expectEqual(10, span2.end);

    const span3 = try table.getOrInsert("hello");
    try t.expectEqualDeep(span, span3);
}
