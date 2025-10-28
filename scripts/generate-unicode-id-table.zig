const std = @import("std");

const spec_url = "https://www.unicode.org/Public/17.0.0/ucd/UCD.zip";
const zip_dest = "/tmp/ucd.zip";
const extracted_dir = "/tmp/ucd";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    try downloadAndExtractSpec(allocator);

    try readSpecToCodes(allocator);
}

fn readSpecToCodes(allocator: std.mem.Allocator) !void {
    const file_path: []const u8 = "DerivedCoreProperties.txt";

    var dir = try std.fs.openDirAbsolute(extracted_dir, .{});
    defer dir.close();

    const content = try dir.readFileAlloc(file_path, allocator, .limited(1024 * 1024 * 1024));
    defer allocator.free(content);

    const delim: u8 = '\n';

    var lines = std.mem.splitScalar(u8, content, delim);
    while (lines.next()) |line| {
        if (line.len > 0 and !std.mem.startsWith(u8, line, "#")) {
            std.log.info("{s}", .{line});
        }
    }
}

pub fn downloadAndExtractSpec(allocator: std.mem.Allocator) !void {
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(spec_url);
    var req = try client.request(.GET, uri, .{ .redirect_behavior = .unhandled, .keep_alive = false });
    defer req.deinit();

    try req.sendBodiless();
    var response = try req.receiveHead(&.{});

    const file = try std.fs.createFileAbsolute(zip_dest, .{});
    defer file.close();
    defer std.fs.deleteFileAbsolute(zip_dest) catch {};

    var file_writer = file.writer(&.{});
    const writer = &file_writer.interface;

    var response_reader_buf: [1024]u8 = undefined;
    const reader = response.reader(&response_reader_buf);
    _ = try reader.streamRemaining(writer);

    try std.fs.deleteTreeAbsolute(extracted_dir);

    try std.fs.makeDirAbsolute(extracted_dir);

    var dir = try std.fs.openDirAbsolute(extracted_dir, .{});
    defer dir.close();

    const zip = try std.fs.openFileAbsolute(zip_dest, .{});
    defer zip.close();

    var zip_reader_buf: [1024]u8 = undefined;
    var zip_reader = zip.reader(&zip_reader_buf);

    try std.zip.extract(dir, &zip_reader, .{});

    std.log.info("Extracted successfully to {s}", .{extracted_dir});
}
