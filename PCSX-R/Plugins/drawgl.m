/***************************************************************************
    drawgl.m
    an odd set of functions that seem misplaced ATM.
    presumably this is the glue to the C GPU plugin stuff
    but a much better place might be "PluginWindowController.m" as
    gluing is what a controller is made for.
    
    PeopsOpenGPU
  
    Created by Gil Pedersen on Sun April 18 2004.
    Copyright (c) 2004 Gil Pedersen.
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version. See also the license.txt file for *
 *   additional informations.                                              *
 *                                                                         *
 ***************************************************************************/

//#import "PluginWindowController.h"
//#import "PluginGLView.h"
#import "PCSXRGameCore.h"
#import <Cocoa/Cocoa.h>
#include <OpenGL/gl.h>
#include "ExtendedKeys.h"
#include "peopsxgl/externals.h"
#include "draw.h"
#include "gpu.h"
#include "menu.h"
#include "drawgl.h"

////////////////////////////////////////////////////////////////////////////////////
// misc globals
////////////////////////////////////////////////////////////////////////////////////
#if 0 // globals for OpenGL (vs. SoftGPU) are owned by others... weird
int            iResX;
int            iResY;
long           lLowerpart;
BOOL           bIsFirstFrame = TRUE;
BOOL           bCheckMask=FALSE;
unsigned short sSetMask=0;
/* unsigned long  lSetMask=0; */
uint32_t        sSetMassk=0;
int            iDesktopCol=16;
int            iShowFPS=0;
int            iWinSize; 
int            iUseScanLines=0;
int            iUseNoStretchBlt=0;
int            iFastFwd=0;
int            iDebugMode=0;
int            iFVDisplay=0;
PSXPoint_t     ptCursorPoint[8];
unsigned short usCursorActive=0;
char *			Xpixels;
char *         pCaptionText;
#endif

#define MAKELONG(low,high)     ((unsigned long)(((unsigned short)(low)) | (((unsigned long)((unsigned short)(high))) << 16)))


extern BOOL    bCheckMask;
extern BOOL    bIsFirstFrame;
extern int     iShowFPS;
extern unsigned short sSetMask;
extern int     iUseScanLines;
extern unsigned short usCursorActive;


extern int     iResX;
extern int     iResY;
long           lLowerpart;

uint32_t        sSetMassk=0;
int            iDesktopCol=16;
extern int     iWinSize; 
int            iUseNoStretchBlt=0;
int            iFastFwd=0;
int            iDebugMode=0;
int            iFVDisplay=0;
extern PSXPoint_t     ptCursorPoint[8];
char *			Xpixels;
char *         pCaptionText;

//static PluginWindowController *windowController;
// static is BAD NEWS if user uses other plug ins
@class PluginGLView;
PluginGLView *glView;
extern PCSXRGameCore *_current;

////////////////////////////////////////////////////////////////////////

void DoBufferSwap(void)                                // SWAP BUFFERS
{
#if 1
	//[glView swapBuffer];
#else
	static long long lastTickCount = -1;
	static int skipCount = 0;
	long long microTickCount;
	long deltaTime;
	
	Microseconds((struct UnsignedWide *)&microTickCount);
	deltaTime = (long)(microTickCount - lastTickCount);
	if (deltaTime <= (PSXDisplay.PAL ? 1000000/50 : 100000000 / 5994) ||
		 skipCount >= 3) {
		skipCount = 0;
		[glView swapBuffer];
	} else {
		skipCount++;
	}
	NSLog(@"count: %i", deltaTime); 
	lastTickCount = microTickCount;
#endif
}


////////////////////////////////////////////////////////////////////////

void DoClearScreenBuffer(void)                         // CLEAR DX BUFFER
{
	// clear the screen, and DON'T flush it
	//[glView clearBuffer:NO];
}


////////////////////////////////////////////////////////////////////////

void DoClearFrontBuffer(void)                          // CLEAR DX BUFFER
{
	// clear the screen, and flush it
	//[glView clearBuffer:YES];
}

////////////////////////////////////////////////////////////////////////

unsigned long ulInitDisplay(void)	// OPEN GAME WINDOW
{
	bUsingTWin = FALSE;
	
	//InitMenu(); // This function does nothing
	
	bIsFirstFrame = FALSE;
	
	if(iShowFPS)
	{
		//iShowFPS=0;
		ulKeybits |= KEY_SHOWFPS;
		szDispBuf[0] = 0;
		BuildDispMenu(0);
	}
	
	/*
	__block PluginWindowController *windowController;
	
	// this causes a runtime error if it's done on a thread other than the main thread
	RunOnMainThreadSync(^{
		windowController = [PluginWindowController openGameView];
		glView = [windowController openGLView];
		
		[[windowController window] setTitle:@(pCaptionText)];
	});
	
	return (unsigned long)[windowController window];
	 */
	return 0;
}


////////////////////////////////////////////////////////////////////////

void CloseDisplay(void)
{
	/*
	if (gameController) {
		[gameController close];
		gameController = nil;
		gameWindow = nil;
	}
	 */
}

void BringContextForward(void)
{
	[_current.renderDelegate willRenderFrameOnAlternateThread];
}

void SendContextBack(void)
{
	[_current.renderDelegate didRenderFrameOnAlternateThread];
}

void SetVSync(GLint myValue)
{
	_current.renderDelegate.enableVSync = myValue == 1;
}
////////////////////////////////////////////////////////////////////////

