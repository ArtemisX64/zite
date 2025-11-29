const std = @import("std");

const sdl = @import("sdl3");

const Color = @import("types.zig").Color;
const Font = @import("types.zig").Font;
const Glyph = @import("types.zig").Glyph;
const GlyphSet = @import("types.zig").GlyphSet;
const Rect = @import("types.zig").Rect;
const TrueType = @import("truetype.zig");
const Window = @import("window.zig").Window;

const Cfg = @import("config.zig").Cfg{};

pub const Renderer = struct {
    window: Window,
    clip: Rect,

    pub fn utf8ToCodepoint(text: []const u8, idx: *usize) u21 {
        var i = idx.*;

        if (i >= text.len) {
            idx.* = text.len;
            return 0xFFFD;
        }

        const b0: u21 = @intCast(text[i]);
        i += 1;

        if (b0 < 0x80) {
            idx.* = i;
            return b0;
        }

        var cp: u21 = 0;

        if (b0 < 0xE0) {
            if (i >= text.len) {
                idx.* = text.len;
                return 0xFFFD;
            }
            cp = ((b0 & 0x1F) << 6) | (@as(u21, @intCast(text[i])) & 0x3F);
            idx.* = i + 1;
            return cp;
        }

        if (b0 < 0xF0) {
            if (i + 1 >= text.len) {
                idx.* = text.len;
                return 0xFFFD;
            }
            cp = ((b0 & 0x0F) << 12) | ((@as(u21, @intCast(text[i])) & 0x3F) << 6) | (@as(u21, @intCast(text[i + 1])) & 0x3F);
            idx.* = i + 2;
            return cp;
        }
        if (i + 2 >= text.len) {
            idx.* = text.len;
            return 0xFFFD;
        }
        cp = ((b0 & 0x07) << 18) | ((@as(u21, @intCast(text[i])) & 0x3F) << 12) | ((@as(u21, @intCast(text[i + 1])) & 0x3F) << 6) | (@as(u21, @intCast(text[i + 2])) & 0x3F);
        idx.* = i + 3;
        return cp;
    }

    pub fn new() !Renderer {
        const win = try Window.new();
        const size = try win.window.getSize();
        const width = size.@"0";
        const height = size.@"1";

        const clip: Rect = .{
            .x = 0,
            .y = 0,
            .width = @intCast(width),
            .height = @intCast(height),
        };

        try win.renderer.setDrawBlendMode(.blend);

        return .{
            .window = win,
            .clip = clip,
        };
    }

    pub fn setClipRect(self: *Renderer, r: Rect) void {
        self.clip = r;
        self.window.renderer.setClipRect(.{
            .h = r.height,
            .w = r.width,
            .x = r.x,
            .y = r.y,
        }) catch {};
    }

    pub fn getSize(self: *Renderer) !struct { usize, usize } {
        return try self.window.window.getSize();
    }

    pub fn loadFont(self: *Renderer, path: []const u8, size: f32) !*Font {
        _ = self;

        const tt_bytes = try std.fs.cwd().readFileAlloc(path, std.heap.page_allocator, .limited(16 * 1024 * 1024));
        errdefer std.heap.page_allocator.free(tt_bytes);

        var tt = try TrueType.load(tt_bytes);

        const vm = tt.verticalMetrics();
        const scale = tt.scaleForPixelHeight(size);
        const height: i32 = @intFromFloat((@as(f32, @floatFromInt(vm.ascent - vm.descent + vm.line_gap))) * scale + 0.5);
        const ascent: i32 = @intFromFloat(@as(f32, @floatFromInt(vm.ascent)) * scale + 0.5); // ADD THIS

        const font = try std.heap.page_allocator.create(Font);
        errdefer std.heap.page_allocator.destroy(font);

        font.* = .{
            .tt_bytes = tt_bytes,
            .tt = tt,
            .size = size,
            .height = height,
            .ascent = ascent, // ADD THIS
            .sets = [_]?*GlyphSet{null} ** 256,
        };

        return font;
    }

    pub fn loadGlyphSet(self: *Renderer, font: *Font, idx: usize) !*GlyphSet {
        var set = try std.heap.page_allocator.create(GlyphSet);
        errdefer std.heap.page_allocator.destroy(set);

        set.width = 128;
        set.height = 128;

        const scale = font.tt.scaleForPixelHeight(font.size + 2);

        while (true) {
            var rgba = try std.heap.page_allocator.alloc(u8, @intCast(set.width * set.height * 4));
            defer std.heap.page_allocator.free(rgba);
            @memset(rgba, 0);

            var pen_x: i32 = 0;
            var pen_y: i32 = font.height;
            var all_fit = true;

            for (0..Cfg.max_glyphset) |i| {
                const cp: u21 = @intCast(idx * Cfg.max_glyphset + i);
                const glyph_index_opt = font.tt.codepointGlyphIndex(cp);
                const glyph_idx: TrueType.GlyphIndex = glyph_index_opt orelse {
                    set.glyphs[i] = Glyph{
                        .w = 0,
                        .h = 0,
                        .off_x = 0,
                        .off_y = 0,
                        .advance = 0,
                        .x0 = 0,
                        .y0 = 0,
                    };
                    continue;
                };

                if (@intFromEnum(glyph_idx) >= font.tt.glyphs_len) {
                    set.glyphs[i] = Glyph{
                        .w = 0,
                        .h = 0,
                        .off_x = 0,
                        .off_y = 0,
                        .advance = 0,
                        .x0 = 0,
                        .y0 = 0,
                    };
                    continue;
                }

                const hm = font.tt.glyphHMetrics(glyph_idx);
                const advance: i32 = @intFromFloat(@as(f32, @floatFromInt(hm.advance_width)) * scale);

                var pixels = std.ArrayListUnmanaged(u8){};
                defer pixels.deinit(std.heap.page_allocator);

                const gbm = font.tt.glyphBitmap(
                    std.heap.page_allocator,
                    &pixels,
                    glyph_idx,
                    scale,
                    scale,
                ) catch |err| {
                    if (err == error.GlyphNotFound) {
                        set.glyphs[i] = Glyph{
                            .w = 0,
                            .h = 0,
                            .off_x = 0,
                            .off_y = 0,
                            .advance = @intCast(advance),
                            .x0 = 0,
                            .y0 = 0,
                        };
                        continue;
                    }
                    return err;
                };

                const w = gbm.width;
                const h = gbm.height;

                if (w == 0 or h == 0) {
                    set.glyphs[i] = Glyph{
                        .w = 0,
                        .h = 0,
                        .off_x = gbm.off_x,
                        .off_y = gbm.off_y,
                        .advance = @intCast(advance),
                        .x0 = 0,
                        .y0 = 0,
                    };
                    continue;
                }

                if (pen_x + w + 2 > set.width) {
                    pen_x = 0;
                    pen_y += font.height + 2;
                }

                if (pen_y + h > set.height) {
                    set.width *= 2;
                    set.height *= 2;
                    all_fit = false;
                    break;
                }

                for (0..h) |yy| {
                    for (0..w) |xx| {
                        const a = pixels.items[yy * w + xx];

                        const dst_x: isize = @as(isize, @intCast(pen_x)) + @as(isize, @intCast(xx));
                        const dst_y: isize = @as(isize, @intCast(pen_y)) + @as(isize, @intCast(yy));

                        if (dst_x < 0 or dst_y < 0) continue;
                        if (dst_x >= set.width or dst_y >= set.height) continue;

                        const ux = @as(usize, @intCast(dst_x));
                        const uy = @as(usize, @intCast(dst_y));

                        const idx_rgba = (uy * @as(usize, @intCast(set.width)) + ux) * 4;
                        rgba[idx_rgba + 0] = 255;
                        rgba[idx_rgba + 1] = 255;
                        rgba[idx_rgba + 2] = 255;
                        rgba[idx_rgba + 3] = a;
                    }
                }

                set.glyphs[i] = Glyph{
                    .w = w,
                    .h = h,
                    .off_x = gbm.off_x,
                    .off_y = gbm.off_y,
                    .advance = @intCast(advance),
                    .x0 = pen_x,
                    .y0 = pen_y,
                };

                pen_x += w + 2;
            }

            if (!all_fit) {
                continue;
            }

            const texture = try std.heap.page_allocator.create(sdl.render.Texture);
            errdefer std.heap.page_allocator.destroy(texture);

            texture.* = try sdl.render.Texture.init(
                self.window.renderer,
                .array_rgba_32,
                .static,
                @intCast(set.width),
                @intCast(set.height),
            );

            set.texture = texture;

            try set.texture.update(null, rgba.ptr, @intCast(set.width * 4));
            try set.texture.setBlendMode(.blend);

            break;
        }

        return set;
    }

    pub fn setFontTabWidth(self: *Renderer, font: *Font, n: i32) !void {
        const state = try self.getGlyphSet(font, '\t');
        state.glyphs['\t'].advance = @intCast(n);
    }

    pub fn getGlyphSet(self: *Renderer, font: *Font, cp: u21) !*GlyphSet {
        const idx = cp >> 8;

        if (idx >= font.sets.len) {
            const replacement_idx: usize = 0xFF;
            if (font.sets[replacement_idx]) |p| return p;
            const set = try self.loadGlyphSet(font, replacement_idx);
            font.sets[replacement_idx] = set;
            return set;
        }

        if (font.sets[idx]) |p| return p;

        const set = try self.loadGlyphSet(font, idx);
        font.sets[idx] = set;
        return set;
    }

    pub fn getFontWidth(self: *Renderer, font: *Font, text: []const u8) !i32 {
        var i: usize = 0;
        var x: i32 = 0;

        while (i < text.len) {
            var cp = utf8ToCodepoint(text, &i);

            if (cp >> 8 >= 256) {
                cp = 0xFFFD;
            }

            const state = try self.getGlyphSet(font, cp);
            const glyph = state.glyphs[cp & 0xFF];
            x += @as(i32, @intCast(glyph.advance));
        }

        return x;
    }

    pub fn getFontHeight(self: *Renderer, font: *Font) i32 {
        _ = self;
        return font.height;
    }

    pub fn getFontTabWidth(self: *Renderer, font: *Font) !i32 {
        const state = try self.getGlyphSet(font, '\t');
        return state.glyphs['\t'].advance;
    }

    pub fn drawText(
        self: *Renderer,
        font: *Font,
        text: []const u8,
        x0: i32,
        y0: i32,
        color: Color,
    ) !i32 {
        var i: usize = 0;
        var x = x0;
        const y = y0;

        while (i < text.len) {
            var cp = utf8ToCodepoint(text, &i);

            if (cp == 0xFFFD and i >= text.len) break;

            if (cp >> 8 >= 256) {
                cp = 0xFFFD;
            }

            const state = try self.getGlyphSet(font, cp);
            const glyph = state.glyphs[cp & 0xFF];

            if (glyph.w > 0 and glyph.h > 0) {
                const src = sdl.rect.FRect{
                    .x = @floatFromInt(glyph.x0),
                    .y = @floatFromInt(glyph.y0),
                    .w = @floatFromInt(glyph.w),
                    .h = @floatFromInt(glyph.h),
                };

                const dst = sdl.rect.FRect{
                    .x = @floatFromInt(x + glyph.off_x),
                    .y = @floatFromInt(y + font.ascent + glyph.off_y),
                    .w = @floatFromInt(glyph.w),
                    .h = @floatFromInt(glyph.h),
                };

                try state.texture.setColorMod(color.r, color.g, color.b);
                try state.texture.setAlphaMod(color.a);

                try self.window.renderer.renderTexture(state.texture.*, src, dst);
            }

            x += @as(i32, @intCast(glyph.advance));
        }
        return x;
    }

    pub fn freeFont(_: *Renderer, font: *Font) void {
        for (font.sets) |set| {
            if (set) |p| {
                p.texture.deinit();
                std.heap.page_allocator.destroy(p.texture);
                std.heap.page_allocator.destroy(p);
            }
        }
        std.heap.page_allocator.free(font.tt_bytes);
        std.heap.page_allocator.destroy(font);
    }

    pub fn drawImage(
        self: *Renderer,
        tex: *sdl.render.Texture,
        sub: Rect,
        x: i32,
        y: i32,
        color: Color,
    ) !void {
        try tex.setColorMod(color.r, color.g, color.b);
        try tex.setAlphaMod(color.a);

        const src = sdl.rect.FRect{
            .x = @floatFromInt(sub.x),
            .y = @floatFromInt(sub.y),
            .w = @floatFromInt(sub.width),
            .h = @floatFromInt(sub.height),
        };

        const dest = sdl.rect.FRect{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .w = @floatFromInt(sub.width),
            .h = @floatFromInt(sub.height),
        };

        try self.window.renderer.renderTexture(tex.*, src, dest);
    }

    pub fn drawRect(self: *Renderer, rect: Rect, c: Color) void {
        self.window.renderer.setDrawColor(.{ .a = c.a, .r = c.r, .g = c.g, .b = c.b }) catch {
            std.debug.print("Error setting draw color in fill rect", .{});
            return;
        };
        const r = sdl.rect.FRect{
            .x = @floatFromInt(rect.x),
            .y = @floatFromInt(rect.y),
            .w = @floatFromInt(rect.width),
            .h = @floatFromInt(rect.height),
        };

        self.window.renderer.renderFillRect(r) catch {
            std.debug.print("Error drawing fill rect", .{});
            return;
        };
    }
};
