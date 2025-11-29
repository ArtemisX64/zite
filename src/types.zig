const Texture = @import("sdl3").render.Texture;

const TrueType = @import("truetype.zig").TrueType;

const Cfg = @import("config.zig").Cfg{};
pub const Rect = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,

    pub fn new(x: i32, y: i32, width: i32, height: i32) Rect {
        return .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        };
    }
};

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
};

pub const Glyph = struct {
    w: u16,
    h: u16,
    off_x: i16,
    off_y: i16,
    advance: i16,
    x0: i32,
    y0: i32,
};

pub const GlyphSet = struct {
    texture: *Texture,
    glyphs: [Cfg.max_glyphset]Glyph,
    width: i32,
    height: i32,
};

pub const Font = struct {
    tt_bytes: []const u8,
    tt: TrueType,
    size: f32,
    height: i32,
    ascent: i32,
    sets: [256]?*GlyphSet,
};

pub const Command = struct {
    ty: i32,
    size: u32,
    rect: Rect,
    color: Color,
    font: *Font,
    tab_width: i32,
    text: [:0]const u8,
    text_len: u32,
};
