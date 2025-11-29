//Head
const zlua = @import("zlua");

const RenCache = @import("../rencache.zig").RenCache;
const types = @import("../types.zig");
const Color = types.Color;
const Rect = types.Rect;
pub const RendererFont = @import("renderer_font.zig").RendererFont;

const Cfg = @import("../config.zig").Cfg{};

pub var ren_cache: RenCache = undefined;

pub const APIRenderer = @This();

pub const libs = [_]zlua.FnReg{
    .{ .name = "show_debug", .func = lShowDebug },
    .{ .name = "get_size", .func = lGetSize },
    .{ .name = "begin_frame", .func = lBeginFrame },
    .{ .name = "end_frame", .func = lEndFrame },
    .{ .name = "set_clip_rect", .func = lSetClipRect },
    .{ .name = "draw_rect", .func = lDrawRect },
    .{ .name = "draw_text", .func = lDrawText },
};

fn checkColor(lua: *zlua.Lua, idx: i32, def: u8) Color {
    if (lua.isNoneOrNil(idx)) {
        return .{ .r = def, .b = def, .g = def, .a = 255 };
    }
    _ = lua.rawGetIndex(idx, 1);
    _ = lua.rawGetIndex(idx, 2);
    _ = lua.rawGetIndex(idx, 3);
    _ = lua.rawGetIndex(idx, 4);

    const r: u8 = @intFromFloat(lua.checkNumber(-4));
    const g: u8 = @intFromFloat(lua.checkNumber(-3));
    const b: u8 = @intFromFloat(lua.checkNumber(-2));
    const a: u8 = @intFromFloat(lua.optNumber(-1) orelse 255.0);
    lua.pop(4);

    const color = Color.new(r, g, b, a);
    return color;
}

pub fn lLuaopenRenderer(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return luaopenRenderer(@ptrCast(lua.?));
}

pub fn lShowDebug(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return showDebug(@ptrCast(lua.?));
}

pub fn lGetSize(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return getSize(@ptrCast(lua.?));
}

pub fn lBeginFrame(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return beginFrame(@ptrCast(lua.?));
}

pub fn lEndFrame(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return endFrame(@ptrCast(lua.?));
}

pub fn lSetClipRect(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return setClipRect(@ptrCast(lua.?));
}

pub fn lDrawRect(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return drawRect(@ptrCast(lua.?));
}

pub fn lDrawText(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return drawText(@ptrCast(lua.?));
}

fn luaopenRenderer(lua: *zlua.Lua) c_int {
    lua.newLib(&libs);
    RendererFont.ren_cache = ren_cache;
    _ = RendererFont.luaopenRendererFont(lua);
    lua.setField(-2, "font");
    return 1;
}

fn showDebug(lua: *zlua.Lua) c_int {
    lua.checkAny(1);
    ren_cache.showDebug(lua.toBoolean(1));
    return 0;
}

fn getSize(lua: *zlua.Lua) c_int {
    const size = ren_cache.renderer.getSize() catch .{ 0, 0 };
    const w = size.@"0";
    const h = size.@"1";
    lua.pushNumber(@floatFromInt(w));
    lua.pushNumber(@floatFromInt(h));
    return 2;
}

fn beginFrame(lua: *zlua.Lua) c_int {
    _ = lua;
    return 0;
}

fn endFrame(lua: *zlua.Lua) c_int {
    _ = lua;
    ren_cache.endFrame();
    return 0;
}

fn setClipRect(lua: *zlua.Lua) c_int {
    var rect = Rect.new(0, 0, 0, 0);
    rect.x = @intFromFloat(lua.checkNumber(1.0));
    rect.y = @intFromFloat(lua.checkNumber(2.0));
    rect.width = @intFromFloat(lua.checkNumber(3.0));
    rect.height = @intFromFloat(lua.checkNumber(4.0));

    ren_cache.setClipRect(rect);
    return 0;
}

fn drawRect(lua: *zlua.Lua) c_int {
    var rect = Rect.new(0, 0, 0, 0);
    rect.x = @intFromFloat(lua.checkNumber(1.0));
    rect.y = @intFromFloat(lua.checkNumber(2.0));
    rect.width = @intFromFloat(lua.checkNumber(3.0));
    rect.height = @intFromFloat(lua.checkNumber(4.0));

    const color = checkColor(lua, 5, 255);
    ren_cache.drawRect(rect, color);
    return 0;
}

fn drawText(lua: *zlua.Lua) c_int {
    const font_ptr_ptr = lua.checkUserdata(*types.Font, 1, Cfg.api_type_font);
    const font = font_ptr_ptr.*; //As font is a double ptr
    const text = lua.checkString(2);
    var x: i32 = @intFromFloat(lua.checkNumber(3));
    const y: i32 = @intFromFloat(lua.checkNumber(4));
    const color = checkColor(lua, 5, 255);
    x = ren_cache.drawText(font, text, x, y, color);
    lua.pushNumber(@floatFromInt(x));
    return 1;
}
