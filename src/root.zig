const sdl2 = @cImport(
    @cInclude("SDL2/SDL.h"),
);
const sdl = @import("sdl3");

const std = @import("std");

pub const ZWindow = struct {
    window: sdl.video.Window,
    flags: sdl.InitFlags,
    renderer: sdl.render.Renderer,

    pub fn new() !ZWindow {
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

        return ZWindow{
            .window = window,
            .flags = flags,
            .renderer = renderer,
        };
    }

    pub fn deinit(self: *ZWindow) void {
        self.window.deinit();
        sdl.quit(self.flags);
        sdl.shutdown();
    }
};

//LEGACY SDL2
// pub const ZWindowO = struct {
//     window: *sdl2.SDL_Window,

//     pub fn new() !ZWindowO {
//         if (sdl2.SDL_Init(sdl2.SDL_INIT_VIDEO | sdl2.SDL_INIT_EVENTS) != 0) {
//             std.debug.print("Error Initialising SDL: {s}\n", .{sdl2.SDL_GetError()});
//             return error.Uninitialised;
//         }

//         sdl2.SDL_EnableScreenSaver();

//         _ = sdl2.SDL_EventState(sdl2.SDL_DROPFILE, sdl2.SDL_ENABLE);

//         _ = sdl2.SDL_SetHint("SDL_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR", "0");
//         _ = sdl2.SDL_SetHint("SDL_MOUSE_FOCUS_CLICKTHROUGH", "1");

//         var dm: sdl2.SDL_DisplayMode = undefined;
//         _ = sdl2.SDL_GetCurrentDisplayMode(0, &dm);

//         const window = sdl2.SDL_CreateWindow(
//             "",
//             sdl2.SDL_WINDOWPOS_UNDEFINED,
//             sdl2.SDL_WINDOWPOS_UNDEFINED,
//             @intFromFloat(@as(f32, @floatFromInt(dm.w)) * 0.8),
//             @intFromFloat(@as(f32, @floatFromInt(dm.h)) * 0.8),
//             sdl2.SDL_WINDOW_RESIZABLE | sdl2.SDL_WINDOW_ALLOW_HIGHDPI | sdl2.SDL_WINDOW_HIDDEN,
//         );

//         if (window == null) {
//             std.debug.print("SDL_CreateWindow failed: {s}\n", .{sdl2.SDL_GetError()});
//             return error.WindowCreationFailed;
//         }

//         return ZWindowO{
//             .window = window.?,
//         };
//     }

//     pub fn deinit(self: *ZWindowO) void {
//         sdl2.SDL_DestroyWindow(self.window);
//         sdl2.SDL_Quit();
//     }
// };
