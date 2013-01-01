/*
 * (C) Gražvydas "notaz" Ignotas, 2011,2012
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - GNU LGPL, version 2.1 or later.
 * See the COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <SDL.h>

#include "libpicofe/input.h"
#include "libpicofe/in_sdl.h"
#include "libpicofe/menu.h"
#include "libpicofe/fonts.h"
#include "libpicofe/plat_sdl.h"
#include "libpicofe/gl.h"
#include "../plugins/gpulib/cspace.h"
#include "plugin_lib.h"
#include "main.h"
#include "plat.h"
#include "revision.h"

static const struct in_default_bind in_sdl_defbinds[] = {
  { SDLK_UP,     IN_BINDTYPE_PLAYER12, DKEY_UP },
  { SDLK_DOWN,   IN_BINDTYPE_PLAYER12, DKEY_DOWN },
  { SDLK_LEFT,   IN_BINDTYPE_PLAYER12, DKEY_LEFT },
  { SDLK_RIGHT,  IN_BINDTYPE_PLAYER12, DKEY_RIGHT },
  { SDLK_d,      IN_BINDTYPE_PLAYER12, DKEY_TRIANGLE },
  { SDLK_z,      IN_BINDTYPE_PLAYER12, DKEY_CROSS },
  { SDLK_x,      IN_BINDTYPE_PLAYER12, DKEY_CIRCLE },
  { SDLK_s,      IN_BINDTYPE_PLAYER12, DKEY_SQUARE },
  { SDLK_v,      IN_BINDTYPE_PLAYER12, DKEY_START },
  { SDLK_c,      IN_BINDTYPE_PLAYER12, DKEY_SELECT },
  { SDLK_w,      IN_BINDTYPE_PLAYER12, DKEY_L1 },
  { SDLK_r,      IN_BINDTYPE_PLAYER12, DKEY_R1 },
  { SDLK_e,      IN_BINDTYPE_PLAYER12, DKEY_L2 },
  { SDLK_t,      IN_BINDTYPE_PLAYER12, DKEY_R2 },
  { SDLK_ESCAPE, IN_BINDTYPE_EMU, SACTION_ENTER_MENU },
  { SDLK_F1,     IN_BINDTYPE_EMU, SACTION_SAVE_STATE },
  { SDLK_F2,     IN_BINDTYPE_EMU, SACTION_LOAD_STATE },
  { SDLK_F3,     IN_BINDTYPE_EMU, SACTION_PREV_SSLOT },
  { SDLK_F4,     IN_BINDTYPE_EMU, SACTION_NEXT_SSLOT },
  { SDLK_F5,     IN_BINDTYPE_EMU, SACTION_TOGGLE_FSKIP },
  { SDLK_F6,     IN_BINDTYPE_EMU, SACTION_SCREENSHOT },
  { SDLK_F7,     IN_BINDTYPE_EMU, SACTION_TOGGLE_FPS },
  { SDLK_F8,     IN_BINDTYPE_EMU, SACTION_SWITCH_DISPMODE },
  { SDLK_F11,    IN_BINDTYPE_EMU, SACTION_TOGGLE_FULLSCREEN },
  { SDLK_BACKSPACE, IN_BINDTYPE_EMU, SACTION_FAST_FORWARD },
  { 0, 0, 0 }
};

static int psx_w, psx_h;
static void *shadow_fb, *menubg_img;
static int in_menu;

static int change_video_mode(void)
{
  int w, h;

  if (in_menu) {
    w = g_menuscreen_w;
    h = g_menuscreen_h;
  }
  else {
    w = psx_w;
    h = psx_h;
  }

  return plat_sdl_change_video_mode(w, h, 0);
}

void plat_init(void)
{
  int ret;

  ret = plat_sdl_init();
  if (ret != 0)
    exit(1);

  in_menu = 1;
  SDL_WM_SetCaption("PCSX-ReARMed " REV, NULL);

  shadow_fb = malloc(640 * 512 * 2);
  menubg_img = malloc(640 * 512 * 2);
  if (shadow_fb == NULL || menubg_img == NULL) {
    fprintf(stderr, "OOM\n");
    exit(1);
  }

  in_sdl_init(in_sdl_defbinds, plat_sdl_event_handler);
  in_probe();
  pl_rearmed_cbs.only_16bpp = 1;

  bgr_to_uyvy_init();
}

void plat_finish(void)
{
  free(shadow_fb);
  shadow_fb = NULL;
  free(menubg_img);
  menubg_img = NULL;
  plat_sdl_finish();
}

void plat_gvideo_open(int is_pal)
{
}

static void uyvy_to_rgb565(void *d, const void *s, int pixels)
{
  unsigned short *dst = d;
  const unsigned int *src = s;
  int v;

  // no colors, for now
  for (; pixels > 0; src++, dst += 2, pixels -= 2) {
    v = (*src >> 8) & 0xff;
    v = (v - 16) * 255 / 219 / 8;
    dst[0] = (v << 11) | (v << 6) | v;

    v = (*src >> 24) & 0xff;
    v = (v - 16) * 255 / 219 / 8;
    dst[1] = (v << 11) | (v << 6) | v;
  }
}

static void overlay_blit(int doffs, const void *src_, int w, int h,
                         int sstride, int bgr24)
{
  const unsigned short *src = src_;
  unsigned short *dst;
  int dstride = plat_sdl_overlay->w;

  SDL_LockYUVOverlay(plat_sdl_overlay);
  dst = (void *)plat_sdl_overlay->pixels[0];

  dst += doffs;
  if (bgr24) {
    for (; h > 0; dst += dstride, src += sstride, h--)
      bgr888_to_uyvy(dst, src, w);
  }
  else {
    for (; h > 0; dst += dstride, src += sstride, h--)
      bgr555_to_uyvy(dst, src, w);
  }

  SDL_UnlockYUVOverlay(plat_sdl_overlay);
}

static void overlay_hud_print(int x, int y, const char *str, int bpp)
{
  SDL_LockYUVOverlay(plat_sdl_overlay);
  basic_text_out_uyvy_nf(plat_sdl_overlay->pixels[0], plat_sdl_overlay->w, x, y, str);
  SDL_UnlockYUVOverlay(plat_sdl_overlay);
}

void *plat_gvideo_set_mode(int *w, int *h, int *bpp)
{
  psx_w = *w;
  psx_h = *h;
  change_video_mode();
  if (plat_sdl_overlay != NULL) {
    pl_plat_clear = plat_sdl_overlay_clear;
    pl_plat_blit = overlay_blit;
    pl_plat_hud_print = overlay_hud_print;
    return NULL;
  }
  else {
    pl_plat_clear = NULL;
    pl_plat_blit = NULL;
    pl_plat_hud_print = NULL;
    if (plat_sdl_gl_active)
      return shadow_fb;
    else
      return plat_sdl_screen->pixels;
  }
}

void *plat_gvideo_flip(void)
{
  if (plat_sdl_overlay != NULL) {
    SDL_Rect dstrect = { 0, 0, plat_sdl_screen->w, plat_sdl_screen->h };
    SDL_DisplayYUVOverlay(plat_sdl_overlay, &dstrect);
    return NULL;
  }
  else if (plat_sdl_gl_active) {
    gl_flip(shadow_fb, psx_w, psx_h);
    return shadow_fb;
  }
  else {
    // XXX: no locking, but should be fine with SDL_SWSURFACE?
    SDL_Flip(plat_sdl_screen);
    return plat_sdl_screen->pixels;
  }
}

void plat_gvideo_close(void)
{
}

void plat_video_menu_enter(int is_rom_loaded)
{
  in_menu = 1;

  /* surface will be lost, must adjust pl_vout_buf for menu bg */
  if (plat_sdl_overlay != NULL)
    uyvy_to_rgb565(menubg_img, plat_sdl_overlay->pixels[0], psx_w * psx_h);
  else if (plat_sdl_gl_active)
    memcpy(menubg_img, shadow_fb, psx_w * psx_h * 2);
  else
    memcpy(menubg_img, plat_sdl_screen->pixels, psx_w * psx_h * 2);
  pl_vout_buf = menubg_img;

  change_video_mode();
}

