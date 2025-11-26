const crender = @cImport(
    @cInclude("renderer.h"),
);

const Window = @import("root.zig").Window;

pub const Renderer = struct {
    pub fn new(window: *const Window) Renderer {
        crender.ren_init(@ptrCast(window.window.value), @ptrCast(window.renderer.value));
        return .{};
    }
};
