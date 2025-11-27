#include "renderer.h"
#include "rencache.h"
#include "lib/lua52/lua.h"
#include "lib/lua52/lauxlib.h"
#include "lib/lua52/lualib.h"

#define API_TYPE_FONT "Font"
int f_load(lua_State *L) {
  const char *filename  = luaL_checkstring(L, 1);
  float size = luaL_checknumber(L, 2);
  RenFont **self = lua_newuserdata(L, sizeof(*self));
  luaL_setmetatable(L, API_TYPE_FONT);
  *self = ren_load_font(filename, size);
  if (!*self) { luaL_error(L, "failed to load font"); }
  return 1;
}


int f_set_tab_width(lua_State *L) {
  RenFont **self = luaL_checkudata(L, 1, API_TYPE_FONT);
  int n = luaL_checknumber(L, 2);
  ren_set_font_tab_width(*self, n);
  return 0;
}


int f_gc(lua_State *L) {
  RenFont **self = luaL_checkudata(L, 1, API_TYPE_FONT);
  if (*self) { rencache_free_font(*self); }
  return 0;
}


int f_get_width(lua_State *L) {
  RenFont **self = luaL_checkudata(L, 1, API_TYPE_FONT);
  const char *text = luaL_checkstring(L, 2);
  lua_pushnumber(L, ren_get_font_width(*self, text) );
  return 1;
}


int f_get_height(lua_State *L) {
  RenFont **self = luaL_checkudata(L, 1, API_TYPE_FONT);
  lua_pushnumber(L, ren_get_font_height(*self) );
  return 1;
}
