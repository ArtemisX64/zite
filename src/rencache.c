#include <stdio.h>
#include "rencache.h"


/* a cache over the software renderer -- all drawing operations are stored as
** commands when issued. At the end of the frame we write the commands to a grid
** of hash values, take the cells that have changed since the previous frame,
** merge them into dirty rectangles and redraw only those regions */

#define CELLS_X 80
#define CELLS_Y 50
#define CELL_SIZE 96
#define COMMAND_BUF_SIZE (1024 * 512)

extern SDL_Renderer* renderer;

enum { CMD_FREE_FONT, CMD_SET_CLIP, CMD_DRAW_TEXT, CMD_DRAW_RECT };

typedef struct {
    int type;
    int size;
    RenRect rect;
    RenColor color;
    RenFont *font;
    int tab_width;
    char text[0];
} Command;

static char command_buf[COMMAND_BUF_SIZE];
static int cmd_idx = 0;
static RenRect current_clip;
static bool show_debug = false;

static unsigned cells_buf1[CELLS_X * CELLS_Y];
static unsigned cells_buf2[CELLS_X * CELLS_Y];
static unsigned *cells_prev = cells_buf1;
static unsigned *cells = cells_buf2;
static RenRect rect_buf[CELLS_X * CELLS_Y / 2];
static int command_buf_idx;
static RenRect screen_rect;


static inline int min(int a, int b) { return a < b ? a : b; }
static inline int max(int a, int b) { return a > b ? a : b; }

/* 32bit fnv-1a hash */
#define HASH_INITIAL 2166136261

static void hash(unsigned *h, const void *data, int size) {
  const unsigned char *p = data;
  while (size--) {
    *h = (*h ^ *p++) * 16777619;
  }
}


static inline int cell_idx(int x, int y) {
  return x + y * CELLS_X;
}


static inline bool rects_overlap(RenRect a, RenRect b) {
  return b.x + b.width  >= a.x && b.x <= a.x + a.width
      && b.y + b.height >= a.y && b.y <= a.y + a.height;
}


static RenRect intersect_rects(RenRect a, RenRect b) {
  int x1 = max(a.x, b.x);
  int y1 = max(a.y, b.y);
  int x2 = min(a.x + a.width, b.x + b.width);
  int y2 = min(a.y + a.height, b.y + b.height);
  return (RenRect) { x1, y1, max(0, x2 - x1), max(0, y2 - y1) };
}


static RenRect merge_rects(RenRect a, RenRect b) {
  int x1 = min(a.x, b.x);
  int y1 = min(a.y, b.y);
  int x2 = max(a.x + a.width, b.x + b.width);
  int y2 = max(a.y + a.height, b.y + b.height);
  return (RenRect) { x1, y1, x2 - x1, y2 - y1 };
}

static Command *push_command_impl(int type, int size) {
    if (size <= 0) return NULL;
    if (command_buf_idx + size > COMMAND_BUF_SIZE) {
        fprintf(stderr, "rencache: command buffer overflow (needed %d, left %d)\n",
                size, COMMAND_BUF_SIZE - command_buf_idx);
        return NULL;
    }
    Command *cmd = (Command*)(command_buf + command_buf_idx);
    command_buf_idx += size;
    /* zero only the fixed header portion to avoid wiping trailing payload pointer
       when size > sizeof(Command) the payload (text[]) is initialized by caller */
    memset(cmd, 0, sizeof(Command));
    cmd->type = type;
    cmd->size = size;
    return cmd;
}

static Command *push_cmd(int type, int size) {
    if (cmd_idx + size > COMMAND_BUF_SIZE)
        return NULL;

    Command *c = (Command*)(command_buf + cmd_idx);
    cmd_idx += size;

    memset(c, 0, sizeof(Command));
    c->type = type;
    c->size = size;
    return c;
}


static bool next_cmd(Command **pp) {
    if (!*pp)
        *pp = (Command*)command_buf;
    else
        *pp = (Command*)((char*)*pp + (*pp)->size);

    return (*pp != (Command*)(command_buf + cmd_idx));
}


void rencache_show_debug(bool enable) {
  show_debug = enable;
}


void rencache_free_font(RenFont *font) {
  Command *cmd = push_cmd(CMD_FREE_FONT, sizeof(Command));
  if (cmd) { cmd->font = font; }
}


void rencache_set_clip_rect(RenRect r) {
    Command *c = push_cmd(CMD_SET_CLIP, sizeof(Command));
    if (c) c->rect = r;
}



void rencache_draw_rect(RenRect r, RenColor c) {
    Command *cmd = push_cmd(CMD_DRAW_RECT, sizeof(Command));
    if (cmd) {
        cmd->rect = r;
        cmd->color = c;
    }
}



int rencache_draw_text(RenFont *font, const char *text, int x, int y, RenColor color) {
    int w = ren_get_font_width(font, text);
    int h = ren_get_font_height(font);
    int sz = strlen(text) + 1;

    Command *cmd = push_cmd(CMD_DRAW_TEXT, sizeof(Command) + sz);
    if (cmd) {
        cmd->font = font;
        cmd->color = color;
        cmd->rect = (RenRect){x, y, w, h};
        cmd->tab_width = ren_get_font_tab_width(font);
        memcpy(cmd->text, text, sz);
    }

    return x + w;
}



void rencache_invalidate(void) { /* no-op in GPU */ }
void rencache_begin_frame(void) { /* no-op */ }


static void update_overlapping_cells(RenRect r, unsigned h) {
  int x1 = r.x / CELL_SIZE;
  int y1 = r.y / CELL_SIZE;
  int x2 = (r.x + r.width) / CELL_SIZE;
  int y2 = (r.y + r.height) / CELL_SIZE;

  for (int y = y1; y <= y2; y++) {
    for (int x = x1; x <= x2; x++) {
      int idx = cell_idx(x, y);
      hash(&cells[idx], &h, sizeof(h));
    }
  }
}


static void push_rect(RenRect r, int *count) {
  /* try to merge with existing rectangle */
  for (int i = *count - 1; i >= 0; i--) {
    RenRect *rp = &rect_buf[i];
    if (rects_overlap(*rp, r)) {
      *rp = merge_rects(*rp, r);
      return;
    }
  }
  /* couldn't merge with previous rectangle: push */
  rect_buf[(*count)++] = r;
}


void rencache_end_frame(void) {
    Command *cmd = NULL;
    current_clip = (RenRect){0,0,64000,64000};

    while (next_cmd(&cmd)) {
        switch (cmd->type) {

        case CMD_SET_CLIP:
            current_clip = cmd->rect;
            ren_set_clip_rect(cmd->rect);
            break;

        case CMD_DRAW_RECT:
            ren_draw_rect(cmd->rect, cmd->color);
            break;

        case CMD_DRAW_TEXT:
            ren_set_font_tab_width(cmd->font, cmd->tab_width);
            ren_draw_text(cmd->font, cmd->text, cmd->rect.x, cmd->rect.y, cmd->color);
            break;

        case CMD_FREE_FONT:
            ren_free_font(cmd->font);
            break;
        }
    }

    SDL_RenderPresent(renderer);
    cmd_idx = 0;
}