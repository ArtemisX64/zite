const std = @import("std");

const zlua = @import("zlua");

const RenCache = @import("../rencache.zig").RenCache;
const Font = @import("../types.zig").Font;

const Cfg = @import("../config.zig").Cfg{};
pub const RendererFont = @This();

pub var ren_cache: RenCache = undefined;

pub const libs = [_]zlua.FnReg{
    .{ .name = "__gc", .func = lGc },
    .{ .name = "load", .func = lLoad },
    .{ .name = "set_tab_width", .func = lSetTabWidth },
    .{ .name = "get_width", .func = lGetWidth },
    .{ .name = "get_height", .func = lGetHeight },
};

pub fn luaopenRendererFont(lua: *zlua.Lua) c_int {
    lua.newMetatable(Cfg.api_type_font) catch return 1;
    lua.setFuncs(&libs, 0);
    lua.pushValue(-1);
    lua.setField(-2, "__index");
    return 1;
}

fn lLoad(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return Load(@ptrCast(lua.?));
}

fn lGc(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return gc(@ptrCast(lua.?));
}

fn lGetWidth(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return getWidth(@ptrCast(lua.?));
}

fn lGetHeight(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return getHeight(@ptrCast(lua.?));
}

fn lSetTabWidth(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return setTabWidth(@ptrCast(lua.?));
}

fn Load(lua: *zlua.Lua) c_int {
    const file_name = lua.checkString(1);
    const size: f32 = @floatCast(lua.checkNumber(2));

    // userdata holds a *Font
    const fnt = lua.newUserdata(*Font, 0);

    // metatable
    lua.setMetatableRegistry(Cfg.api_type_font);

    // load font
    const path = std.mem.sliceTo(file_name, 0);
    const font = ren_cache.renderer.loadFont(path, size) catch |err| {
        std.log.err("{any}", .{err});
        lua.raiseErrorStr("Failed to load font", .{});
        return 1;
    };

    // store pointer, not struct
    fnt.* = font;

    return 1;
}

fn setTabWidth(lua: *zlua.Lua) c_int {
    const fnt = lua.checkUserdata(*Font, 1, Cfg.api_type_font);
    const n: i32 = @intFromFloat(lua.checkNumber(2));
    ren_cache.renderer.setFontTabWidth(fnt.*, n) catch return 0;
    return 0;
}

fn gc(lua: *zlua.Lua) c_int {
    const fnt = lua.checkUserdata(*Font, 1, Cfg.api_type_font);

    ren_cache.freeFont(fnt.*);

    return 0;
}

fn getWidth(lua: *zlua.Lua) c_int {
    const fnt = lua.checkUserdata(*Font, 1, Cfg.api_type_font);
    const text = lua.checkString(2);
    lua.pushInteger(@intCast(ren_cache.renderer.getFontWidth(fnt.*, text) catch 0));
    return 1;
}

fn getHeight(lua: *zlua.Lua) c_int {
    const fnt = lua.checkUserdata(*Font, 1, Cfg.api_type_font);
    lua.pushInteger(@intCast(ren_cache.renderer.getFontHeight(fnt.*)));
    return 1;
}
