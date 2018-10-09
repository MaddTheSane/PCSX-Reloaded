//
//  draw.c
//  pigl
//
//  Created by Brian Black on 6/13/18.
//

#include "draw.h"
#include "Gpu.h"

unsigned short * getPixel(int x, int y) {
  return (unsigned short *)psxVub + (y * VRAM_WIDTH + x);
}

unsigned short get15from24(unsigned int color) {
  return ((color >> 9) & 0x7c00) |
  ((color >> 6) & 0x03e0) |
  ((color >> 3) & 0x001f);
}

unsigned short blend15bit(unsigned short src, unsigned short dest, unsigned char alphaMode) {
  unsigned short srcR = (src >> 10) & 0x1f;
  unsigned short destR = (dest >> 10) & 0x1f;
  unsigned short srcG = (src >> 5) & 0x1f;
  unsigned short destG = (dest >> 5) & 0x1f;
  unsigned short srcB = src & 0x1f;
  unsigned short destB = dest & 0x1f;
  unsigned short outR;
  unsigned short outG;
  unsigned short outB;
  if (src == 0x0000) {
    return dest;
  }
  if (!(src & 0x8000)) { // if alpha bit = 0, return
    return src;
  }
  // TODO: use blend func indicated by status reg bits
  // dest - src:
  switch (alphaMode) {
    case 0:
      outR = destR / 2 + srcR / 2;
      outG = destG / 2 + srcG / 2;
      outB = destB / 2 + srcB / 2;
      break;
    case 1:
      outR = destR + srcR;
      outG = destG + srcG;
      outB = destB + srcB;
      if (outR > 31) outR = 31;
      if (outG > 31) outG = 31;
      if (outB > 31) outB = 31;
      break;
    case 2:
      outR = (destR < srcR ? 0 : destR - srcR);
      outG = (destG < srcG ? 0 : destG - srcG);
      outB = (destB < srcB ? 0 : destB - srcB);
      break;
    case 3:
      outR = (destR + srcR / 4);
      outG = (destG + srcG / 4);
      outB = (destB + srcB / 4);
      if (outR > 31) outR = 31;
      if (outG > 31) outG = 31;
      if (outB > 31) outB = 31;
      break;
    default:
      printf("alpha mode %d not implemented\n", alphaMode);
      outR = outG = outB = 0;
  }
  return 0x8000 | // alpha bit on. TODO: respect mask bit setting (statusReg bits 11 and 12, set by GP0(e6))
  ((outR << 10) & 0x7c00) |
  ((outG << 5) & 0x03e0) |
  (outB & 0x001f);
}

unsigned int blend24(unsigned int c0, unsigned int c1, float d) {
  unsigned int cout = 0x000000;
  unsigned int channelOut;
  for (int shift = 0; shift < 24; shift += 8) {
    channelOut =
    (c0 >> shift & 0xff) * d +
    (c1 >> shift & 0xff) * (1 - d);
    if (channelOut > 0xff) channelOut = 0xff;
    cout |= ((short)channelOut) << shift;
  }
  return cout;
}

// this is NOT semi-trans blending--this is "draw blended poly" blending
unsigned short blend24bit(unsigned short color, unsigned int blender) {
  unsigned short b = (color >> 7 & 0xf8) * (blender >> 16 & 0xff) / 0x80;
  unsigned short g = (color >> 2 & 0xf8) * (blender >> 8 & 0xff) / 0x80;
  unsigned short r = (color << 3 & 0xf8) * (blender & 0xff) / 0x80;
  if (b > 255) b = 255;
  if (g > 255) g = 255;
  if (r > 255) r = 255;
  return (
          0x8000 | // alpha bit
          (b << 7 & 0x7c00) |
          (g << 2 & 0x03e0) |
          (r >> 3 & 0x001f)
          );
}

