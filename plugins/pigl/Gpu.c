#include <OpenGL/gl.h>
#include <OpenGL/glext.h>
#include <OpenGL/glu.h>
#include <GLUT/glut.h>
#include "Gpu.h"
#include "window.h"

// TODO: replace these quick defs for undefined shit
static long lSelectedSlot;
static long iTransferMode;
static void BuildDispMenu(int i) {
    return;
};
// Vars below here are things I know
#define CALLBACK
unsigned char * psxVub;
int statusReg; // TODO: unsigned?
#define STATUSREG statusReg
static int dataReg;
#define DATAREG dataReg
vec2_t drawingOffset;
static vec2_t displayArea;
static vec2_t displayRes;
static GLenum displayColorMode = GL_UNSIGNED_SHORT_1_5_5_5_REV;
rect_t drawingArea;
textureWindowSetting_t textureWindowSetting;
const static int extraWordsByCommand[] = {
  0, 0, 2, 0, 0, 0, 0, 0, // 00
  0, 0, 0, 0, 0, 0, 0, 0, // 08
  0, 0, 0, 0, 0, 0, 0, 0, // 10
  0, 0, 0, 0, 0, 0, 0, 0, // 18
  3, 0, 3, 0, 6, 6, 6, 6, // 20
  4, 0, 4, 0, 8, 8, 8, 8, // 28
  5, 0, 5, 0, 8, 0, 8, 0, // 30
  7, 7, 7, 7, 11, 0, 11, 0, // 38
  2, 0, 2, 0, 0, 0, 0, 0, // 40
  0, 0, 0, 0, 0, 0, 0, 0, // 48
  3, 0, 3, 3, 0, 0, 0, 0, // 50
  0, 0, 0, 0, 0, 0, 0, 0, // 58
  2, 0, 2, 2, 3, 3, 3, 3, // 60
  0, 0, 0, 0, 0, 0, 0, 0, // 68
  0, 0, 0, 0, 0, 2, 0, 0, // 70
  1, 0, 0, 0, 0, 2, 0, 0, // 78
  3, 0, 0, 0, 0, 0, 0, 0, // 80
  0, 0, 0, 0, 0, 0, 0, 0, // 88
  0, 0, 0, 0, 0, 0, 0, 0, // 90
  0, 0, 0, 0, 0, 0, 0, 0, // 98
  2, 0, 0, 0, 0, 0, 0, 0, // a0
  0, 0, 0, 0, 0, 0, 0, 0, // a8
  0, 0, 0, 0, 0, 0, 0, 0, // b0
  0, 0, 0, 0, 0, 0, 0, 0, // b8
  2, 0, 0, 0, 0, 0, 0, 0, // c0
  0, 0, 0, 0, 0, 0, 0, 0, // c8
  0, 0, 0, 0, 0, 0, 0, 0, // d0
  0, 0, 0, 0, 0, 0, 0, 0, // d8
  0, 0, 0, 0, 0, 0, 0, 0, // e0
  0, 0, 0, 0, 0, 0, 0, 0, // e8
  0, 0, 0, 0, 0, 0, 0, 0, // f0
  0, 0, 0, 0, 0, 0, 0, 0, // f8
};
static unsigned int commandWordsExpected;
static unsigned int commandWordsReceived;
static unsigned int commandWordsBuffer[256];
static GPUWrite_t GPUWrite;
static GPUWrite_t GPURead;
static GLuint vramTexture;
static GLuint vramTexture2;
static bool treatWordsAsPixelData;

////////////////////////////////////////////////////////////////////////
// PPDK developer must change libraryName field and can change revision and build
////////////////////////////////////////////////////////////////////////

const  unsigned char version  = 1;    // do not touch - library for PSEmu 1.x
const  unsigned char revision = 1;
const  unsigned char build    = 46;
static char *libraryName      = "pi's opengl driver";
#define VRAM_WIDTH 1024
#define VRAM_HEIGHT 512
static unsigned int heightMask = VRAM_HEIGHT - 1;
static int VRAM_PIXEL_COUNT = VRAM_WIDTH * VRAM_HEIGHT;
static bool glInitialized = FALSE;

