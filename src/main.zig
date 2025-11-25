const std = @import("std");
const zite = @import("zite");

const c = @cImport({
    @cInclude("api/api.h");
    @cInclude("renderer.h");

    @cInclude("lib/lua52/lua.h");
    @cInclude("lib/lua52/lauxlib.h");
    @cInclude("lib/lua52/lualib.h");
});

var window: ?*c.SDL_Window = null;

fn get_scale() f32 {
    return 1.0;
}

fn get_exe_filename(alloc: std.mem.Allocator) ![:0]u8 {
    // Get executable path as []u8 (NOT null terminated)
    const exe_path = try std.fs.selfExePathAlloc(alloc);
    defer alloc.free(exe_path);

    const cexe_path: [:0]u8 = try std.fmt.allocPrintSentinel(alloc, "{s}", .{exe_path}, 0);
    // Convert to null-terminated C string
    return cexe_path;
}

fn init_window_icon() void {
    // no-op for Linux
}

pub fn main() !void {
    var zWindow = try zite.ZWindow.new();
    defer zWindow.deinit();
    init_window_icon();
    c.ren_init(@ptrCast(zWindow.window));

    const L = c.luaL_newstate() orelse return error.LuaInitFail;
    defer c.lua_close(L);

    c.luaL_openlibs(L);
    c.api_load_libs(L);

    // ARGS
    c.lua_newtable(L);
    const args = std.os.argv;
    for (args, 0..) |arg, i| {
        _ = c.lua_pushstring(L, arg);
        c.lua_rawseti(L, -2, @intCast(i + 1));
    }
    c.lua_setglobal(L, "ARGS");

    _ = c.lua_pushstring(L, "1.11");
    c.lua_setglobal(L, "VERSION");

    _ = c.lua_pushstring(L, c.SDL_GetPlatform());
    c.lua_setglobal(L, "PLATFORM");

    c.lua_pushnumber(L, get_scale());
    c.lua_setglobal(L, "SCALE");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var exename = try get_exe_filename(gpa.allocator());
    // lua_pushstring expects C string pointer
    _ = c.lua_pushstring(L, @as([*c]const u8, @ptrCast(exename[0..])));
    c.lua_setglobal(L, "EXEFILE");

    // run bootstrap script (load + pcall to avoid Lua macro issues)
    const script =
        \\local core
        \\xpcall(function()
        \\  SCALE = tonumber(os.getenv("LITE_SCALE")) or SCALE
        \\  PATHSEP = package.config:sub(1, 1)
        \\  EXEDIR = EXEFILE:match("^(.+)[/\\\\].*$")
        \\  package.path = EXEDIR .. '/data/?.lua;' .. package.path
        \\  package.path = EXEDIR .. '/data/?/init.lua;' .. package.path
        \\  core = require('core')
        \\  core.init()
        \\  core.run()
        \\end, function(err)
        \\  print('Error: ' .. tostring(err))
        \\  print(debug.traceback(nil, 2))
        \\  if core and core.on_error then
        \\    pcall(core.on_error, err)
        \\  end
        \\  os.exit(1)
        \\end)
    ;

    if (c.luaL_loadstring(L, script) != 0) {
        var len: usize = 0;
        const msg = c.lua_tolstring(L, -1, @as([*c]usize, @ptrCast(&len)));
        std.debug.print("Lua load failed: {s}\n", .{msg});
    }

    if (c.lua_pcallk(L, 0, c.LUA_MULTRET, 0, 0, null) != 0) {
        var len: usize = 0;
        const msg = c.lua_tolstring(L, -1, @as([*c]usize, @ptrCast(&len)));
        std.debug.print("Lua runtime error: {s}\n", .{msg});
    }
}
