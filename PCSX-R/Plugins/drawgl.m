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

////////////////////////////////////////////////////////////////////////

void DoBufferSwap(void)                                // SWAP BUFFERS
{
	GET_CURRENT_OR_RETURN();

	[current.renderDelegate presentDoubleBufferedFBO];
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
		iUseExts = 1;
	}
	
	GET_CURRENT_OR_RETURN(0);

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
	return (unsigned long)current;
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
	GET_CURRENT_OR_RETURN();

	[current.renderDelegate willRenderFrameOnAlternateThread];
}

void SendContextBack(void)
{
	GET_CURRENT_OR_RETURN();

	[current.renderDelegate didRenderFrameOnAlternateThread];
}

void SetVSync(GLint myValue)
{
	GET_CURRENT_OR_RETURN();

	current.renderDelegate.enableVSync = myValue == 1;
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

/** try to reset the GPU without discarding textures, etc.
 when a resize takes place, all hell breaks loose, so
 this is necessarily ugly.
 */
static void cureAllIlls(void)
{
	rRatioRect.left   = rRatioRect.top=0;
	rRatioRect.right  = iResX;
	rRatioRect.bottom = iResY;

	glFlush();
	glFinish();
	
	glViewport(rRatioRect.left,                           // init viewport by ratio rect
			   iResY-(rRatioRect.top+rRatioRect.bottom),
			   rRatioRect.right,
			   rRatioRect.bottom);
	
	
	glScissor(0, 0, iResX, iResY);                        // init clipping (fullscreen)
	glEnable(GL_SCISSOR_TEST);
	glMatrixMode(GL_PROJECTION);                          // init projection with psx resolution
	glLoadIdentity();
	glOrtho(0,PSXDisplay.DisplayMode.x,
			PSXDisplay.DisplayMode.y, 0, -1, 1);
	
	CreateScanLines();
	// if(bKeepRatio) SetAspectRatio();                      // set ratio
	glFlush();
	glFinish();

}

bool GPUResize(OEIntSize size)
{
	GET_CURRENT_OR_RETURN(false);

	[current.renderDelegate willRenderFrameOnAlternateThread];

	iResX = size.width;
	iResY = size.height;
	
	cureAllIlls();
	
	glViewport(0.0, 0.0, size.width, size.height);
	
	glClearColor (1.0, 0.5, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);

	[current.renderDelegate didRenderFrameOnAlternateThread];

	
	return true;
}

void ChangeWindowMode(void)
{
	
}
