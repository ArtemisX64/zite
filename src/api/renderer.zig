//TODO: Remove it in future
const rd = @cImport(@cInclude("renderer.h"));
const rc = @cImport(@cInclude("rencache.h"));
//Head
const renderer = @import("../renderer.zig");
const Color = renderer.Color;
const RendererFont = @import("renderer_font.zig").RendererFont;

//FIXME: To remove
const RenColor = renderer.RenColor;
extern fn f_show_debug(L: ?*zlua.LuaState) c_int;
extern fn f_get_size(L: ?*zlua.LuaState) c_int;
extern fn f_begin_frame(L: ?*zlua.LuaState) c_int;
extern fn f_end_frame(L: ?*zlua.LuaState) c_int;
extern fn f_set_clip_rect(L: ?*zlua.LuaState) c_int;
extern fn f_draw_rect(L: ?*zlua.LuaState) c_int;
extern fn f_draw_text(L: ?*zlua.LuaState) c_int;

const zlua = @import("zlua");

pub const Renderer = @This();

pub const libs = [_]zlua.FnReg{
    .{ .name = "show_debug", .func = f_show_debug },
    .{ .name = "get_size", .func = f_get_size },
    .{ .name = "begin_frame", .func = f_begin_frame },
    .{ .name = "end_frame", .func = f_end_frame },
    .{ .name = "set_clip_rect", .func = f_set_clip_rect },
    .{ .name = "draw_rect", .func = f_draw_rect },
    .{ .name = "draw_text", .func = f_draw_text },
};

//FIXME: Remove public visibility
pub fn checkColor(lua: *zlua.Lua, idx: i32, def: u8) Color {
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

fn luaopenRenderer(lua: *zlua.Lua) c_int {
    lua.newLib(&libs);
    _ = RendererFont.luaopenRendererFont(lua);
    lua.setField(-2, "font");
    return 1;
}
