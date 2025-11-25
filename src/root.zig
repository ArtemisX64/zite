const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});
const std = @import("std");

pub const ZWindow = struct {
    window: *sdl.SDL_Window,

    pub fn new() !ZWindow {
        if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_EVENTS) != 0) {
            std.debug.print("Error Initialising SDL: {s}\n", .{sdl.SDL_GetError()});
            return error.Uninitialised;
        }

        sdl.SDL_EnableScreenSaver();
        _ = sdl.SDL_EventState(sdl.SDL_DROPFILE, sdl.SDL_ENABLE);

        _ = sdl.SDL_SetHint("SDL_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR", "0");
        _ = sdl.SDL_SetHint("SDL_MOUSE_FOCUS_CLICKTHROUGH", "1");

        var dm: sdl.SDL_DisplayMode = undefined;
        _ = sdl.SDL_GetCurrentDisplayMode(0, &dm);

        const window = sdl.SDL_CreateWindow(
            "",
            sdl.SDL_WINDOWPOS_UNDEFINED,
            sdl.SDL_WINDOWPOS_UNDEFINED,
            @intFromFloat(@as(f32, @floatFromInt(dm.w)) * 0.8),
            @intFromFloat(@as(f32, @floatFromInt(dm.h)) * 0.8),
            sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_ALLOW_HIGHDPI | sdl.SDL_WINDOW_HIDDEN,
        );

        if (window == null) {
            std.debug.print("SDL_CreateWindow failed: {s}\n", .{sdl.SDL_GetError()});
            return error.WindowCreationFailed;
        }

        return ZWindow{
            .window = window.?,
        };
    }

    pub fn deinit(self: *ZWindow) void {
        sdl.SDL_DestroyWindow(self.window);
        sdl.SDL_Quit();
    }
};
