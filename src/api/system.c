// src/api/system.c
// SDL3 version of system.c for zlite — exposes events and system helpers to Lua.

#include <SDL3/SDL.h>
#include <SDL3/SDL_messagebox.h>
#include <stdbool.h>
#include <ctype.h>
#include <dirent.h>
#include <unistd.h>
#include <errno.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "rencache.h"

#include "lib/lua52/lua.h"
#include "lib/lua52/lauxlib.h"
#include "lib/lua52/lualib.h"

/* window is defined in renderer.c (non-static) */
extern SDL_Window *window;

static const char *button_name(int b) {
    switch (b) {
        case SDL_BUTTON_LEFT:   return "left";
        case SDL_BUTTON_MIDDLE: return "middle";
        case SDL_BUTTON_RIGHT:  return "right";
    }
    return "?";
}

static char *key_name(char *dst, SDL_Keycode sym) {
    const char *raw = SDL_GetKeyName(sym);
    /* copy and lower-case */
    strcpy(dst, raw);
    for (char *p = dst; *p; p++) *p = (char)tolower((unsigned char)*p);
    return dst;
}

static int f_poll_event(lua_State *L) {
    SDL_Event e;
    char buf[32];

top:
    if (!SDL_PollEvent(&e)) return 0;

    switch (e.type) {

    case SDL_EVENT_QUIT:
        lua_pushstring(L, "quit");
        return 1;

    case SDL_EVENT_WINDOW_RESIZED:
        /* SDL3 provides data1/data2 on window events */
        lua_pushstring(L, "resized");
        lua_pushnumber(L, e.window.data1);
        lua_pushnumber(L, e.window.data2);
        return 3;

    case SDL_EVENT_WINDOW_EXPOSED:
        rencache_invalidate();
        lua_pushstring(L, "exposed");
        return 1;

    case SDL_EVENT_WINDOW_FOCUS_GAINED:
        /* Flush any queued keydown events (same behaviour as original SDL2 code) */
        SDL_FlushEvent(SDL_EVENT_KEY_DOWN);
        /* enable text input so SDL_TEXT_INPUT events arrive */
        SDL_StartTextInput(window);
        goto top; /* continue polling (skip returning anything for focus events) */

    case SDL_EVENT_WINDOW_FOCUS_LOST:
        /* stop text input when focus lost */
        SDL_StopTextInput(window);
        goto top;

    case SDL_EVENT_KEY_DOWN:
        lua_pushstring(L, "keypressed");
        lua_pushstring(L, key_name(buf, e.key.key));
        return 2;

    case SDL_EVENT_KEY_UP:
        lua_pushstring(L, "keyreleased");
        lua_pushstring(L, key_name(buf, e.key.key));
        return 2;

    case SDL_EVENT_TEXT_INPUT:
        /* text input comes from SDL_StartTextInput() */
        lua_pushstring(L, "textinput");
        lua_pushstring(L, e.text.text);
        return 2;

    case SDL_EVENT_MOUSE_BUTTON_DOWN:
        if (e.button.button == SDL_BUTTON_LEFT) { SDL_CaptureMouse(true); }
        lua_pushstring(L, "mousepressed");
        lua_pushstring(L, button_name(e.button.button));
        lua_pushnumber(L, e.button.x);
        lua_pushnumber(L, e.button.y);
        lua_pushnumber(L, e.button.clicks);
        return 5;

    case SDL_EVENT_MOUSE_BUTTON_UP:
        if (e.button.button == SDL_BUTTON_LEFT) { SDL_CaptureMouse(false); }
        lua_pushstring(L, "mousereleased");
        lua_pushstring(L, button_name(e.button.button));
        lua_pushnumber(L, e.button.x);
        lua_pushnumber(L, e.button.y);
        return 4;

    case SDL_EVENT_MOUSE_MOTION:
        lua_pushstring(L, "mousemoved");
        lua_pushnumber(L, e.motion.x);
        lua_pushnumber(L, e.motion.y);
        lua_pushnumber(L, e.motion.xrel);
        lua_pushnumber(L, e.motion.yrel);
        return 5;

    case SDL_EVENT_MOUSE_WHEEL:
        lua_pushstring(L, "mousewheel");
        lua_pushnumber(L, e.wheel.y);
        return 2;

    case SDL_EVENT_DROP_FILE: {
        /* SDL_Event.drop.data is const char*; SDL_free takes void* — cast safely */
        const char *path = e.drop.data;
        lua_pushstring(L, "filedropped");
        lua_pushstring(L, path);
        /* SDL3 provides drop.x / drop.y relative to the window */
        lua_pushnumber(L, e.drop.x);
        lua_pushnumber(L, e.drop.y);
        /* free the string memory allocated by SDL */
        SDL_free((void*)path);
        return 4;
    }

    default:
        goto top;
    }

    return 0;
}

