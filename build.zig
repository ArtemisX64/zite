const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(
        .{
            .default_target = .{
                .cpu_arch = .x86_64,
            },
        },
    );
    const optimize = b.standardOptimizeOption(.{});

    const c_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });
    c_module.addCSourceFiles(
        .{
            .files = &.{
                //"src/main.c",
                "src/renderer.c",
                "src/rencache.c",
                "src/api/renderer.c",
                "src/api/renderer_font.c",
                "src/api/system.c",
                "src/lib/lua52/lapi.c",
                "src/lib/lua52/lauxlib.c",
                "src/lib/lua52/lbaselib.c",
                "src/lib/lua52/lbitlib.c",
                "src/lib/lua52/lcode.c",
                "src/lib/lua52/lcorolib.c",
                "src/lib/lua52/lctype.c",
                "src/lib/lua52/ldblib.c",
                "src/lib/lua52/ldebug.c",
                "src/lib/lua52/ldo.c",
                "src/lib/lua52/ldump.c",
                "src/lib/lua52/lfunc.c",
                "src/lib/lua52/lgc.c",
                "src/lib/lua52/linit.c",
                "src/lib/lua52/liolib.c",
                "src/lib/lua52/llex.c",
                "src/lib/lua52/lmathlib.c",
                "src/lib/lua52/lmem.c",
                "src/lib/lua52/loadlib.c",
                "src/lib/lua52/lobject.c",
                "src/lib/lua52/lopcodes.c",
                "src/lib/lua52/loslib.c",
                "src/lib/lua52/lparser.c",
                "src/lib/lua52/lstate.c",
                "src/lib/lua52/lstring.c",
                "src/lib/lua52/lstrlib.c",
                "src/lib/lua52/ltable.c",
                "src/lib/lua52/ltablib.c",
                "src/lib/lua52/ltm.c",
                "src/lib/lua52/lundump.c",
                "src/lib/lua52/lvm.c",
                "src/lib/lua52/lzio.c",
                "src/lib/stb/stb_truetype.c",
            },
            .flags = &.{
                "-Wall",
                "-O3",
                "-g",
                "-std=gnu11",
                "-fwrapv",
                "-fno-sanitize=undefined",
                "-fno-strict-aliasing",
                "-Isrc",
                "-DLUA_USE_POSIX",
            },
            .language = .c,
        },
    );

    c_module.addIncludePath(.{
        .cwd_relative = "src",
    });
    c_module.addIncludePath(.{ .cwd_relative = "src/lib/lua52" });

    c_module.linkSystemLibrary("m", .{});
    // c_module.linkSystemLibrary("SDL3", .{});

    const mod = b.addModule("zite", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "zite",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/main.zig"),
            .link_libc = true, //TODO: Remove it once replaced fully by zig
            .imports = &.{
                .{
                    .name = "czite",
                    .module = c_module,
                },
                .{
                    .name = "zite",
                    .module = mod,
                },
            },
        }),
    });

    const sdl3 = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
    });

    const lua_dep = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
        .lang = .lua52,
        .shared = true,
    });

    mod.addImport("sdl3", sdl3.module("sdl3"));
    mod.addImport("zlua", lua_dep.module("zlua"));
    exe.addIncludePath(.{ .cwd_relative = "src" });
    exe.addIncludePath(.{ .cwd_relative = "src/lib/lua52" });
    //TODO: To be deleted
    mod.addIncludePath(.{ .cwd_relative = "src" });
    b.installArtifact(exe);
}