////////////////////////////////////////////////////////////////////////
// stuff to make this a true PDK module
////////////////////////////////////////////////////////////////////////

char * CALLBACK PSEgetLibName(void) {
 return libraryName;
}

unsigned long CALLBACK PSEgetLibType(void) {
  return PSE_LT_GPU;
}

unsigned long CALLBACK PSEgetLibVersion(void)
{
 return version<<16|revision<<8|build;
}

////////////////////////////////////////////////////////////////////////
// Init/shutdown, will be called just once on emu start/close
////////////////////////////////////////////////////////////////////////

long CALLBACK GPUinit() {
  return 0;
}

long CALLBACK GPUshutdown()                            // GPU SHUTDOWN
{
 return 0;
}

////////////////////////////////////////////////////////////////////////
// Snapshot func, save some snap into
////////////////////////////////////////////////////////////////////////

void CALLBACK GPUmakeSnapshot(void)                    // MAKE SNAPSHOT FILE
{
}

GLuint makeVramTexture(void){
  GLuint tex;
  glGenTextures(1, &tex);
  glBindTexture(GL_TEXTURE_2D, tex);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  return tex;
}

// TODO: move it
void display(void) {
  glClear(GL_COLOR_BUFFER_BIT);
  glEnable(GL_TEXTURE_2D);
  glBindTexture(GL_TEXTURE_2D, vramTexture);
  glTexImage2D(
    GL_TEXTURE_2D,
    0,
    GL_RGBA,
    VRAM_WIDTH,
    VRAM_HEIGHT,
    0,
    GL_RGBA,
    GL_UNSIGNED_SHORT_1_5_5_5_REV,
    (unsigned short *)psxVub
  );
  glBegin(GL_POLYGON);
  glTexCoord2i(0, 0);
  glVertex2i(-1, 1);
  glTexCoord2i(1, 0);
  glVertex2i(1, 1);
  glTexCoord2i(1, 1);
  glVertex2i(1, -1);
  glTexCoord2i(0, 1);
  glVertex2i(-1, -1);
  glEnd();
  glFlush();
}

void display2(void) {
  int w = displayColorMode == GL_UNSIGNED_SHORT_1_5_5_5_REV ? VRAM_WIDTH :
    (VRAM_WIDTH * 2 / 3);
  GLenum format = displayColorMode == GL_UNSIGNED_SHORT_1_5_5_5_REV ? GL_RGBA : GL_RGB;
  float u1 = (float)displayArea.x / w;
  float v1 = (float)displayArea.y / VRAM_HEIGHT;
  float u2 = u1 + (float)displayRes.x / w;
  float v2 = v1 + (float)displayRes.y / VRAM_HEIGHT;
  glClear(GL_COLOR_BUFFER_BIT);
  glEnable(GL_TEXTURE_2D);
  glBindTexture(GL_TEXTURE_2D, vramTexture2);
  glTexImage2D(
    GL_TEXTURE_2D,
    0,
    format, // internal
    w,
    VRAM_HEIGHT,
    0,
    format, // data being supplied
    displayColorMode,
    (unsigned short *)psxVub
  );
  glBegin(GL_POLYGON);
  glTexCoord2f(u1, v1);
  glVertex2f(-1, 1);
  glTexCoord2f(u2, v1);
  glVertex2f(1, 1);
  glTexCoord2f(u2, v2);
  glVertex2f(1, -1);
  glTexCoord2f(u1, v2);
  glVertex2f(-1, -1);
  glEnd();
  glFlush();
}

////////////////////////////////////////////////////////////////////////
// Open/close will be called when a games starts/stops
////////////////////////////////////////////////////////////////////////

