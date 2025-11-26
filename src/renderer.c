#include <stdio.h>
#include <stdbool.h>
#include <assert.h>
#include <math.h>
#include "lib/stb/stb_truetype.h"
#include "renderer.h"

#define MAX_GLYPHSET 256

typedef struct
{
  SDL_Texture *texture; // GPU texture for atlas
  stbtt_bakedchar glyphs[256];
  int width, height;
} GlyphSet;

struct RenFont
{
  void *data;
  stbtt_fontinfo stbfont;
  GlyphSet *sets[MAX_GLYPHSET];
  float size;
  int height;
};

SDL_Window *window;
SDL_Renderer *renderer;
static RenRect clip;

static void *check_alloc(void *ptr)
{
  if (!ptr)
  {
    fprintf(stderr, "Fatal error: memory allocation failed\n");
    exit(-1);
  }
  return ptr;
}

static const char *utf8_to_codepoint(const char *p, unsigned *dst)
{
  unsigned res, n;
  switch (*p & 0xf0)
  {
  case 0xf0:
    res = *p & 0x07;
    n = 3;
    break;
  case 0xe0:
    res = *p & 0x0f;
    n = 2;
    break;
  case 0xd0:
  case 0xc0:
    res = *p & 0x1f;
    n = 1;
    break;
  default:
    res = *p;
    n = 0;
    break;
  }
  while (n--)
  {
    res = (res << 6) | (*(++p) & 0x3f);
  }
  *dst = res;
  return p + 1;
}

void ren_init(SDL_Window *win, SDL_Renderer *ren)
{
  assert(win);
  assert(ren);
  window = win;
  renderer = ren;

  int w, h;
  SDL_GetWindowSize(win, &w, &h);
  clip = (RenRect){0, 0, w, h};

  SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
}

void ren_update_rects(RenRect *rects, int count)
{
  SDL_RenderPresent(renderer);
  // SDL_UpdateWindowSurfaceRects(window, (SDL_Rect *)rects, count);
  static bool initial_frame = true;
  if (initial_frame)
  {
    SDL_ShowWindow(window);
    initial_frame = false;
  }
}

void ren_set_clip_rect(RenRect r)
{
  clip = r;
  SDL_SetRenderClipRect(renderer, &(SDL_Rect){
                                      (int)r.x,
                                      (int)r.y,
                                      (int)r.width,
                                      (int)r.height,
                                  });
}

void ren_get_size(int *w, int *h)
{
  SDL_GetWindowSize(window, w, h);
}

static GlyphSet *load_glyphset(RenFont *font, int idx)
{
  GlyphSet *set = check_alloc(calloc(1, sizeof(GlyphSet)));

  int width = 128;
  int height = 128;

retry:
  uint8_t *alpha = malloc(width * height);
  if (!alpha)
    return NULL;

  float s =
      stbtt_ScaleForMappingEmToPixels(&font->stbfont, 1) /
      stbtt_ScaleForPixelHeight(&font->stbfont, 1);

  int res = stbtt_BakeFontBitmap(
      font->data,
      0,
      font->size * s,
      alpha,
      width,
      height,
      idx * 256,
      256,
      set->glyphs);

  if (res < 0)
  {
    free(alpha);
    width *= 2;
    height *= 2;
    goto retry;
  }

  set->width = width;
  set->height = height;

  // Expand to RGBA8888 (white text with alpha)
  uint8_t *rgba = malloc(width * height * 4);
  if (!rgba)
  {
    free(alpha);
    free(set);
    return NULL;
  }

  for (int i = 0; i < width * height; i++)
  {
    rgba[i * 4 + 0] = 255;      // R
    rgba[i * 4 + 1] = 255;      // G
    rgba[i * 4 + 2] = 255;      // B
    rgba[i * 4 + 3] = alpha[i]; // A
  }

  free(alpha);

  // Create SDL3 texture
  set->texture = set->texture = SDL_CreateTexture(renderer,
    SDL_PIXELFORMAT_ABGR8888,
    SDL_TEXTUREACCESS_STATIC, width, height);

  if (!set->texture)
  {
    fprintf(stderr, "SDL_CreateTexture failed: %s\n", SDL_GetError());
    free(rgba);
    free(set);
    return NULL;
  }

  SDL_UpdateTexture(set->texture, NULL, rgba, width * 4);
  SDL_SetTextureBlendMode(set->texture, SDL_BLENDMODE_BLEND);

  free(rgba);

  // Fix metrics: baseline alignment
  int ascent, descent, linegap;
  stbtt_GetFontVMetrics(&font->stbfont, &ascent, &descent, &linegap);
  float scale = stbtt_ScaleForMappingEmToPixels(&font->stbfont, font->size);
  int baseline = ascent * scale + 0.5;

  for (int i = 0; i < 256; i++)
  {
    set->glyphs[i].yoff += baseline;
    set->glyphs[i].xadvance = floor(set->glyphs[i].xadvance);
  }

  return set;
}

static GlyphSet *get_glyphset(RenFont *font, int codepoint)
{
  int idx = (codepoint >> 8) % MAX_GLYPHSET;
  if (!font->sets[idx])
  {
    font->sets[idx] = load_glyphset(font, idx);
  }
  return font->sets[idx];
}