void plat_video_menu_begin(void)
{
  if (plat_sdl_overlay != NULL || plat_sdl_gl_active) {
    g_menuscreen_ptr = shadow_fb;
  }
  else {
    SDL_LockSurface(plat_sdl_screen);
    g_menuscreen_ptr = plat_sdl_screen->pixels;
  }
}

void plat_video_menu_end(void)
{
  if (plat_sdl_overlay != NULL) {
    SDL_Rect dstrect = { 0, 0, plat_sdl_screen->w, plat_sdl_screen->h };

    SDL_LockYUVOverlay(plat_sdl_overlay);
    rgb565_to_uyvy(plat_sdl_overlay->pixels[0], shadow_fb,
      g_menuscreen_w * g_menuscreen_h);
    SDL_UnlockYUVOverlay(plat_sdl_overlay);

    SDL_DisplayYUVOverlay(plat_sdl_overlay, &dstrect);
  }
  else if (plat_sdl_gl_active) {
    gl_flip(g_menuscreen_ptr, g_menuscreen_w, g_menuscreen_h);
  }
  else {
    SDL_UnlockSurface(plat_sdl_screen);
    SDL_Flip(plat_sdl_screen);
  }
  g_menuscreen_ptr = NULL;
}

void plat_video_menu_leave(void)
{
  in_menu = 0;
}

/* unused stuff */
void *plat_prepare_screenshot(int *w, int *h, int *bpp)
{
  return 0;
}

void plat_trigger_vibrate(int is_strong)
{
}

void plat_minimize(void)
{
}

// vim:shiftwidth=2:expandtab