long CALLBACK GPUopen(HWND hwndGPU) {
  int screenW = 640;
  int screenH = 480;
  psxVub = calloc(VRAM_PIXEL_COUNT * 2, sizeof(unsigned char));

  if (!glInitialized) {
    initGLWindow(VRAM_WIDTH, VRAM_HEIGHT);
    initScreenWindow(screenW, screenH);
    glInitialized = TRUE;
    
    makeCurrentContext();
    glViewport(0, 0, VRAM_WIDTH, VRAM_HEIGHT);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    vramTexture = makeVramTexture();
    
    makeCurrentContext2();
    glViewport(0, 0, screenW, screenH);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    vramTexture2 = makeVramTexture();
  }

  return 0;
}

long CALLBACK GPUclose() {
  free(psxVub);
  return 0;
}

////////////////////////////////////////////////////////////////////////
// UpdateLace will be called on every vsync
////////////////////////////////////////////////////////////////////////

void CALLBACK GPUupdateLace(void) {
  makeCurrentContext(); // confirmed required
  display();
  makeCurrentContext2(); // confirmed required
  display2();
}

////////////////////////////////////////////////////////////////////////
// process read request from GPU status register
////////////////////////////////////////////////////////////////////////

unsigned long CALLBACK GPUreadStatus(void) {
  // printf("GPUreadStatus\n");
  return STATUSREG;
}

////////////////////////////////////////////////////////////////////////
// processes data send to GPU status register
////////////////////////////////////////////////////////////////////////

// new: for freezing stuff... memset it to 0 at GPUinit !
unsigned long ulStatusControl[256];

void CALLBACK GPUwriteStatus(unsigned long gdata) {
  unsigned long lCommand = (gdata >> 24) & 0xff;
  // printf("GPUwriteStatus %08x\n", gdata);
  ulStatusControl[lCommand] = gdata;                      // store command for freezing

  switch (lCommand) {
    case 0x00: // Reset GPU
      STATUSREG = 0x14802000; // TODO: make this less magic-numbery
      break;
    case 0x01: // Reset command buffer / clear fifo (TODO: do it)
      break;
    case 0x02: // Acknowledge GPU interrupt (IRQ1)
      STATUSREG &= 0xfeffffff;  // "Resets the IRQ flag in GPUSTAT.24"
      break;
    case 0x03: // Enable/disable display (0=enable; 1=disable)
      STATUSREG &= 0xff7fffff;
      STATUSREG |= (gdata & 0b1) << 23;
      break;
    case 0x04: // Set DMA direction (0=off, 1=fifo, 2=cpu->gp0, 3=GPUREAD->CPU)
      STATUSREG &= 0x9fffffff;
      STATUSREG |= (gdata & 0b11) << 29;
      break;
    case 0x05: // Set display area location (upper-left) in vram
      displayArea.x = gdata & 0x03ff;
      displayArea.y = (gdata >> 10) & 0x01ff;
      break;
    case 0x06: // Set display x-range on screen TODO: do it
      break;
    case 0x07: // Set display y-range on screen TODO: do it
      break;
    case 0x08: // Set display mode TODO: do it
      displayRes.x = gdata & 0x40 ? 368 :
        ((gdata & 0x1 ? 320 : 256) * (gdata & 0x2 ? 2 : 1));
      displayRes.y = gdata & 0x4 ? 480 : 240;
      if (gdata >> 4 & 0x1) {
        displayColorMode = GL_UNSIGNED_BYTE;
      } else {
        displayColorMode = GL_UNSIGNED_SHORT_1_5_5_5_REV;
      }
      break;
    case 0x10: // Get GPU Info
      switch (gdata & 0xf) { // param
        case 0x07: // read GPU type (usually 2) see "gpu versions"
          DATAREG = 2;
          break;
      }
      break;
    default:
      printf("Unknown GP1 cmd received: %08lx\n", gdata);
      break;
  }
}