static int f_wait_event(lua_State *L) {
    double n = luaL_checknumber(L, 1);
    SDL_Event e;
    /* SDL_WaitEventTimeout returns SDL_TRUE/SDL_FALSE */
    lua_pushboolean(L, SDL_WaitEventTimeout(&e, (int)(n * 1000)));
    return 1;
}

/* cursor mapping (SDL3 system cursors) */
static SDL_Cursor* cursor_cache[SDL_SYSTEM_CURSOR_POINTER + 1];

static const char *cursor_opts[] = {
  "arrow",
  "ibeam",
  "sizeh",
  "sizev",
  "hand",
  NULL
};

static const int cursor_enums[] = {
  SDL_SYSTEM_CURSOR_DEFAULT,
  SDL_SYSTEM_CURSOR_TEXT,
  SDL_SYSTEM_CURSOR_EW_RESIZE,
  SDL_SYSTEM_CURSOR_NS_RESIZE,
  SDL_SYSTEM_CURSOR_POINTER
};

static int f_set_cursor(lua_State *L) {
  int opt = luaL_checkoption(L, 1, "arrow", cursor_opts);
  int n = cursor_enums[opt];
  SDL_Cursor *cursor = cursor_cache[n];
  if (!cursor) {
    cursor = SDL_CreateSystemCursor(n);
    cursor_cache[n] = cursor;
  }
  SDL_SetCursor(cursor);
  return 0;
}

static int f_set_window_title(lua_State *L) {
    SDL_SetWindowTitle(window, luaL_checkstring(L, 1));
    return 0;
}

static const char *window_opts[] = { "normal", "maximized", "fullscreen", NULL };
enum { WIN_NORMAL, WIN_MAXIMIZED, WIN_FULLSCREEN };

static int f_set_window_mode(lua_State *L) {
    int mode = luaL_checkoption(L, 1, "normal", window_opts);

    switch (mode) {
        case WIN_NORMAL:
            SDL_SetWindowFullscreen(window, false);
            SDL_RestoreWindow(window);
            break;
        case WIN_MAXIMIZED:
            SDL_MaximizeWindow(window);
            break;
        case WIN_FULLSCREEN:
            SDL_SetWindowFullscreen(window, true);
            break;
    }
    return 0;
}

static int f_window_has_focus(lua_State *L) {
    uint32_t flags = SDL_GetWindowFlags(window);
    lua_pushboolean(L, (flags & SDL_WINDOW_INPUT_FOCUS) != 0);
    return 1;
}

static int f_show_confirm_dialog(lua_State *L) {
    const char *title = luaL_checkstring(L, 1);
    const char *msg   = luaL_checkstring(L, 2);

    const SDL_MessageBoxButtonData buttons[] = {
        { SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT, 1, "Yes" },
        { SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT, 0, "No"  },
    };

    const SDL_MessageBoxData data = {
        .title = title,
        .message = msg,
        .buttons = buttons,
        .numbuttons = 2,
    };

    int rid = 0;
    SDL_ShowMessageBox(&data, &rid);
    lua_pushboolean(L, rid == 1);
    return 1;
}

static int f_chdir(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  int err = chdir(path);
  if (err) { luaL_error(L, "chdir() failed"); }
  return 0;
}

