const std = @import("std");
const Zite = @import("zite").Zite;
const ZWindow = @import("zite").ZWindow;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var zite = try Zite.new(gpa.allocator());

    var argsIt = std.process.args();

    var args = try std.ArrayList([]const u8).initCapacity(gpa.allocator(), 256);
    defer args.deinit(gpa.allocator());

    while (argsIt.next()) |arg| {
        try args.append(gpa.allocator(), arg);
    }
    try zite.init(args.items);
}