void copyVramToVram(unsigned int * buffer) {
  vec2_t fromLoc = {.x = buffer[1] & 0xffff, .y = (buffer[1] >> 16) & 0xffff};
  vec2_t toLoc = {.x = buffer[2] & 0xffff, .y = (buffer[2] >> 16) & 0xffff};
  vec2_t size = {.x = buffer[3] & 0xffff, .y = (buffer[3] >> 16) & 0xffff};
  unsigned short *psxVus = (unsigned short *)psxVub;
  for (int i = 0; i < size.y; i++) {
    memcpy(
      psxVus + (VRAM_WIDTH * toLoc.y + toLoc.x),
      psxVus + (VRAM_WIDTH * fromLoc.y + fromLoc.x),
      2 * size.x
    );
  }
}

vec2_t vertFromWord(unsigned int word) {
  vec2_t vert = {.y = (short)(word >> 16 & 0xffff), .x = (short)(word & 0xffff)};
  return vert;
}

// TODO: speedup e.g. with memset
void fillRect(unsigned int * buffer, unsigned int count) {
  int color = buffer[0] & 0xffffff; // 24-bit
  int color15 = get15from24(color);
  int originY = (buffer[1] >> 16) & 0xffff;
  int originX = buffer[1] & 0xffff;
  int height = (buffer[2] >> 16) & 0xffff;
  int width = buffer[2] & 0xffff;
  unsigned short * pixel;
  
  for (int y = originY; y < originY + height; y++) {
    for (int x = originX; x < originX + width; x++) {
      pixel = getPixel(x, y);
      *pixel = color15;
    }
  }
}

void drawSingleColorTri(unsigned int * buffer, unsigned int count) {
  unsigned int color = buffer[0] & 0x00ffffff;
  bool semiTrans = buffer[0] & 0x02000000;
  vec2_t v0 = vertFromWord(buffer[1]);
  vec2_t v1 = vertFromWord(buffer[2]);
  vec2_t v2 = vertFromWord(buffer[3]);
  vec2_t tri[] = {v0, v1, v2};
  unsigned int colors[] = {color, color, color};
  
  drawTexturedTri(tri, NULL, colors, NOTEXPAGE, NOCLUT, semiTrans);
}

void drawTriTexturedTextureBlend(unsigned int * buffer, unsigned int count) {
  unsigned int color = buffer[0] & 0x00ffffff;
  bool semiTrans = buffer[0] & 0x02000000;
  vec2_t v0 = vertFromWord(buffer[1]);
  vec2_t v1 = vertFromWord(buffer[3]);
  vec2_t v2 = vertFromWord(buffer[5]);
  vec2_t uv0 = {.y = (buffer[2] >> 8) & 0xff, .x = (buffer[2] & 0xff)};
  vec2_t uv1 = {.y = (buffer[4] >> 8) & 0xff, .x = (buffer[4] & 0xff)};
  vec2_t uv2 = {.y = (buffer[6] >> 8) & 0xff, .x = (buffer[6] & 0xff)};
  vec2_t tri[] = {v0, v1, v2};
  vec2_t texcoords[] = {uv0, uv1, uv2};
  unsigned int colors[] = {color, color, color};
  unsigned short texpage = (buffer[4] >> 16) & 0xffff;
  unsigned short clut = (buffer[2] >> 16) & 0xffff;
  
  drawTexturedTri(tri, texcoords, colors, texpage, clut, semiTrans);
}

void drawQuad(unsigned int * buffer, unsigned int count) {
  bool semiTrans = buffer[0] & 0x02000000;
  vec2_t v0 = vertFromWord(buffer[1]);
  vec2_t v1 = vertFromWord(buffer[2]);
  vec2_t v2 = vertFromWord(buffer[3]);
  vec2_t v3 = vertFromWord(buffer[4]);
  unsigned int color = buffer[0] & 0x00ffffff;
  vec2_t tri0[] = {v0, v1, v2};
  vec2_t tri1[] = {v2, v1, v3};
  unsigned int colors[] = {color, color, color};
  drawTexturedTri(tri0, NULL, colors, NOTEXPAGE, NOCLUT, semiTrans);
  drawTexturedTri(tri1, NULL, colors, NOTEXPAGE, NOCLUT, semiTrans);
}

