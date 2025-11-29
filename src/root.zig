const std = @import("std");

const sdl = @import("sdl3");
const zlua = @import("zlua");

const Api = @import("api/api.zig").Api;
const RenCache = @import("rencache.zig").RenCache;
const Renderer = @import("renderer.zig").Renderer;
const Window = @import("window.zig").Window;

pub const Zite = struct {
    allocator: std.mem.Allocator,
    api: Api,
    ren_cache: RenCache,

    pub fn new(allocator: std.mem.Allocator) !Zite {
        const renderer = try Renderer.new();
        const ren_cache = try RenCache.new(renderer);

        const api = try Api.new(allocator, ren_cache);

        return .{
            .allocator = allocator,
            .api = api,
            .ren_cache = ren_cache,
        };
    }

    pub fn init(self: *Zite, args: [][]const u8) !void {
        try self.api.init(args);
    }

    pub fn deinit(self: *Zite) void {
        self.api.deinit(self.allocator);
    }
};