////////////////////////////////////////////////////////////////////////
// core read from vram
////////////////////////////////////////////////////////////////////////

unsigned long CALLBACK GPUreadData(void) {
  return DATAREG;
}

// new function, used by ePSXe, for example, to read a whole chunk of data

void CALLBACK GPUreadDataMem(unsigned long * pMem, int iSize) {
  // iSize is the number of WORDS (i.e. pixel PAIRS) to read
  int pixelNum = 0;
  unsigned short * usMem = (unsigned short *) pMem;

  while ((GPURead.currentX < GPURead.x + GPURead.width) &&
         (GPURead.currentY < GPURead.y + GPURead.height) &&
         (pixelNum < iSize * 2)) {
    usMem[pixelNum] = *(getPixel(GPURead.currentX, GPURead.currentY));
    pixelNum += 1;
    GPURead.currentX += 1;
    if (GPURead.currentX >= GPURead.x + GPURead.width) {
      GPURead.currentX = GPURead.x;
      GPURead.currentY += 1;
    }
  }
  // did we just finish reading the last line?
  if (GPURead.currentY > GPURead.y + GPURead.height) {
    statusReg &= 0xf7ffffff;
  }
}

void setupWriteTextureToVram(unsigned int * buffer, unsigned int count) {
  GPUWrite.x = GPUWrite.currentX = buffer[1] & 0xffff;
  GPUWrite.y = GPUWrite.currentY = (buffer[1] >> 16) & 0xffff;
  GPUWrite.width = buffer[2] & 0xffff;
  GPUWrite.height = (buffer[2] >> 16) & 0xffff;
  treatWordsAsPixelData = true;
//   printf("Prepared CPU->VRAM: %d * %d @ (%d, %d)\n",
//         GPUWrite.width, GPUWrite.height, GPUWrite.x, GPUWrite.y);
}

void setupReadFromVram(unsigned int * buffer, unsigned int count) {
  unsigned short x = buffer[1] & 0xffff;
  unsigned short y = (buffer[1] >> 16) & 0xffff;
  unsigned short width = buffer[2] & 0xffff;
  unsigned short height = (buffer[2] >> 16) & 0xffff;
  GPURead.currentX = GPURead.x = x;
  GPURead.currentY = GPURead.y = y;
  GPURead.width = width;
  GPURead.height = height;
  statusReg |= 0x08000000;
}