void drawQuadTexturedTextureBlend(unsigned int * buffer, unsigned int count) {
  unsigned int color = buffer[0] & 0x00ffffff;
  bool semiTrans = buffer[0] & 0x02000000;
  bool blend = !(buffer[0] & 0x01000000);
  vec2_t v0 = vertFromWord(buffer[1]);
  vec2_t v1 = vertFromWord(buffer[3]);
  vec2_t v2 = vertFromWord(buffer[5]);
  vec2_t v3 = vertFromWord(buffer[7]);
  vec2_t uv0 = {.y = (buffer[2] >> 8) & 0xff, .x = (buffer[2] & 0xff)};
  vec2_t uv1 = {.y = (buffer[4] >> 8) & 0xff, .x = (buffer[4] & 0xff)};
  vec2_t uv2 = {.y = (buffer[6] >> 8) & 0xff, .x = (buffer[6] & 0xff)};
  vec2_t uv3 = {.y = (buffer[8] >> 8) & 0xff, .x = (buffer[8] & 0xff)};
  vec2_t tri0[] = {v0, v1, v2};
  vec2_t tri1[] = {v2, v1, v3};
  vec2_t texcoords0[] = {uv0, uv1, uv2};
  vec2_t texcoords1[] = {uv2, uv1, uv3};
  unsigned int colors[] = {color, color, color}; // TODO: don't allocate when not blending
  unsigned short texpage = (buffer[4] >> 16) & 0xffff;
  unsigned short clut = (buffer[2] >> 16) & 0xffff;
  drawTexturedTri(tri0, texcoords0, blend ? colors : NULL, texpage, clut, semiTrans);
  drawTexturedTri(tri1, texcoords1, blend ? colors : NULL, texpage, clut, semiTrans);
}

void drawTriShaded(unsigned int * buffer, unsigned int count) {
  bool semiTrans = buffer[0] & 0x02000000;
  vec2_t v0 = vertFromWord(buffer[1]);
  vec2_t v1 = vertFromWord(buffer[3]);
  vec2_t v2 = vertFromWord(buffer[5]);
  unsigned int c0 = buffer[0] & 0x00ffffff;
  unsigned int c1 = buffer[2] & 0x00ffffff;
  unsigned int c2 = buffer[4] & 0x00ffffff;
  vec2_t tri[] = {v0, v1, v2};
  unsigned int colors[] = {c0, c1, c2};
  unsigned int texpage = statusReg & 0x7ff;
  drawTexturedTri(tri, NULL, colors, texpage, NOCLUT, semiTrans);
}

void drawTriTexturedShaded(unsigned int * buffer, unsigned int count) {
  bool semiTrans = buffer[0] & 0x02000000;
  vec2_t v0 = vertFromWord(buffer[1]);
  vec2_t v1 = vertFromWord(buffer[4]);
  vec2_t v2 = vertFromWord(buffer[7]);
  unsigned int c0 = buffer[0] & 0x00ffffff;
  unsigned int c1 = buffer[3] & 0x00ffffff;
  unsigned int c2 = buffer[6] & 0x00ffffff;
  vec2_t uv0 = {.y = (buffer[2] >> 8) & 0xff, .x = (buffer[2] & 0xff)};
  vec2_t uv1 = {.y = (buffer[5] >> 8) & 0xff, .x = (buffer[5] & 0xff)};
  vec2_t uv2 = {.y = (buffer[8] >> 8) & 0xff, .x = (buffer[8] & 0xff)};
  vec2_t tri[] = {v0, v1, v2};
  unsigned int colors[] = {c0, c1, c2};
  vec2_t texcoords[] = {uv0, uv1, uv2};
  unsigned short texpage = (buffer[5] >> 16) & 0xffff;
  unsigned short clut = (buffer[2] >> 16) & 0xffff;
  drawTexturedTri(tri, texcoords, colors, texpage, clut, semiTrans);
}