/* taken care of in menu.c
void CreatePic(unsigned char * pMem)
{
}
*/

///////////////////////////////////////////////////////////////////////////////////////

/* taken care of in menu.c
void DestroyPic(void)
{
}
*/

///////////////////////////////////////////////////////////////////////////////////////
/* taken care of in menu.c
void DisplayPic(void)
{
}
*/

///////////////////////////////////////////////////////////////////////////////////////

void ShowGpuPic(void)
{
	// this is the default implementation...
}

///////////////////////////////////////////////////////////////////////////////////////

void ShowTextGpuPic(void)
{
	// this is the default implementation...
}

void HandleKey(int keycode)
{
	switch (keycode) {
        case GPU_FRAME_LIMIT:
            if(bUseFrameLimit) {
                bUseFrameLimit = false;
                iFrameLimit = 1;
            }
            else {
                bUseFrameLimit = true;
                iFrameLimit = 2;
            }
            SetAutoFrameCap();
            break;
        case GPU_FAST_FORWARD:
            if(bUseFrameLimit) {
                bUseFrameLimit = false;
                iFrameLimit = 1;
                bUseFrameSkip = true;
                iFastFwd = 0;
            }
            else {
                bUseFrameLimit = true;
                iFrameLimit = 2;
                bUseFrameSkip = false;
                iFastFwd = 0;
            }
            bSkipNextFrame = FALSE;
            break;
		case GPU_FULLSCREEN_KEY:
			//[gameController setFullscreen:![gameController fullscreen]];
			break;
	}
}

unsigned char* PSXVideoBuffer()
{
	//return image;
	return NULL;
}

void setGPUDefaults()
{
	iResX = 640;
	iResY = 480;
	iWinSize = MAKELONG(iResX, iResY);
	iColDepth = 32;
	iFrameLimit = 2;
	fFrameRate = 60;
	dwCfgFixes = 0;
	iUseNoStretchBlt = 0;
	iShowFPS = 0;
}

void GPUTick()
{
	static int image_width2 = 0;
	//if (image_width2 == 0)
	//	image_width2 = mylog2(image_width);
	//int image_height2 = mylog2(image_height);
	
	
	unsigned char * surf;
	long x = PSXDisplay.DisplayPosition.x;
	long y = PSXDisplay.DisplayPosition.y;
	GLuint lu;
	unsigned short row,column;
	unsigned short dx=(unsigned short)PSXDisplay.DisplayEnd.x;//PreviousPSXDisplay.Range.x1;
	unsigned short dy=(unsigned short)PSXDisplay.DisplayEnd.y;//PreviousPSXDisplay.DisplayMode.y;
	long lPitch;
	
	//printf("y=%i",PSXDisplay.DisplayPosition.y);
	
	if (/*[glLock tryLock]*/ 1) {
		
		/*
		if ((image_width != PreviousPSXDisplay.Range.x1) ||
			(image_height != PreviousPSXDisplay.DisplayMode.y) ||
			((PSXDisplay.RGB24 ? 32 : 16) != image_depth)) {
		}
		
		surf = image;
		lPitch=image_width2<<(image_depth >> 4);
		*/
		if(PreviousPSXDisplay.Range.y0)                       // centering needed?
		{
			surf+=PreviousPSXDisplay.Range.y0*lPitch;
			dy-=PreviousPSXDisplay.Range.y0;
		}
		
		if(/*PSXDisplay.RGB24*/ 1) //We'll always be in 32-bit mode
		{
			unsigned char * pD;unsigned int startxy;
			
			surf+=PreviousPSXDisplay.Range.x0<<2;
			
			for(column=0;column<dy;column++)
			{
				startxy = (1024 * (column + y)) + x;
				pD = (unsigned char *)&psxVuw[startxy];
				
				row = 0;
				// make sure the reads are aligned
				while ((intptr_t)pD & 0x3) {
					*((unsigned long *)((surf)+(column*lPitch)+(row<<2))) =
					(*(pD+0)<<16)|(*(pD+1)<<8)|*(pD+2);
					
					pD+=3;
					row++;
				}
				
				for(;row<dx;row+=4)
				{
					GLuint lu1 = *((GLuint *)pD);
					GLuint lu2 = *((GLuint *)pD+1);
					GLuint lu3 = *((GLuint *)pD+2);
					GLuint *dst = ((GLuint *)((surf)+(column*lPitch)+(row<<2)));
					*(dst)=
					(((lu1>>0)&0xff)<<16)|(((lu1>>8)&0xff)<<8)|(((lu1>>16)&0xff));
					*(dst+1)=
					(((lu1>>24)&0xff)<<16)|(((lu2>>0)&0xff)<<8)|(((lu2>>8)&0xff));
					*(dst+2)=
					(((lu2>>16)&0xff)<<16)|(((lu2>>24)&0xff)<<8)|(((lu3>>0)&0xff));
					*(dst+3)=
					(((lu3>>8)&0xff)<<16)|(((lu3>>16)&0xff)<<8)|(((lu3>>24)&0xff));
					pD+=12;
				}
				
				//for(;row<dx;row+=4)
				/*while (pD&0x3) {
				 *((unsigned long *)((surf)+(column*lPitch)+(row<<2)))=
				 (*(pD+0)<<16)|(*(pD+1)<<8)|(*(pD+2)&0xff));
				 pD+=3;
				 row++;
				 }*/
			}
		}
	}
}

void ChangeWindowMode(void)
{
	
}