void executeCommandWordBuffer(unsigned int buffer[256], unsigned int count) {
  unsigned int command = (buffer[0] >> 24) & 0xff;

  // printf("Executing command %02x\n", command);
  switch (command) {
    case 0x00: // noop
      break;
    case 0x01: // docs unclear - clear fifo, like GP1(01h)? clear texture cache? ??
      break;
    case 0x02: // single-color rect, var size, opaque
      fillRect(buffer, count);
      break;
    case 0x20: // the simplest possible poly. single color, 3 points, no shading, no transparency.
    case 0x22:
      drawSingleColorTri(buffer, count);
      break;
    case 0x24:
    case 0x26:
      drawTriTexturedTextureBlend(buffer, count);
      break;
    case 0x28:
    case 0x2a:
      drawQuad(buffer, count);
      break;
    case 0x2c:
    case 0x2d:
    case 0x2e:
    case 0x2f:
      drawQuadTexturedTextureBlend(buffer, count);
      break;
    case 0x30: // shaded tri, opaque
      drawTriShaded(buffer, count);
      break;
    case 0x32: // shaded tri, semi-trans
      drawTriShaded(buffer, count);
      break;
    case 0x34:
    case 0x36:
      drawTriTexturedShaded(buffer, count);
      break;
    case 0x38: // shaded quad, opaque
    case 0x39:
      drawQuadShaded(buffer, count);
      break;
    case 0x3c: // shaded quad, opaque, texblend
      drawQuadTexturedShaded(buffer, count);
      break;
    case 0x3a: // shaded quad, semi-trans
    case 0x3b:
      drawQuadShaded(buffer, count);
      break;
    case 0x3e:
      drawQuadTexturedShaded(buffer, count);
      break;
    case 0x40:
    case 0x42:
      drawLine(buffer, count);
      break;
    case 0x50:
    case 0x52:
    case 0x53:
      drawShadedLine(buffer, count);
      break;
    case 0x60: // single-color rect, var size, opaque
    case 0x61:
    case 0x62: // single-color rect, var size, semi-trans
    case 0x63:
    case 0x78: // single-color rect, 16x16, opaque
      drawSingleColorRect(buffer, count);
      break;
    case 0x64: // when opponent strikes cloud in battle
    case 0x65:
    case 0x66:
    case 0x67:
    case 0x75:
    case 0x7d:
      drawTexturedRect(buffer, count);
      break;
    case 0x80:
      copyVramToVram(buffer);
      break;
    case 0xa0: // write texture to vram
      setupWriteTextureToVram(buffer, count);
      break;
    case 0xc0:
      setupReadFromVram(buffer, count);
      break;
    case 0xe1: // draw mode setting
      STATUSREG &= 0xfffffc00; // copy least-sig 10 bits to status reg...
      STATUSREG |= (buffer[0] & 0x3ff);
      STATUSREG &= 0xffff7fff; // copy bit 11 to bit 15 of status reg...
      STATUSREG |= ((buffer[0] << 4) & 0x800);
      // TODO: handle bits 12, 13 (textured rectangle x, y flip)
      break;
    case 0xe2: // texture window setting
      textureWindowSetting.maskX = buffer[0] & 0x1f;
      textureWindowSetting.maskY = (buffer[0] >> 5) & 0x1f;
      textureWindowSetting.offsetX = (buffer[0] >> 10) & 0x1f;
      textureWindowSetting.offsetY = (buffer[0] >> 15) & 0x1f;
      break;
    case 0xe3: // set drawing area x1, y1
      drawingArea.x1 = buffer[0] & 0x3ff;
      drawingArea.y1 = (buffer[0] >> 10) & 0x1ff;
      break;
    case 0xe4: // set drawing area x2, y2
      drawingArea.x2 = buffer[0] & 0x3ff;
      drawingArea.y2 = (buffer[0] >> 10) & 0x1ff;
      break;
    case 0xe5: // set drawing offset (typically within drawing area)
      // HERE: 11 bits, not 10--and they're 11-bit signed values.
      drawingOffset.x = buffer[0] & 0x7ff;
      if (drawingOffset.x & 0x400) {
        drawingOffset.x = drawingOffset.x & 0xfffff800;
      }
      drawingOffset.y = (buffer[0] >> 11) & 0x7ff;
      if (drawingOffset.y & 0x400) {
        drawingOffset.y = drawingOffset.y & 0xfffff800;
      }
      break;
    case 0xe6: // mask bit setting
      STATUSREG &= 0xffffe7ff;
      STATUSREG |= ((buffer[0] << 11) & 0x1800);
      break;
    default:
      printf("Command not yet implemented: %02x\n", command);
      break;
  }
}

