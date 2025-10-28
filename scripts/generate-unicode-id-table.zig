const std = @import("std");

pub fn downloadSpec(allocator: std.mem.Allocator, dest: []const u8) !void {
    if (std.fs.accessAbsolute(dest, .{})) {
        try std.fs.deleteFileAbsolute(dest);
    } else |_| {}

    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse("https://www.unicode.org/Public/17.0.0/ucd/UCD.zip");
    var req = try client.request(.GET, uri, .{ .redirect_behavior = .unhandled, .keep_alive = false });
    defer req.deinit();

    try req.sendBodiless();
    var response = try req.receiveHead(&.{});

    const file = try std.fs.createFileAbsolute(dest, .{});
    defer file.close();

    var file_writer = file.writer(&.{});
    const writer = &file_writer.interface;

    var buf: [1024]u8 = undefined;
    const reader = response.reader(&buf);
    _ = try reader.streamRemaining(writer);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    try downloadSpec(allocator, "/tmp/ucd.zip");
}