void drawQuadShaded(unsigned int * buffer, unsigned int count) {
  bool semiTrans = buffer[0] & 0x02000000;
  vec2_t v0 = vertFromWord(buffer[1]);
  vec2_t v1 = vertFromWord(buffer[3]);
  vec2_t v2 = vertFromWord(buffer[5]);
  vec2_t v3 = vertFromWord(buffer[7]);
  unsigned int c0 = buffer[0] & 0x00ffffff;
  unsigned int c1 = buffer[2] & 0x00ffffff;
  unsigned int c2 = buffer[4] & 0x00ffffff;
  unsigned int c3 = buffer[6] & 0x00ffffff;
  vec2_t tri0[] = {v0, v1, v2};
  vec2_t tri1[] = {v2, v1, v3};
  unsigned int colors0[] = {c0, c1, c2};
  unsigned int colors1[] = {c2, c1, c3};
  drawTexturedTri(tri0, NULL, colors0, NOTEXPAGE, NOCLUT, semiTrans);
  drawTexturedTri(tri1, NULL, colors1, NOTEXPAGE, NOCLUT, semiTrans);
}

void drawQuadTexturedShaded(unsigned int * buffer, unsigned int count) {
  vec2_t v0 = vertFromWord(buffer[1]);
  vec2_t v1 = vertFromWord(buffer[4]);
  vec2_t v2 = vertFromWord(buffer[7]);
  vec2_t v3 = vertFromWord(buffer[10]);
  unsigned int c0 = buffer[0] & 0x00ffffff;
  unsigned int c1 = buffer[3] & 0x00ffffff;
  unsigned int c2 = buffer[6] & 0x00ffffff;
  unsigned int c3 = buffer[9] & 0x00ffffff;
  vec2_t uv0 = {.y = (buffer[2] >> 8) & 0xff, .x = (buffer[2] & 0xff)};
  vec2_t uv1 = {.y = (buffer[5] >> 8) & 0xff, .x = (buffer[5] & 0xff)};
  vec2_t uv2 = {.y = (buffer[8] >> 8) & 0xff, .x = (buffer[8] & 0xff)};
  vec2_t uv3 = {.y = (buffer[11] >> 8) & 0xff, .x = (buffer[11] & 0xff)};
  vec2_t tri0[] = {v0, v1, v2};
  vec2_t tri1[] = {v2, v1, v3};
  unsigned int colors0[] = {c0, c1, c2};
  unsigned int colors1[] = {c2, c1, c3};
  vec2_t texcoords0[] = {uv0, uv1, uv2};
  vec2_t texcoords1[] = {uv2, uv1, uv3};
  unsigned short texpage = (buffer[5] >> 16) & 0xffff;
  unsigned short clut = (buffer[2] >> 16) & 0xffff;
  bool semitrans = buffer[0] & 0x02000000;
  drawTexturedTri(tri0, texcoords0, colors0, texpage, clut, semitrans);
  drawTexturedTri(tri1, texcoords1, colors1, texpage, clut, semitrans);
}