static int f_list_dir(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);

  DIR *dir = opendir(path);
  if (!dir) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    return 2;
  }

  lua_newtable(L);
  int i = 1;
  struct dirent *entry;
  while ( (entry = readdir(dir)) ) {
    if (strcmp(entry->d_name, "." ) == 0) { continue; }
    if (strcmp(entry->d_name, "..") == 0) { continue; }
    lua_pushstring(L, entry->d_name);
    lua_rawseti(L, -2, i);
    i++;
  }

  closedir(dir);
  return 1;
}

#ifdef _WIN32
  #include <windows.h>
  #define realpath(x, y) _fullpath(y, x, MAX_PATH)
#endif

static int f_absolute_path(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  char *res = realpath(path, NULL);
  if (!res) { return 0; }
  lua_pushstring(L, res);
  free(res);
  return 1;
}

static int f_get_file_info(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);

  struct stat s;
  int err = stat(path, &s);
  if (err < 0) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    return 2;
  }

  lua_newtable(L);
  lua_pushnumber(L, s.st_mtime);
  lua_setfield(L, -2, "modified");

  lua_pushnumber(L, s.st_size);
  lua_setfield(L, -2, "size");

  if (S_ISREG(s.st_mode)) {
    lua_pushstring(L, "file");
  } else if (S_ISDIR(s.st_mode)) {
    lua_pushstring(L, "dir");
  } else {
    lua_pushnil(L);
  }
  lua_setfield(L, -2, "type");

  return 1;
}

static int f_get_clipboard(lua_State *L) {
    char *text = SDL_GetClipboardText();
    if (!text) return 0;
    lua_pushstring(L, text);
    SDL_free(text);
    return 1;
}

static int f_set_clipboard(lua_State *L) {
    SDL_SetClipboardText(luaL_checkstring(L, 1));
    return 0;
}

static int f_get_time(lua_State *L) {
    double t = SDL_GetTicksNS() / 1e9;
    lua_pushnumber(L, t);
    return 1;
}

static int f_sleep(lua_State *L) {
    SDL_Delay((int)(luaL_checknumber(L, 1) * 1000));
    return 0;
}

static int f_exec(lua_State *L) {
    const char *cmd = luaL_checkstring(L, 1);
    system(cmd);
    return 0;
}

static int f_fuzzy_match(lua_State *L) {
  const char *str = luaL_checkstring(L, 1);
  const char *ptn = luaL_checkstring(L, 2);
  int score = 0;
  int run = 0;

  while (*str && *ptn) {
    while (*str == ' ') { str++; }
    while (*ptn == ' ') { ptn++; }
    if (tolower(*str) == tolower(*ptn)) {
      score += run * 10 - (*str != *ptn);
      run++;
      ptn++;
    } else {
      score -= 10;
      run = 0;
    }
    str++;
  }
  if (*ptn) { return 0; }

  lua_pushnumber(L, score - (int) strlen(str));
  return 1;
}

static const luaL_Reg lib[] = {
  { "poll_event",          f_poll_event          },
  { "wait_event",          f_wait_event          },
  { "set_cursor",          f_set_cursor          },
  { "set_window_title",    f_set_window_title    },
  { "set_window_mode",     f_set_window_mode     },
  { "window_has_focus",    f_window_has_focus    },
  { "show_confirm_dialog", f_show_confirm_dialog },
  { "chdir",               f_chdir               },
  { "list_dir",            f_list_dir            },
  { "absolute_path",       f_absolute_path       },
  { "get_file_info",       f_get_file_info       },
  { "get_clipboard",       f_get_clipboard       },
  { "set_clipboard",       f_set_clipboard       },
  { "get_time",            f_get_time            },
  { "sleep",               f_sleep               },
  { "exec",                f_exec                },
  { "fuzzy_match",         f_fuzzy_match         },
  { NULL, NULL }
};

int luaopen_system(lua_State *L) {
  luaL_newlib(L, lib);
  return 1;
}
