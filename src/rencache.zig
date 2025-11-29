const std = @import("std");

const Color = @import("types.zig").Color;
const Command = @import("types.zig").Command;
const Font = @import("types.zig").Font;
const Rect = @import("types.zig").Rect;
const Renderer = @import("renderer.zig").Renderer;

const Cfg = @import("config.zig").Cfg{};
pub const RenCache = struct {
    renderer: Renderer,

    command_buf: []u8,
    cmd_idx: usize,

    current_clip: Rect,
    show_debug: bool,

    pub fn new(rend: Renderer) !RenCache {
        const current_clip = Rect.new(0, 0, 0, 0);
        const command_buf = try std.heap.page_allocator.alloc(u8, Cfg.command_buf_size);
        @memset(command_buf, 0);
        const cmd_idx = 0;

        return .{
            .renderer = rend,
            .command_buf = command_buf,
            .cmd_idx = cmd_idx,
            .current_clip = current_clip,
            .show_debug = false,
        };
    }

    pub fn deinit(self: *RenCache) void {
        if (self.command_buf.len > 0) {
            std.heap.page_allocator.free(self.command_buf);
        }
        self.command_buf = &[_]u8{};
        self.cmd_idx = 0;
    }

    fn pushCommand(self: *RenCache, size: usize) ?*Command {
        // Align cmd_idx to Command alignment before allocating
        const aligned_idx = std.mem.alignForward(usize, self.cmd_idx, @alignOf(Command));

        if (aligned_idx + size > self.command_buf.len)
            return null;

        const ptr = self.command_buf[aligned_idx .. aligned_idx + size];
        self.cmd_idx = aligned_idx + size;

        @memset(ptr[0..@sizeOf(Command)], @as(u8, 0));

        return @ptrCast(@alignCast(ptr.ptr));
    }

    pub fn showDebug(self: *RenCache, enable: bool) void {
        self.show_debug = enable;
    }

    pub fn freeFont(self: *RenCache, font: *Font) void {
        const cmd = self.pushCommand(@sizeOf(Command)) orelse return;
        cmd.ty = 0; // CMD_FREE_FONT
        cmd.size = @intCast(@sizeOf(Command));
        cmd.font = font;
    }

    pub fn setClipRect(self: *RenCache, r: Rect) void {
        const cmd = self.pushCommand(@sizeOf(Command)) orelse return;
        cmd.ty = 1; // CMD_SET_CLIP
        cmd.size = @intCast(@sizeOf(Command));
        cmd.rect = r;
    }

    pub fn drawRect(self: *RenCache, r: Rect, c: Color) void {
        const cmd = self.pushCommand(@sizeOf(Command)) orelse return;
        cmd.ty = 3; // CMD_DRAW_RECT
        cmd.size = @intCast(@sizeOf(Command));
        cmd.rect = r;
        cmd.color = c;
    }

    pub fn drawText(
        self: *RenCache,
        font: *Font,
        text: [:0]const u8,
        x: i32,
        y: i32,
        color: Color,
    ) i32 {
        const text_len = text.len;
        const total_size = @sizeOf(Command) + text_len + 1;

        const cmd = self.pushCommand(total_size) orelse return x;

        cmd.ty = 2; // CMD_DRAW_TEXT
        cmd.size = @intCast(total_size);
        cmd.font = font;
        cmd.color = color;

        const w = self.renderer.getFontWidth(font, text) catch b: {
            std.debug.print("Error getting font width", .{});
            break :b 0;
        };

        const h = font.height;

        cmd.rect = Rect.new(x, y, w, h);
        cmd.tab_width = self.renderer.getFontTabWidth(font) catch 0;

        // Copy the text data into the command buffer
        const text_ptr = @intFromPtr(cmd) + @sizeOf(Command);
        const text_buf: [*]u8 = @ptrFromInt(text_ptr);
        @memcpy(text_buf[0..text_len], text);
        text_buf[text_len] = 0;

        cmd.text_len = @intCast(text_len);

        return x + w;
    }

    pub fn invalidate(self: *RenCache) void {
        _ = self;
    }

    pub fn endFrame(self: *RenCache) void {
        var i: usize = 0;

        self.current_clip = Rect.new(0, 0, 999999, 999999);

        while (i < self.cmd_idx) {
            i = std.mem.alignForward(usize, i, @alignOf(Command));

            if (i >= self.cmd_idx) break;

            const cmd: *Command = @ptrCast(@alignCast(self.command_buf.ptr + i));
            const size: usize = @intCast(cmd.size);

            switch (cmd.ty) {
                1 => { // CMD_SET_CLIP
                    self.current_clip = cmd.rect;
                    self.renderer.setClipRect(cmd.rect);
                },
                3 => { // CMD_DRAW_RECT
                    self.renderer.drawRect(cmd.rect, cmd.color);
                },
                2 => { // CMD_DRAW_TEXT
                    self.renderer.setFontTabWidth(cmd.font, cmd.tab_width) catch return;

                    // Calculate where the text data is stored
                    const text_ptr = @intFromPtr(cmd) + @sizeOf(Command);
                    const text_buf: [*]const u8 = @ptrFromInt(text_ptr);
                    const text: []const u8 = text_buf[0..cmd.text_len];

                    _ = self.renderer.drawText(cmd.font, text, cmd.rect.x, cmd.rect.y, cmd.color) catch b: {
                        std.debug.print("Error in endframe: renderer.drawText\n", .{});
                        break :b 0;
                    };
                },
                0 => { // CMD_FREE_FONT
                    self.renderer.freeFont(cmd.font);
                },
                else => {},
            }

            i += size;
        }

        self.renderer.window.renderer.present() catch {
            std.debug.print("Error in end frame: renderer.present\n", .{});
        };
        self.cmd_idx = 0;
    }
};