// TODO: DRY w/ drawshadedline
void drawLine(unsigned int * buffer, unsigned int count) {
  unsigned int color = buffer[0] & 0x00ffffff;
  signed short x0 = buffer[1] & 0xffff;
  signed short y0 = buffer[1] >> 16 & 0xffff;
  signed short x1 = buffer[2] & 0xffff;
  signed short y1 = buffer[2] >> 16 & 0xffff;
  bool semiTrans = buffer[0] & 0x02000000;
  short x;
  short y;
  unsigned short * pixel;
  unsigned short alphaMode = semiTrans ? (statusReg >> 5 & 0x3) : 0;
  // TODO: bresenham
  // TODO: use drawing offset!
  // TODO: clip when outside drawing area! these are causing segfault on starting a race!
  if (abs(x0 - x1) > abs(y0 - y1)) {
    for (x = x0; x != x1; x += x0 > x1 ? -1 : 1) {
      y = (((float)x - x0) / (x1 - x0)) * (y1 - y0) + y0;
      if (x + drawingOffset.x < drawingArea.x1 || x + drawingOffset.x > drawingArea.x2)
        continue;
      if (y + drawingOffset.y < drawingArea.y1 || y + drawingOffset.y > drawingArea.y2)
        continue;
      pixel = getPixel(x + drawingOffset.x, y + drawingOffset.y);
      *pixel = blend15bit(get15from24(color), *pixel, alphaMode);
    }
  } else {
    for (y = y0; y != y1; y += y0 > y1 ? -1 : 1) {
      x = (((float)y - y0) / (y1 - y0)) * (x1 - x0) + x0;
      if (x + drawingOffset.x < drawingArea.x1 || x + drawingOffset.x > drawingArea.x2)
        continue;
      if (y + drawingOffset.y < drawingArea.y1 || y + drawingOffset.y > drawingArea.y2)
        continue;
      pixel = getPixel(x + drawingOffset.x, y + drawingOffset.y);
      *pixel = blend15bit(get15from24(color), *pixel, alphaMode);
    }
  }
}

void drawShadedLine(unsigned int * buffer, unsigned int count) {
  unsigned int color0 = buffer[0] & 0x00ffffff;
  unsigned int color1 = buffer[2] & 0x00ffffff;
  signed short x0 = buffer[1] & 0xffff;
  signed short y0 = buffer[1] >> 16 & 0xffff;
  signed short x1 = buffer[3] & 0xffff;
  signed short y1 = buffer[3] >> 16 & 0xffff;
  bool semiTrans = buffer[0] & 0x02000000;
  short x;
  short y;
  unsigned short * pixel;
  unsigned short alphaMode = semiTrans ? (statusReg >> 5 & 0x3) : 0;
  // TODO: bresenham
  // TODO: use drawing offset
  // TODO: clip when outside drawing area
  if (abs(x0 - x1) > abs(y0 - y1)) {
    for (x = x0; x != x1; x += x0 > x1 ? -1 : 1) {
      y = (((float)x - x0) / (x1 - x0)) * (y1 - y0) + y0;
      if (x + drawingOffset.x < drawingArea.x1 || x + drawingOffset.x > drawingArea.x2)
        continue;
      if (y + drawingOffset.y < drawingArea.y1 || y + drawingOffset.y > drawingArea.y2)
        continue;
      pixel = getPixel(x + drawingOffset.x, y + drawingOffset.y);
      *pixel = blend15bit(
                          get15from24(blend24(color0, color1, (float)x / (x1 - x0))),
                          *pixel,
                          alphaMode
                          );
    }
  } else {
    for (y = y0; y != y1; y += y0 > y1 ? -1 : 1) {
      x = (((float)y - y0) / (y1 - y0)) * (x1 - x0) + x0;
      if (x + drawingOffset.x < drawingArea.x1 || x + drawingOffset.x > drawingArea.x2)
        continue;
      if (y + drawingOffset.y < drawingArea.y1 || y + drawingOffset.y > drawingArea.y2)
        continue;
      pixel = getPixel(x + drawingOffset.x, y + drawingOffset.y);
      *pixel = blend15bit(
                          get15from24(blend24(color0, color1, (float)y / (y1 - y0))),
                          *pixel,
                          alphaMode
                          );
    }
  }
}

