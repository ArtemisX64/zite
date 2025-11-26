const zlua = @import("zlua");
const std = @import("std");
const Allocator = std.mem.Allocator;

extern fn luaopen_system(L: ?*zlua.LuaState) c_int;
extern fn luaopen_renderer(L: ?*zlua.LuaState) c_int;

fn luaopenSystem(L: ?*zlua.LuaState) callconv(.c) c_int {
    return luaopen_system(@ptrCast(L));
}

fn luaopenRenderer(L: ?*zlua.LuaState) callconv(.c) c_int {
    return luaopen_renderer(@ptrCast(L));
}

const libs: [2]zlua.FnReg = .{
    .{ .name = "system", .func = luaopenSystem },
    .{ .name = "renderer", .func = luaopenRenderer },
};

pub const Api = struct {
    lua: *zlua.Lua,
    pub fn new(alloc: Allocator) !Api {
        const lua = try zlua.Lua.init(alloc);
        return Api{ .lua = lua };
    }
    pub fn init(self: *Api) void {
        for (libs) |l| {
            zlua.Lua.requireF(self.lua, l.name, l.func.?, true);
        }
    }

    pub fn deinit(self: *Api) void {
        self.lua.deinit();
    }
};
