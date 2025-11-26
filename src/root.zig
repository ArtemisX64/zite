const sdl = @import("sdl3");
const std = @import("std");
const Api = @import("api/api.zig").Api;
const Renderer = @import("renderer.zig").Renderer;

pub const Window = struct {
    window: sdl.video.Window,
    flags: sdl.InitFlags,
    renderer: sdl.render.Renderer,

    fn new() !Window {
        const flags = sdl.InitFlags{ .video = true, .events = true };
        try sdl.init(flags);
        try sdl.video.enableScreenSaver();
        sdl.events.setEnabled(.drop_file, true);
        try sdl.hints.set(.video_x11_net_wm_bypass_compositor, "0");
        try sdl.hints.set(.mouse_focus_clickthrough, "1");
        const primary_display = try sdl.video.Display.getPrimaryDisplay();
        const dm = try primary_display.getCurrentMode();
        const width: usize = @intFromFloat(@as(f32, @floatFromInt(dm.width)) * 0.8);
        const height: usize = @intFromFloat(@as(f32, @floatFromInt(dm.height)) * 0.8);
        const window = try sdl.video.Window.init("", width, height, .{
            .resizable = true,
            .high_pixel_density = true,
        });
        const renderer = try sdl.render.Renderer.init(window, null);

        return Window{
            .window = window,
            .flags = flags,
            .renderer = renderer,
        };
    }

    fn deinit(self: *Window) void {
        self.window.deinit();
        sdl.quit(self.flags);
        sdl.shutdown();
    }
};

pub const Zite = struct {
    api: Api,
    window: Window,
    renderer: Renderer,

    pub fn new(allocator: std.mem.Allocator) !Zite {
        const window = try Window.new();
        const renderer = Renderer.new(&window);
        const api = try Api.new(allocator);
        return .{
            .api = api,
            .window = window,
            .renderer = renderer,
        };
    }

    pub fn init(self: *Zite) void {
        self.api.init();
    }

    pub fn deinit(self: *Zite) void {
        self.api.deinit();
        self.window.deinit();
    }
};
