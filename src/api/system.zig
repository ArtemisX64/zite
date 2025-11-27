const std = @import("std");
const zlua = @import("zlua");
const sdl = @import("sdl3");
const Button = sdl.mouse.Button;
const Window = @import("../window.zig").Window;
const Allocator = std.mem.Allocator;
const Event = sdl.events.Event;

pub const System = @This();

pub var window: sdl.video.Window = undefined;

var cursorCache = [_]?sdl.mouse.Cursor{null} ** (@as(i32, @intFromEnum(sdl.mouse.SystemCursor.pointer)) + 1);

const libs = [_]zlua.FnReg{
    .{ .name = "poll_event", .func = lPollEvent },
    .{ .name = "wait_event", .func = lWaitEvent },
    .{ .name = "set_cursor", .func = lSetCursor },
    .{ .name = "set_window_title", .func = lSetWindowTitle },
    .{ .name = "set_window_mode", .func = lsetWindowMode },
    .{ .name = "window_has_focus", .func = lWindowHasFocus },
    .{ .name = "show_confirm_dialog", .func = lshowConfirmDialog },
    .{ .name = "chdir", .func = lChdir },
    .{ .name = "list_dir", .func = lListDir },
    .{ .name = "absolute_path", .func = lAbsolutePath },
    .{ .name = "get_file_info", .func = lGetFileInfo },
    .{ .name = "get_clipboard", .func = lGetClipboard },
    .{ .name = "set_clipboard", .func = lSetClipboard },
    .{ .name = "get_time", .func = lGetTime },
    .{ .name = "sleep", .func = lSleep },
    .{ .name = "exec", .func = lExec },
    .{ .name = "fuzzy_match", .func = lFuzzyMatch },
};

const cursorOpts = enum {
    arrow,
    ibeam,
    sizeh,
    sizev,
    hand,
};

const windowOpts = enum {
    fullscreen,
    maximized,
    normal,
};

const cursorEnums = [_]sdl.mouse.SystemCursor{
    .default,
    .text,
    .east_west_resize,
    .north_south_resize,
    .pointer,
};

//Helper functions
fn getButtonName(b: sdl.mouse.Button) []const u8 {
    switch (b) {
        .left => return "left",
        .right => return "right",
        .middle => return "middle",
        else => return "?",
    }
}

fn getKeyName(buf: []u8, sym: sdl.keycode.Keycode) ![]const u8 {
    const keyname = sdl.keyboard.getKeyName(sym) orelse return error.CannotGetKey;
    const keyname_lower = std.ascii.lowerString(buf, keyname);
    return keyname_lower;
}

//Lua export functions
fn lPollEvent(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return pollEvent(@ptrCast(lua.?));
}

fn lWaitEvent(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return waitEvent(@ptrCast(lua.?));
}

fn lSetCursor(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return setCursor(@ptrCast(lua.?));
}

fn lSetWindowTitle(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return setWindowTitle(@ptrCast(lua.?));
}

fn lsetWindowMode(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return setWindowMode(@ptrCast(lua.?));
}

fn lWindowHasFocus(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return windowHasFocus(@ptrCast(lua.?));
}

fn lshowConfirmDialog(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return showConfirmDialog(@ptrCast(lua.?));
}

fn lChdir(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return chdir(@ptrCast(lua.?));
}

fn lListDir(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return listDir(@ptrCast(lua.?));
}

pub fn lLuaOpenSystem(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return luaOpenSystem(@ptrCast(lua.?));
}

pub fn lAbsolutePath(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return absolutePath(@ptrCast(lua.?));
}

pub fn lGetFileInfo(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return getFileInfo(@ptrCast(lua.?));
}

pub fn lGetClipboard(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return getClipboard(@ptrCast(lua.?));
}

pub fn lSetClipboard(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return setClipboard(@ptrCast(lua.?));
}

pub fn lGetTime(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return getTime(@ptrCast(lua.?));
}

pub fn lSleep(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return sleep(@ptrCast(lua.?));
}

pub fn lExec(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return exec(@ptrCast(lua.?));
}

pub fn lFuzzyMatch(lua: ?*zlua.LuaState) callconv(.c) c_int {
    return fuzzyMatch(@ptrCast(lua.?));
}

//Ziggified lua options

pub fn luaOpenSystem(lua: *zlua.Lua) c_int {
    lua.newLib(&libs);
    return 1;
}

