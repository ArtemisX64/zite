const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const ZWindow = struct {
    window: sdl.SDL_Window,

    
};
