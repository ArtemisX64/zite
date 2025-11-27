const sdl = @import("sdl3");
const std = @import("std");

const crender = @cImport(
    @cInclude("renderer.h"),
);

const Window = @import("window.zig").Window;
const Cfg = @import("config.zig").Cfg{};

//TODO: For compatibility. Remove
pub const RenColor = extern struct {
    b: u8,
    g: u8,
    r: u8,
    a: u8,
};

//Color, by default rgba... But, SDL3 only supports bgra
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn new(r: u8, g: u8, b: u8, a: u8) Color {
        return .{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }

    //TODO: Remove after transistion

    pub fn toRenColor(self: *const Color) RenColor {
        return .{
            .r = self.r,
            .g = self.g,
            .b = self.b,
            .a = self.a,
        };
    }

    pub fn fromRenColor(rcol: RenColor) Color {
        return .{
            .r = rcol.r,
            .g = rcol.g,
            .b = rcol.b,
            .a = rcol.a,
        };
    }
};

pub const Renderer = struct {
    pub fn new(window: *const Window) Renderer {
        crender.ren_init(@ptrCast(window.window.value), @ptrCast(window.renderer.value));
        return .{};
    }
};