fn pollEvent(lua: *zlua.Lua) c_int {
    var buf: [32]u8 = .{0} ** 32;
    while (sdl.events.poll()) |e| {
        switch (e) {
            .quit => {
                _ = lua.pushString("quit");
                return 1;
            },

            .window_resized => {
                _ = lua.pushString("resized");
                lua.pushNumber(@floatFromInt(e.window_resized.width));
                lua.pushNumber((@floatFromInt(e.window_resized.height)));
                return 3;
            },

            .window_exposed => {
                _ = lua.pushString("exposed");
                return 1;
            },

            .window_focus_gained => {
                sdl.events.flush(.key_down);
                sdl.keyboard.startTextInput(window) catch return 0;
                continue;
            },

            .window_focus_lost => {
                sdl.keyboard.stopTextInput(window) catch return 0;
                continue;
            },

            .key_down => {
                _ = lua.pushString("keypressed");
                _ = lua.pushString(getKeyName(&buf, e.key_down.key.?) catch "");
                return 2;
            },

            .key_up => {
                _ = lua.pushString("keyreleased");
                _ = lua.pushString(getKeyName(&buf, e.key_up.key.?) catch "");
                return 2;
            },

            .text_input => {
                _ = lua.pushString("textinput");
                _ = lua.pushStringZ(e.text_input.text);
                return 2;
            },

            .mouse_button_down => {
                if (e.mouse_button_down.button == .left) {
                    sdl.mouse.setWindowRelativeMode(window, true) catch return 0;
                }
                _ = lua.pushString("mousepressed");
                _ = lua.pushString(getButtonName(e.mouse_button_down.button));
                lua.pushNumber(e.mouse_button_down.x);
                lua.pushNumber(e.mouse_button_down.y);
                lua.pushNumber(@floatFromInt(e.mouse_button_down.clicks));
                return 5;
            },

            .mouse_button_up => {
                if (e.mouse_button_up.button == .left) {
                    sdl.mouse.setWindowRelativeMode(window, false) catch return 0;
                }
                _ = lua.pushString("mousereleased");
                _ = lua.pushString(getButtonName(e.mouse_button_up.button));
                lua.pushNumber(e.mouse_button_up.x);
                lua.pushNumber(e.mouse_button_up.y);
                return 4;
            },

            .mouse_motion => {
                _ = lua.pushString("mousemoved");
                lua.pushNumber(e.mouse_motion.x);
                lua.pushNumber(e.mouse_motion.y);
                lua.pushNumber(e.mouse_motion.x_rel);
                lua.pushNumber(e.mouse_motion.y_rel);
                return 5;
            },

            .mouse_wheel => {
                _ = lua.pushString("mousewheel");
                lua.pushNumber(e.mouse_wheel.y);
                return 2;
            },

            .drop_file => {
                const path: [:0]const u8 = e.drop_file.file_name;
                _ = lua.pushString("filedropped");
                _ = lua.pushStringZ(path);
                lua.pushNumber(e.drop_file.x);
                lua.pushNumber(e.drop_file.y);
                return 4;
            },

            else => continue,
        }
    }
    return 0;
}

fn waitEvent(lua: *zlua.Lua) c_int {
    const n: f64 = lua.checkNumber(1);
    lua.pushBoolean(sdl.events.waitTimeout(@intFromFloat(n * 1000.0)));
    return 1;
}

fn setCursor(lua: *zlua.Lua) c_int {
    const opt = lua.checkOption(cursorOpts, 1, .arrow);

    const i: usize = switch (opt) {
        .arrow => 0,
        .ibeam => 1,
        .sizeh => 2,
        .sizev => 3,
        .hand => 4,
    };
    const n: usize = @intFromEnum(cursorEnums[i]);
    if (n >= cursorCache.len) {
        return 0;
    }
    var cursor = cursorCache[n];
    if (cursor == null) {
        cursor = sdl.mouse.Cursor.initSystem(@enumFromInt(n)) catch return 0;
        cursorCache[n] = cursor;
    }
    sdl.mouse.set(cursor) catch return 0;
    return 0;
}

fn setWindowTitle(lua: *zlua.Lua) c_int {
    window.setTitle(lua.checkString(1)) catch return 0;
    return 0;
}

fn setWindowMode(lua: *zlua.Lua) c_int {
    const mode = lua.checkOption(windowOpts, 1, .fullscreen);
    switch (mode) {
        .fullscreen => {
            window.setFullscreen(true) catch return 0;
        },
        .maximized => {
            window.maximize() catch return 0;
        },
        .normal => {
            window.setFullscreen(false) catch return 0;
            window.restore() catch return 0;
        },
    }
    return 0;
}

fn windowHasFocus(lua: *zlua.Lua) c_int {
    const flags = window.getFlags();
    lua.pushBoolean(flags.input_focus);
    return 1;
}

fn showConfirmDialog(lua: *zlua.Lua) c_int {
    const title = lua.checkString(1);
    const msg = lua.checkString(2);

    const buttons = [_]sdl.message_box.Button{
        .{
            .flags = .{ .mark_default_with_escape_key = true },
            .value = 1,
            .text = "Yes",
        },
        .{
            .flags = .{ .mark_default_with_return_key = true },
            .value = 0,
            .text = "No",
        },
    };

    const data = sdl.message_box.BoxData{
        .buttons = &buttons,
        .message = msg,
        .title = title,
        .parent_window = window,
        .flags = .{
            .warning_dialog = true,
        },
        .color_scheme = null,
    };

    const rid = sdl.message_box.show(data) catch 0;
    lua.pushBoolean(rid == 1);
    return 1;
}