void drawSingleColorRect(unsigned int * buffer, unsigned int count) {
  bool semiTrans = (buffer[0] & 0x02000000) != 0;
  int color = buffer[0] & 0xffffff; // 24-bit
  int color15 = get15from24(color);
  short originY = (short)(buffer[1] >> 16 & 0xffff);
  short originX = (short)(buffer[1] & 0xffff);
  unsigned short height;
  unsigned short width;
  unsigned char command = buffer[0] >> 24 & 0xff;
  if (command <= 0x63) {
    width = buffer[2] & 0xffff;
    height = (buffer[2] >> 16) & 0xffff;
  } else if (command <= 0x6b) {
    width = height = 1;
  } else if (command <= 0x73) {
    width = height = 8;
  } else {
    width = height = 16;
  }
  int yMin = originY + drawingOffset.y;
  int yMax = originY + drawingOffset.y + height;
  int xMin = originX + drawingOffset.x;
  int xMax = originX + drawingOffset.x + width;
  unsigned short * pixel;
  
  for (int y = yMin; y < yMax; y++) {
    if (y < drawingArea.y1 || y > drawingArea.y2) {
      continue;
    }
    for (int x = xMin; x < xMax; x++) {
      if (x < drawingArea.x1 || x > drawingArea.x2) {
        continue;
      }
      pixel = getPixel(x, y);
      if (semiTrans) {
        *pixel = blend15bit(color15 | 0x8000, *pixel, (statusReg >> 5) & 0x3);
      } else {
        *pixel = color15;
      }
    }
  }
}

void drawTexturedRect(unsigned int * buffer, unsigned int count) {
  bool semiTrans = buffer[0] & 0x02000000;
  bool blend = !(buffer[0] & 0x01000000);
  unsigned int color = buffer[0] & 0x00ffffff;
  unsigned int colors[3] = {color, color, color}; // TODO: don't allocate this when not blending
  signed short y = (buffer[1] >> 16) & 0xffff;
  signed short x = buffer[1] & 0xffff;
  unsigned short clut = (buffer[2] >> 16) & 0xffff;
  unsigned short uMin = buffer[2] & 0xff;
  unsigned short vMin = (buffer[2] >> 8) & 0xff;
  unsigned short height;
  unsigned short width;
  unsigned short uMax;
  unsigned short vMax;
  unsigned char command = buffer[0] >> 24 & 0xff;
  // TODO: should we be adding one pixel due to the top-left rule?
  if (command >= 0x7c) { // TODO: succinctify by using relevant bits
    height = width = 16;
  } else if (command >= 0x74) {
    height = width = 8;
  } else if (command >= 0x6c) {
    height = width = 1;
  } else {
    height = buffer[3] >> 16 & 0xffff;
    width = buffer[3] & 0xffff;
  }
  uMax = uMin + width;
  if (uMax > 255) uMax = 255;
  vMax = vMin + height;
  if (vMax > 255) vMax = 255;
  vec2_t v0 = {.y = y, .x = x};
  vec2_t v1 = {.y = y, .x = x + width};
  vec2_t v2 = {.y = y + height, .x = x + width};
  vec2_t v3 = {.y = y + height, .x = x};
  vec2_t uv0 = {.y = vMin, .x = uMin};
  vec2_t uv1 = {.y = vMin, .x = uMax};
  vec2_t uv2 = {.y = vMax, .x = uMax};
  vec2_t uv3 = {.y = vMax, .x = uMin};
  vec2_t tri0[] = {v0, v1, v2};
  vec2_t tri1[] = {v2, v3, v0};
  vec2_t texcoords0[] = {uv0, uv1, uv2};
  vec2_t texcoords1[] = {uv2, uv3, uv0};
  unsigned short texpage = statusReg & 0x7ff; // TODO double-check this
  
  drawTexturedTri(tri0, texcoords0, blend ? colors : NULL, texpage, clut, semiTrans);
  drawTexturedTri(tri1, texcoords1, blend ? colors : NULL, texpage, clut, semiTrans);
}

