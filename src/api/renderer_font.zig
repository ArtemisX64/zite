const zlua = @import("zlua");
const Cfg = @import("../config.zig").Cfg{};

//TODO: Remove
extern fn f_gc(L: ?*zlua.LuaState) c_int;
extern fn f_load(L: ?*zlua.LuaState) c_int;
extern fn f_set_tab_width(L: ?*zlua.LuaState) c_int;
extern fn f_get_width(L: ?*zlua.LuaState) c_int;
extern fn f_get_height(L: ?*zlua.LuaState) c_int;

pub const RendererFont = @This();

pub const libs = [_]zlua.FnReg{
    .{ .name = "__gc", .func = f_gc },
    .{ .name = "load", .func = f_load },
    .{ .name = "set_tab_width", .func = f_set_tab_width },
    .{ .name = "get_width", .func = f_get_width },
    .{ .name = "get_height", .func = f_get_height },
};

pub fn luaopenRendererFont(lua: *zlua.Lua) c_int {
    lua.newMetatable(Cfg.api_type_font) catch return 1;
    lua.setFuncs(&libs, 0);
    lua.pushValue(-1);
    lua.setField(-2, "__index");
    return 1;
}