// new function, used by ePSXe, for example, to write a whole chunk of data
// This represents a number (>= 1) of words written one-by-one to GPU0--
// For example, texture data via DMA2 following GP0(A0h)
void CALLBACK GPUwriteDataMem(unsigned int * pMem, int iSize) {
  unsigned short * psxVus = (unsigned short *) psxVub;
  unsigned short * usMem = (unsigned short *) pMem;
  int pixelNum = 0;
  unsigned char command;

  if (treatWordsAsPixelData) {
    // printf("GPU0 receiving %d things (words/pixelpairs?) to write to VRAM\n", iSize);
    while ((GPUWrite.currentX < GPUWrite.x + GPUWrite.width) &&
           (GPUWrite.currentY < GPUWrite.y + GPUWrite.height) &&
           (pixelNum < iSize * 2)) {
      // TODO: handle case when width not divisible by word width and might wrap mid-word
      psxVus[(GPUWrite.currentY & heightMask) * VRAM_WIDTH + GPUWrite.currentX] =
        usMem[pixelNum];
      pixelNum += 1;
      GPUWrite.currentX += 1;
      if (GPUWrite.currentX >= GPUWrite.x + GPUWrite.width) {
        GPUWrite.currentX = GPUWrite.x;
        GPUWrite.currentY += 1;
      }
    }
    // did we just finish the final line?
    if (GPUWrite.currentY >= GPUWrite.y + GPUWrite.height) {
      treatWordsAsPixelData = false;
    }
    // printf("wrote %d words to vram\n", wordNum);
  } else {
    for (int i = 0; i < iSize; i++) {
      // printf("GP0(%08xh)\n", pMem[i]);
      commandWordsBuffer[commandWordsReceived] = pMem[i];
      if (commandWordsReceived == 0) {
        command = (pMem[i] >> 24) & 0xff;
        commandWordsExpected = 1 + extraWordsByCommand[command];
      }
      commandWordsReceived += 1;
      if (commandWordsReceived == commandWordsExpected) {
        // we've collected all params for the command; let it take effect
        executeCommandWordBuffer(commandWordsBuffer, commandWordsReceived);
        commandWordsReceived = 0;
        commandWordsExpected = 0;
      }
    }
  }
}

void CALLBACK GPUwriteData(unsigned int gdata) {
  // printf("GPUwriteData %08x\n", gdata);
  GPUwriteDataMem(&gdata, 1);
}

////////////////////////////////////////////////////////////////////////
// setting/getting the transfer mode (this functions are obsolte)
////////////////////////////////////////////////////////////////////////

void CALLBACK GPUsetMode(unsigned long gdata)
{
 return;
}

// this function will be removed soon
long CALLBACK GPUgetMode(void)
{
 return iTransferMode;
}

////////////////////////////////////////////////////////////////////////
// dma chain, process gpu commands
////////////////////////////////////////////////////////////////////////

long CALLBACK GPUdmaChain(unsigned long * baseAddrL, unsigned long addr) {
  // printf(">> receiving dma chain...\n");
  unsigned char *psxMem = (unsigned char *)baseAddrL;
  unsigned int *memBlockWords;
  unsigned char memBlockWordCount;
  unsigned long nextAddr;

  do {
    memBlockWords = (unsigned int *)(psxMem + addr);
    memBlockWordCount = (memBlockWords[0] >> 24) & 0xff;
    GPUwriteDataMem(memBlockWords + 1, memBlockWordCount);
    nextAddr = memBlockWords[0] & 0x00ffffff;
    // Syphon Filter, after the intro screens, will receive a DMA block
    // that contains GP0(E3,E4) and points to itself for the next block,
    // causing an infinite loop. Unclear why (emu core bug? no$ docs mention this:
    // "In SyncMode=1 and SyncMode=2, the hardware does update MADR (it will
    // contain the start address of the currently transferred block; at transfer
    // end, it'll hold the end-address in SyncMode=1, or the 00FFFFFFh end-code in
    // SyncMode=2)". Maybe it's related?
    if (nextAddr == addr) {
      break;
    }
    addr = nextAddr;
  } while (addr != 0x00ffffff);

  // printf("<< dma chain received\n");
  return 0;
}

////////////////////////////////////////////////////////////////////////
// call config dlg
////////////////////////////////////////////////////////////////////////

long CALLBACK GPUconfigure(void) {
  return 0;
}

////////////////////////////////////////////////////////////////////////
// show about dlg
////////////////////////////////////////////////////////////////////////
__attribute__((visibility("default")))
void CALLBACK GPUabout(void) {
  return;
}

////////////////////////////////////////////////////////////////////////
// test... well, we are ever fine ;)
////////////////////////////////////////////////////////////////////////