void drawTexturedTri(vec2_t verts[], vec2_t texcoords[], unsigned int colors[], unsigned short texpage, unsigned short clut, bool semiTrans) {
  short vertCount = 3;
  short yMin = verts[0].y;
  short yMax = verts[0].y;
  short vertIndexL = 0;
  short vertIndexR = 0;
  short vertIndexNextL;
  short vertIndexNextR;
  float xLeft;
  float xRight;
  float doubleTriArea = (verts[0].y - verts[2].y) * (verts[1].x - verts[2].x) +
  (verts[1].y - verts[2].y) * (verts[2].x - verts[0].x);
  float b[] = {0, 0, 0};
  vec2_t uv;
  
  short texpageX = texpage & 0x000f; // *64
  short texpageY = (texpage & 0x0010) >> 4; // *256
  short texpageAlphaMode = (texpage & 0x0060) >> 5;
  short texpageColorDepth = (texpage & 0x0180) >> 7;
  // short texpageTextureDisable = (texpage & 0x0800) >> 11;
  unsigned short blendR;
  unsigned short blendG;
  unsigned short blendB;
  unsigned int blendColor;
  unsigned short outColor;
  unsigned short * psxVus = (unsigned short *)psxVub;
  unsigned short * psxVusTarget;
  
  // find top and bottom scanlines (yMin, yMax)
  // set left and right verts to leftmost and rightmost of top scanline (may be same)
  for (int i = 0; i < vertCount; i++) {
    if (verts[i].y < yMin) {
      yMin = verts[i].y;
      vertIndexL = i;
      vertIndexR = i;
    } else if (verts[i].y == yMin) {
      vertIndexR = i;
    }
    if (verts[i].y > yMax) {
      yMax = verts[i].y;
    }
  }
  // set initial values before iteration
  vertIndexNextL = (vertIndexL - 1 + vertCount) % vertCount;
  vertIndexNextR = (vertIndexR + 1) % vertCount;
  // iterate through scanlines
  // TODO: speedup
  // TODO: expect circular linked list to prevent all this modulo and index crap
  for (int y = yMin; y < yMax; y++) {
    if (verts[vertIndexNextL].y == y) {
      vertIndexL = vertIndexNextL;
      vertIndexNextL = (vertIndexNextL - 1 + vertCount) % vertCount;
    }
    if (verts[vertIndexNextR].y == y) {
      vertIndexR = vertIndexNextR;
      vertIndexNextR = (vertIndexNextR + 1) % vertCount;
    }
    if (y + drawingOffset.y < drawingArea.y1 || y + drawingOffset.y > drawingArea.y2) {
      continue;
    }
    // ((y - y0)/(y1 - y0))(x1 - x0) + x0
    xLeft = verts[vertIndexL].x + (
                                   (float)(y - verts[vertIndexL].y) /
                                   (verts[vertIndexNextL].y - verts[vertIndexL].y) *
                                   (verts[vertIndexNextL].x - verts[vertIndexL].x)
                                   );
    xRight = verts[vertIndexR].x + (
                                    (float)(y - verts[vertIndexR].y) /
                                    (verts[vertIndexNextR].y - verts[vertIndexR].y) *
                                    (verts[vertIndexNextR].x - verts[vertIndexR].x)
                                    );
    // draw scanline
    // TODO: move CW/CCW agnostic code to a more performant place, or make it more readable?
    for (int x = (short)(xLeft < xRight ? xLeft : xRight); x < (short)(xLeft < xRight ? xRight : xLeft); x++) {
      if (x + drawingOffset.x < drawingArea.x1 || x + drawingOffset.x > drawingArea.x2) {
        continue;
      }
      b[0] = ((y - verts[2].y) * (verts[1].x - verts[2].x) +
              (verts[1].y - verts[2].y) * (verts[2].x - x)) / doubleTriArea;
      b[1] = ((y - verts[0].y) * (verts[2].x - verts[0].x) +
              (verts[2].y - verts[0].y) * (verts[0].x - x)) / doubleTriArea;
      //      b[2] = ((y - verts[1].y) * (verts[0].x - verts[1].x) +
      //        (verts[0].y - verts[1].y) * (verts[1].x - x)) / doubleTriArea;
      b[2] = 1 - b[0] - b[1];
      if (texcoords) {
        uv.x = round(b[0] * texcoords[0].x + b[1] * texcoords[1].x + b[2] * texcoords[2].x);
        uv.y = round(b[0] * texcoords[0].y + b[1] * texcoords[1].y + b[2] * texcoords[2].y);
        outColor = sampleTexpage(texpageX, texpageY, uv, texpageColorDepth, clut);
      } else {
        outColor = 0x0000;
      }
      if (colors) {
        // TODO: clamp to 255
        blendB = (unsigned short)(
                                  (colors[0] >> 16 & 0xff) * b[0] +
                                  (colors[1] >> 16 & 0xff) * b[1] +
                                  (colors[2] >> 16 & 0xff) * b[2]
                                  );
        blendG = (unsigned short)(
                                  (colors[0] >> 8 & 0xff) * b[0] +
                                  (colors[1] >> 8 & 0xff) * b[1] +
                                  (colors[2] >> 8 & 0xff) * b[2]
                                  );
        blendR = (unsigned short)(
                                  (colors[0] & 0xff) * b[0] +
                                  (colors[1] & 0xff) * b[1] +
                                  (colors[2] & 0xff) * b[2]
                                  );
        if (texcoords) {
          if (outColor != 0x0000) { // remember, "full-black" is actually "full transparent"
            blendColor = (blendB << 16) | (blendG << 8) | (blendR);
            outColor = blend24bit(outColor, blendColor);
          }
        } else {
          outColor = 0x8000 | // alpha bit
          (blendB << 7 & 0x7c00) |
          (blendG << 2 & 0x03e0) |
          (blendR >> 3 & 0x001f);
        }
      }
      psxVusTarget = psxVus + (VRAM_WIDTH * (y + drawingOffset.y) + (x + drawingOffset.x));
      if (semiTrans) {
        outColor = blend15bit(outColor, *psxVusTarget, texpageAlphaMode);
      }
      if (outColor != 0x0000) { // remember, "full-black" is actually "full transparent"
        *psxVusTarget = outColor;
      }
    }
  }
}

