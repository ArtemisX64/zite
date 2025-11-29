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
        .lang = .lua54,
        .shared = false,
    });

    mod.addImport("sdl3", sdl3.module("sdl3"));
    mod.addImport("zlua", lua_dep.module("zlua"));
    b.installArtifact(exe);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