long CALLBACK GPUtest(void)
{
 // if test fails this function should return negative value for error (unable to continue)
 // and positive value for warning (can continue but output might be crappy)
 return 0;
}


////////////////////////////////////////////////////////////////////////
// special debug function, only available in Pete's Soft GPU
////////////////////////////////////////////////////////////////////////

void CALLBACK GPUdisplayText(char * pText)
{
}

////////////////////////////////////////////////////////////////////////
// special info display function, only available in Pete's GPUs right now
////////////////////////////////////////////////////////////////////////

void CALLBACK GPUdisplayFlags(unsigned long dwFlags)
{
 // currently supported flags:
 // bit 0 -> Analog pad mode activated
 // bit 1 -> PSX mouse mode activated
 // display this info in the gpu menu/fps display
}

////////////////////////////////////////////////////////////////////////
// Freeze
////////////////////////////////////////////////////////////////////////

typedef struct
{
 unsigned long ulFreezeVersion;      // should be always 1 for now (set by main emu)
 unsigned long ulStatus;             // current gpu status
 unsigned long ulControl[256];       // latest control register values
 unsigned char psxVRam[1024*512*2];  // current VRam image
} GPUFreeze_t;

////////////////////////////////////////////////////////////////////////

long CALLBACK GPUfreeze(unsigned long ulGetFreezeData,GPUFreeze_t * pF)
{
 //----------------------------------------------------//
 if(ulGetFreezeData==2)                                // 2: info, which save slot is selected? (just for display)
  {
   long lSlotNum=*((long *)pF);                        // -> a bit dirty, I know... ehehe
   lSelectedSlot=lSlotNum+1;
   BuildDispMenu(0);                                   // -> that's one of my funcs to display the "lSelectedSlot" number
   return 1;
  }
 //----------------------------------------------------//
 if(!pF)                    return 0;                  // some checks
 if(pF->ulFreezeVersion!=1) return 0;

 if(ulGetFreezeData==1)                                // 1: get data
  {
   pF->ulStatus=STATUSREG;
   memcpy(pF->ulControl,ulStatusControl,256*sizeof(unsigned long));
   memcpy(pF->psxVRam,  psxVub,         1024*512*2);

   return 1;
  }

 if(ulGetFreezeData!=0) return 0;                      // 0: set data

 STATUSREG=pF->ulStatus;
 memcpy(ulStatusControl,pF->ulControl,256*sizeof(unsigned long));
 memcpy(psxVub,         pF->psxVRam,  1024*512*2);

// RESET TEXTURE STORE HERE, IF YOU USE SOMETHING LIKE THAT

 GPUwriteStatus(ulStatusControl[0]);
 GPUwriteStatus(ulStatusControl[1]);
 GPUwriteStatus(ulStatusControl[2]);
 GPUwriteStatus(ulStatusControl[3]);
 GPUwriteStatus(ulStatusControl[8]);                   // try to repair things
 GPUwriteStatus(ulStatusControl[6]);
 GPUwriteStatus(ulStatusControl[7]);
 GPUwriteStatus(ulStatusControl[5]);
 GPUwriteStatus(ulStatusControl[4]);

 return 1;
}

void dumpVram(void) {
  unsigned short * psxVuw = (unsigned short *)psxVub;
  int w = VRAM_WIDTH;
  int h = VRAM_HEIGHT;
  FILE *file;
  file = fopen("/Users/bblack/Desktop/psx.vram.ppm", "w");
  fprintf(file, "P6\n");
  fprintf(file, "%d %d\n", w, h);
  fprintf(file, "255\n"); // pixel depth
  for (int i = 0; i < w * h; i++) {
    fputc((psxVuw[i] << 3) & 0b11111000, file); // r
    fputc((psxVuw[i] >> 2) & 0b11111000, file); // g
    fputc((psxVuw[i] >> 7) & 0b11111000, file); // b
  };
  fclose(file);
}