unsigned short sampleTexpage(short texpageX, short texpageY, vec2_t uv, unsigned short colorDepth, unsigned short clut) {
  // TODO: either workaround here, or truly fix in rasterizer,
  // the case when rounding error causes a pixel at scanline edge
  // to be mapped outside the texwindow. worst case is when that
  // means invalid memory address.
  short u = (uv.x & (~(textureWindowSetting.maskX * 8))) |
  ((textureWindowSetting.offsetX & textureWindowSetting.maskX) * 8);
  short v = (uv.y & (~(textureWindowSetting.maskY * 8))) |
  ((textureWindowSetting.offsetY & textureWindowSetting.maskY) * 8);
  // set pixel to the halfword beginning the line
  unsigned short * pixel = getPixel(texpageX * 64, texpageY * 256 + v);
  unsigned short sample = 0x0000;
  unsigned short clutX = 16 * (clut & 0x3f);
  unsigned short clutY = (clut >> 6) & 0x1ff;
  
  switch (colorDepth) {
    case 0: // 4bit
      pixel += u / 4;
      sample = (*pixel >> (4 * (u % 4))) & 0xf;
      sample = *getPixel(clutX + sample, clutY);
      break;
    case 1: // 8bit
      pixel += u / 2;
      sample = (*pixel >> (8 * (u % 2))) & 0xff;
      sample = *getPixel(clutX + sample, clutY);
      break;
    case 2: // 16bit
      pixel += u;
      sample = (*pixel) & 0xffff;
      break;
  }
  return sample;
}
