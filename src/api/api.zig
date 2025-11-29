const std = @import("std");
const Allocator = std.mem.Allocator;

const getPlatform = @import("sdl3").platform.get;
const zlua = @import("zlua");

const RenCache = @import("../rencache.zig").RenCache;
const Renderer = @import("../renderer.zig").Renderer;
const Window = @import("../window.zig").Window;
const APIRenderer = @import("renderer.zig").APIRenderer;
const RenFont = @import("renderer_font.zig").RendererFont;
const System = @import("system.zig").System;

const Cfg = @import("../config.zig").Cfg{};
//Workaround for k
fn noCont(_: ?*zlua.LuaState, _: c_int, _: zlua.Context) callconv(.c) c_int {
    return 0;
}

//Initialises Lua and also, general api functions
pub const Api = struct {
    lua: *zlua.Lua,
    exe_path: []const u8,
    pub fn new(alloc: Allocator, ren_cache: RenCache) !Api {
        const lua = try zlua.Lua.init(alloc);
        lua.newTable();
        const exe_path = try std.fs.selfExePathAlloc(alloc);

        System.window = ren_cache.renderer.window.window;
        System.allocator = alloc;
        APIRenderer.ren_cache = ren_cache;

        return Api{
            .lua = lua,
            .exe_path = exe_path,
        };
    }
    pub fn init(self: *Api, args: [][]const u8) !void {
        //LOAD The Initial Arguments
        self.lua.openLibs();

        for (args, 0..) |arg, i| {
            _ = self.lua.pushString(arg);
            self.lua.rawSetIndex(-2, @intCast(i + 1));
        }
        self.lua.setGlobal("ARGS");

        _ = self.lua.pushString(Cfg.version);
        self.lua.setGlobal("VERSION");

        _ = self.lua.pushStringZ(getPlatform());
        self.lua.setGlobal("PLATFORM");

        _ = self.lua.pushNumber(1.0);
        self.lua.setGlobal("SCALE");

        _ = self.lua.pushString(self.exe_path);
        self.lua.setGlobal("EXEFILE");

        self.load_libs();

        try self.lua.loadString(Cfg.script);

        try self.lua.protectedCallCont(.{
            .results = zlua.mult_return,
            .k = noCont,
            .ctx = 0,
        });
    }

    pub fn deinit(self: *Api, allocator: Allocator) void {
        allocator.free(self.exe_path);
        self.lua.deinit();
        APIRenderer.ren_cache.renderer.window.deinit();
    }

    fn load_libs(self: *Api) void {
        //Functions to be loaded to lua global table
        const libs: [2]zlua.FnReg = .{
            .{ .name = "system", .func = System.lLuaOpenSystem },
            .{ .name = "renderer", .func = APIRenderer.lLuaopenRenderer },
        };

        for (libs) |l| {
            self.lua.requireF(l.name, l.func.?, true);
        }
    }
};