fn chdir(lua: *zlua.Lua) c_int {
    const path: [:0]const u8 = lua.checkString(1);
    std.posix.chdirZ(path) catch lua.raiseErrorStr("{s}", .{"chdir() failed"});
    return 0;
}

fn listDir(lua: *zlua.Lua) c_int {
    const path: [:0]const u8 = lua.checkString(1);

    var dir = std.fs.cwd().openDir(path, .{
        .iterate = true,
        .access_sub_paths = true,
        .follow_symlinks = true,
    }) catch {
        lua.pushNil();
        _ = lua.pushString("Error opening directory");
        return 2;
    };
    defer dir.close();

    lua.newTable();

    var dir_iterate = dir.iterate();

    var i: i32 = 1;
    while (dir_iterate.next() catch return 0) |entry| {
        _ = lua.pushString(entry.name);
        lua.rawSetIndex(-2, i);
        i += 1;
    }

    return 1;
}

fn absolutePath(lua: *zlua.Lua) c_int {
    const path: [:0]const u8 = lua.checkString(1);
    var buf = [1]u8{0} ** std.posix.PATH_MAX;
    const res = std.posix.realpathZ(path, &buf) catch {
        lua.pushNil();
        _ = lua.pushString("Getting real path");
        return 0;
    };
    _ = lua.pushString(res);
    return 1;
}

fn getFileInfo(lua: *zlua.Lua) c_int {
    const path: [:0]const u8 = lua.checkString(1);
    const stat = std.posix.fstatatZ(std.posix.AT.FDCWD, path, 0) catch {
        lua.pushNil();
        _ = lua.pushString("Error Getting Stat");
        return 2;
    };

    lua.newTable();
    lua.pushNumber(@floatFromInt(stat.mtim.sec));
    lua.setField(-2, "modified");

    lua.pushNumber(@floatFromInt(stat.size));
    lua.setField(-2, "size");

    const file_type = stat.mode & std.posix.S.IFMT; //Remove permissions and keep only file format

    switch (file_type) {
        std.posix.S.IFREG => _ = lua.pushString("file"),
        std.posix.S.IFDIR => _ = lua.pushString("dir"),
        else => lua.pushNil(),
    }
    lua.setField(-2, "type");

    return 1;
}

fn getClipboard(lua: *zlua.Lua) c_int {
    const text = sdl.clipboard.getText() catch return 0;
    _ = lua.pushStringZ(text);
    return 1;
}

fn setClipboard(lua: *zlua.Lua) c_int {
    const text = lua.checkString(1);
    sdl.clipboard.setText(text) catch return 1;
    return 0;
}

fn getTime(lua: *zlua.Lua) c_int {
    const t = sdl.timer.getNanosecondsSinceInit();
    const seconds: f64 = @as(f64, @floatFromInt(t)) / 1e9;

    lua.pushNumber(seconds);
    return 1;
}

fn sleep(lua: *zlua.Lua) c_int {
    const delay_time: u32 = @intFromFloat(lua.checkNumber(1) * 1000.0);
    sdl.timer.delayMilliseconds(delay_time);
    return 0;
}

fn exec(lua: *zlua.Lua) c_int {
    const cmd = lua.checkString(1);
    const alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const argv = [_][]const u8{
        "sh", "-c", cmd,
    };
    var child = std.process.Child.init(&argv, alloc);
    child.stderr_behavior = .Inherit;
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;

    child.spawn() catch return 0;
    _ = child.wait() catch {};

    return 0;
}

inline fn asciiLower(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn fuzzyMatch(lua: *zlua.Lua) c_int {
    const str = lua.checkString(1);
    const ptn = lua.checkString(2); //pattern
    var score: i32 = 0;
    var run: i32 = 0;

    var i: usize = 0;
    var j: usize = 0;

    while (i < str.len and j < ptn.len) : (i += 1) {
        while (i < str.len and str[i] == ' ') : (i += 1) {}
        if (i >= str.len) break;

        while (j < ptn.len and ptn[j] == ' ') : (j += 1) {}
        if (j >= ptn.len) break;

        const sc = str[i];
        const pc = ptn[j];

        if (asciiLower(sc) == asciiLower(pc)) {
            score += run * 10 - @as(i32, @intFromBool(sc != pc));
            run += 1;
            j += 1;
        } else {
            score -= 10;
            run = 0;
        }
    }

    if (j < ptn.len) {
        lua.pushNumber(0);
        return 1;
    }

    const remaining = @as(i32, @intCast(str.len - i));

    lua.pushNumber(@as(f64, @floatFromInt(score - remaining)));
    return 1;
}