RenFont *ren_load_font(const char *filename, float size)
{
  RenFont *font = check_alloc(calloc(1, sizeof(RenFont)));
  font->size = size;

  FILE *fp = fopen(filename, "rb");
  if (!fp)
    return NULL;

  fseek(fp, 0, SEEK_END);
  int buf_size = ftell(fp);
  fseek(fp, 0, SEEK_SET);

  font->data = check_alloc(malloc(buf_size));
  fread(font->data, 1, buf_size, fp);
  fclose(fp);

  if (!stbtt_InitFont(&font->stbfont, font->data, 0))
  {
    free(font->data);
    free(font);
    return NULL;
  }

  int ascent, descent, linegap;
  stbtt_GetFontVMetrics(&font->stbfont, &ascent, &descent, &linegap);
  float scale = stbtt_ScaleForMappingEmToPixels(&font->stbfont, size);

  font->height = (ascent - descent + linegap) * scale + 0.5;

  // Force loading first glyph set so \t and \n exist
GlyphSet *gset = get_glyphset(font, 0);

if (gset) {
    stbtt_bakedchar *g = gset->glyphs;
    g['\t'].x1 = g['\t'].x0;
    g['\n'].x1 = g['\n'].x0;
}


  return font;
}

void ren_free_font(RenFont *font)
{
  for (int i = 0; i < MAX_GLYPHSET; i++)
  {
    GlyphSet *set = font->sets[i];
    if (set)
    {
      if (set->texture)
        SDL_DestroyTexture(set->texture);
      free(set);
    }
  }
  free(font->data);
  free(font);
}

void ren_set_font_tab_width(RenFont *font, int n)
{
  GlyphSet *set = get_glyphset(font, '\t');
  set->glyphs['\t'].xadvance = n;
}

int ren_get_font_tab_width(RenFont *font)
{
  GlyphSet *set = get_glyphset(font, '\t');
  return set->glyphs['\t'].xadvance;
}

int ren_get_font_width(RenFont *font, const char *text)
{
  int x = 0;
  const char *p = text;
  unsigned codepoint;
  while (*p)
  {
    p = utf8_to_codepoint(p, &codepoint);
    GlyphSet *set = get_glyphset(font, codepoint);
    stbtt_bakedchar *g = &set->glyphs[codepoint & 0xff];
    x += g->xadvance;
  }
  return x;
}

int ren_get_font_height(RenFont *font)
{
  return font->height;
}

static inline RenColor blend_pixel(RenColor dst, RenColor src)
{
  int ia = 0xff - src.a;
  dst.r = ((src.r * src.a) + (dst.r * ia)) >> 8;
  dst.g = ((src.g * src.a) + (dst.g * ia)) >> 8;
  dst.b = ((src.b * src.a) + (dst.b * ia)) >> 8;
  return dst;
}

static inline RenColor blend_pixel2(RenColor dst, RenColor src, RenColor color)
{
  src.a = (src.a * color.a) >> 8;
  int ia = 0xff - src.a;
  dst.r = ((src.r * color.r * src.a) >> 16) + ((dst.r * ia) >> 8);
  dst.g = ((src.g * color.g * src.a) >> 16) + ((dst.g * ia) >> 8);
  dst.b = ((src.b * color.b * src.a) >> 16) + ((dst.b * ia) >> 8);
  return dst;
}

#define rect_draw_loop(expr)      \
  for (int j = y1; j < y2; j++)   \
  {                               \
    for (int i = x1; i < x2; i++) \
    {                             \
      *d = expr;                  \
      d++;                        \
    }                             \
    d += dr;                      \
  }

void ren_draw_rect(RenRect rect, RenColor c)
{
  SDL_SetRenderDrawColor(renderer, c.r, c.g, c.b, c.a);
  SDL_FRect frect = {
      (float)rect.x, (float)rect.y, (float)rect.width, (float)rect.height};
  SDL_RenderFillRect(renderer, &frect);
}

void ren_draw_image(SDL_Texture *tex, RenRect sub, int x, int y, RenColor color)
{
  SDL_SetTextureColorMod(tex, color.r, color.g, color.b);
  SDL_SetTextureAlphaMod(tex, color.a);

  SDL_FRect src = {(float)sub.x, (float)sub.y, (float)sub.width, (float)sub.height};
  SDL_FRect dst = {(float)x, (float)y, (float)sub.width, (float)sub.height};

  SDL_RenderTexture(renderer, tex, &src, &dst);
}

int ren_draw_text(RenFont *font, const char *text, int x, int y, RenColor color)
{
  const char *p = text;
  unsigned codepoint;

  while (*p)
  {
    p = utf8_to_codepoint(p, &codepoint);

    GlyphSet *set = get_glyphset(font, codepoint);
    stbtt_bakedchar *g = &set->glyphs[codepoint & 0xFF];

    int w = g->x1 - g->x0;
    int h = g->y1 - g->y0;

    if (w > 0 && h > 0)
    {
      SDL_FRect src = {
          (float)g->x0,
          (float)g->y0,
          (float)w,
          (float)h};

      SDL_FRect dst = {
          (float)(x + g->xoff),
          (float)(y + g->yoff),
          (float)w,
          (float)h};

      SDL_SetTextureColorMod(set->texture, color.r, color.g, color.b);
      SDL_SetTextureAlphaMod(set->texture, color.a);

      SDL_RenderTexture(renderer, set->texture, &src, &dst);
    }

    x += g->xadvance;
  }

  return x;
}
