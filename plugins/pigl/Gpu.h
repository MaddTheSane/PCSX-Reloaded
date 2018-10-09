//
//  Gpu.h
//  pigl
//
//  Created by Brian Black on 6/13/18.
//

#ifndef Gpu_h
#define Gpu_h

#include "draw.h"

#define PSE_LT_GPU 2
#define HWND void *

typedef struct {
  short maskX;
  short maskY;
  short offsetX;
  short offsetY;
} textureWindowSetting_t;
typedef struct {
  signed short x;
  signed short y;
  unsigned short width;
  unsigned short height;
  signed short currentX;
  signed short currentY;
} GPUWrite_t;

extern unsigned char * psxVub;
extern rect_t drawingArea;
extern int statusReg;
extern vec2_t drawingOffset;
extern textureWindowSetting_t textureWindowSetting;

#endif /* Gpu_h */
