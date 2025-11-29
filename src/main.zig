const std = @import("std");

const Zite = @import("zite").Zite;
const ZWindow = @import("zite").ZWindow;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    var zite = try Zite.new(allocator);
    defer zite.deinit();
    var argsIt = std.process.args();

    var args = try std.ArrayList([]const u8).initCapacity(allocator, 256);
    defer args.deinit(allocator);

    while (argsIt.next()) |arg| {
        try args.append(allocator, arg);
    }
    try zite.init(args.items);
}
