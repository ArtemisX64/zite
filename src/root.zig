const sdl = @import("sdl3");
const std = @import("std");
const Api = @import("api/api.zig").Api;
const Renderer = @import("renderer.zig").Renderer;
const Window = @import("window.zig").Window;

//TODO: For compatibility check
//Remove
const zlua = @import("zlua");
const RenColor = @import("renderer.zig").RenColor;
const checkColor = @import("api/renderer.zig").checkColor;

export fn checkcolor(L: *zlua.LuaState, idx: c_int, def: c_int) callconv(.c) RenColor {
    return checkColor(@ptrCast(L), @intCast(idx), @intCast(def)).toRenColor();
}

pub const Zite = struct {
    api: Api,
    window: Window,
    renderer: Renderer,

    pub fn new(allocator: std.mem.Allocator) !Zite {
        var window = try Window.new();
        const renderer = Renderer.new(&window);
        const api = try Api.new(allocator, &window);
        return .{
            .api = api,
            .window = window,
            .renderer = renderer,
        };
    }

    pub fn init(self: *Zite, args: [][]const u8) !void {
        try self.api.init(args);
    }

    pub fn deinit(self: *Zite) void {
        self.api.deinit();
        self.window.deinit();
    }
};
