/*
 Copyright (c) 2009, OpenEmu Team
 
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#include <OpenGL/gl.h>
#include "psxcommon.h"
#include "plugins.h"
#include "misc.h"
#include "drawgl.h"
//#include "stdafx_spu.h"
#define _IN_OSS
#include "dfsound/externals.h"
#include "peopsxgl/externals.h"
#undef BOOL
#import "PCSXRGameCore.h"
#import "PCSXRGameCore+Input.h"
#import <OpenEmuBase/OERingBuffer.h>
#include <sys/time.h>
#import <OpenGL/gl.h>
#import "OEPSXSystemResponderClient.h"
#import "EmuThread.h"
#include "PlugInBridges.h"

@interface PCSXRGameCore() <OEPSXSystemResponderClient>

@end

#pragma mark SPU calls

// SETUP SOUND
void SetupSound(void)
{
	
}

// REMOVE SOUND
void RemoveSound(void)
{
	
}

// GET BYTES BUFFERED
unsigned long SoundGetBytesBuffered(void)
{
	return 0;
}

// FEED SOUND DATA
void SoundFeedStreamData(unsigned char* pSound,long lBytes)
{
	
}


#define SAMPLERATE 44100

@implementation PCSXRGameCore

- (id)init
{
    self = [super init];
    if(self)
    {
		
    }
    return self;
}

- (GLenum)pixelFormat
{
    return GL_BGRA;
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_INT_8_8_8_8_REV;
}

- (GLenum)internalPixelFormat
{
    return GL_RGBA;
}

- (BOOL)loadFileAtPath:(NSString*) path
{
	SetIsoFile([path fileSystemRepresentation]);
	//FIXME: find out CD-ROM ID before executing [EmuThread run].
	[EmuThread run];
	{
		NSFileManager *manager = [NSFileManager defaultManager];
		NSURL *supportURL = [manager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
		NSURL *url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PSX/MemCards"];
		NSURL *memCardURL = nil;
		int i;
		for (i = 1; i > 2; i++) {
			memCardURL = [url URLByAppendingPathComponent:[NSString stringWithFormat:@"%s-%3.3d.mcd", CdromId, i]];
			const char* mcdFile = [[memCardURL path] fileSystemRepresentation];
			if (![manager fileExistsAtPath:[memCardURL path]]) {
				CreateMcd(mcdFile);
			}
			if (i == 1) {
				strlcpy(Config.Mcd1, mcdFile, MAXPATHLEN);
			} else {
				strlcpy(Config.Mcd2, mcdFile, MAXPATHLEN);
			}
		}
		LoadMcds(Config.Mcd1, Config.Mcd2);
	}
	return YES;
}

- (void)setupEmulation
{
	DLog(@"Setup");
	//PCSXR Core
	memset(&Config, 0, sizeof(Config));
    Config.UseNet = NO;
	Config.Cpu = CPU_DYNAREC; //We don't have to worry about misaligned stack error on x86_64
	{
		NSFileManager *manager = [NSFileManager defaultManager];
		NSURL *supportURL = [manager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
		NSURL *url = [supportURL URLByAppendingPathComponent:@"OpenEmu/BIOS"];
		if (![url checkResourceIsReachableAndReturnError:NULL])
			[manager createDirectoryAtPath:[url path] withIntermediateDirectories:YES attributes:nil error:NULL];
		NSMutableArray<NSString *> *biosList = [NSMutableArray arrayWithCapacity:1];
        url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PCSXR/MemCards"];
		if (![url checkResourceIsReachableAndReturnError:NULL])
            [manager createDirectoryAtPath:[url path] withIntermediateDirectories:YES attributes:nil error:NULL];
		url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PCSXR/Patches"];
		if (![url checkResourceIsReachableAndReturnError:NULL])
            [manager createDirectoryAtPath:[url path] withIntermediateDirectories:YES attributes:nil error:NULL];

		url = [supportURL URLByAppendingPathComponent:@"OpenEmu/BIOS"];
		const char *str = [[url path] fileSystemRepresentation];
		if (str != nil) strncpy(Config.BiosDir, str, MAXPATHLEN);
		url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PCSXR/Patches"];
		str = [[url path] fileSystemRepresentation];
		if (str != nil) strncpy(Config.PatchesDir, str, MAXPATHLEN);

		NSString *biosDir = [manager stringWithFileSystemRepresentation:Config.BiosDir length:strlen(Config.BiosDir)];
		NSArray *bioses = [manager contentsOfDirectoryAtPath:biosDir error:NULL];
		if (bioses) {
			NSUInteger i;
			for (i = 0; i < [bioses count]; i++) {
				NSString *file = [bioses objectAtIndex:i];
				NSDictionary *attrib = [manager attributesOfItemAtPath:[[biosDir stringByAppendingPathComponent:file] stringByResolvingSymlinksInPath] error:NULL];
				
				if ([[attrib fileType] isEqualToString:NSFileTypeRegular]) {
					unsigned long long size = [attrib fileSize];
					if (([attrib fileSize] % (256 * 1024)) == 0 && size > 0) {
						[biosList addObject:file];
					}
				}
			}
		}
		
		if (([biosList count] > 0)) {
			str = [[biosList objectAtIndex:0] fileSystemRepresentation];
			if (str != nil) strncpy(Config.Bios, str, MAXPATHLEN);
			else strcpy(Config.Bios, "HLE");
		} else {
			Config.HLE = YES;
			strcpy(Config.Bios, "HLE");
		}
	}
	
	Config.Xa = YES;
	Config.Mdec = YES;
	Config.Cdda = YES;
	Config.PsxAuto = YES;
	Config.PsxType = PSX_TYPE_NTSC; //This will probably be changed later in execution.

	//PCSXR GPU
	setGPUDefaults();
	
	//PCSXR SPU
	iVolume = 5; //We'll have OpenEmu manage the volume.
	iXAPitch = 0;
	iSPUIRQWait = 1;
	iUseTimer = 2;
	iUseReverb = 2;
	iUseInterpolation = 2;
	iDisStereo = 0;
	iFreqResponse = 0;

	
}

- (void)stopEmulation
{
	[EmuThread stop];
}

# pragma mark -

- (void)executeFrame
{
	//TODO: find out the proper function(s) to call here!
	GPUTick();
}

# pragma mark -

- (void)resetEmulation
{
	[EmuThread reset];
}

- (void)dealloc
{

}

- (OEGameCoreRendering)gameCoreRendering
{
	return OEGameCoreRenderingOpenGL2Video;
}

- (oneway void)didMovePSXJoystickDirection:(OEPSXButton)button withValue:(CGFloat)value forPlayer:(NSUInteger)player
{
	
}

- (oneway void)didPushPSXButton:(OEPSXButton)button forPlayer:(NSUInteger)player;
{
    //controls->pad[player - 1].buttons |=  NESControlValues[button];
}

- (oneway void)didReleasePSXButton:(OEPSXButton)button forPlayer:(NSUInteger)player;
{
    //controls->pad[player - 1].buttons &= ~NESControlValues[button];
}

- (double)audioSampleRate
{
    return SAMPLERATE;
}

- (NSUInteger)channelCount
{
    return 2;
}

- (NSTimeInterval)frameInterval
{
	if (Config.PsxType == PSX_TYPE_NTSC) {
		return 60;
	} else {
		return 50;
	}
}

- (BOOL)saveStateToFileAtPath:(NSString *)fileName
{
	[EmuThread freezeAt:fileName which:1];
	
    return YES;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName
{    
	return [EmuThread defrostAt:fileName];
}

- (OEIntSize)bufferSize
{
	OEIntSize size;
	//TODO: Handle PAL/SECAM sizes?
	size.width = 640;
	size.height = 480;
	return size;
}

@end

void ReadConfig(void)
{
	iVolume=2;
	iXAPitch=0;
	iSPUIRQWait=1;
	iUseTimer=2;
	iUseReverb=2;
	iUseInterpolation=2;
	iDisStereo=0;
	iFreqResponse=0;
	
	iResX=640;
	iResY=480;
	iColDepth=16;
	bChangeRes=FALSE;
	bWindowMode=TRUE;
	iUseScanLines=0;
	//bFullScreen=FALSE;
	bFullVRam=FALSE;
	iFilterType=0;
	bAdvancedBlend=FALSE;
	bDrawDither=FALSE;
	bUseLines=FALSE;
	bUseFrameLimit=TRUE;
	bUseFrameSkip=FALSE;
	iFrameLimit=2;
	fFrameRate=200.0f;
	iOffscreenDrawing=2;
	bOpaquePass=TRUE;
	bUseAntiAlias=FALSE;
	iTexQuality=0;
	iUseMask=0;
	iZBufferDepth=0;
	bUseFastMdec=TRUE;
	dwCfgFixes=0;
	bUseFixes=FALSE;
	iFrameTexType=1;
	iFrameReadType=0;
	bUse15bitMdec=FALSE;
	iShowFPS=0;
	bGteAccuracy=0;
	bKeepRatio=FALSE;
	bForceRatio43=FALSE;
	iScanBlend=0;
	iVRamSize=0;
	iTexGarbageCollection=1;
	iBlurBuffer=0;
	iHiResTextures=0;
	iForceVSync=-1;
}

int OpenPlugins(void)
{
	PAD1_configure = PADConfigure;
	PAD1_about = PADAbout;
	PAD1_init = PADInit;
	PAD1_shutdown = PADShutdown;
	PAD1_test = PADTest;
	PAD1_open = PADOpen;
	PAD1_close = PADClose;
	PAD1_query = PADQuery;
	PAD1_readPort1 = PADReadPort1;
	PAD1_keypressed = PADKeyPressed;
	PAD1_startPoll = PADStartPoll;
	PAD1_poll = PADPoll;
	PAD1_setSensitive = NULL;
	PAD1_registerVibration = NULL;
	PAD1_registerCursor = NULL;
	
	PAD2_configure = PADConfigure;
	PAD2_about = PADAbout;
	PAD2_init = PADInit;
	PAD2_shutdown = PADShutdown;
	PAD2_test = PADTest;
	PAD2_open = PADOpen;
	PAD2_close = PADClose;
	PAD2_query = PADQuery;
	PAD2_readPort2 = PADReadPort2;
	PAD2_keypressed = PADKeyPressed;
	PAD2_startPoll = PADStartPoll;
	PAD2_poll = PADPoll;
	PAD2_setSensitive = NULL;
	PAD2_registerVibration = NULL;
	PAD2_registerCursor = NULL;

	GPU_updateLace = GPUUpdateLace_bridge;
	GPU_init = GPUInit_bridge;
	GPU_shutdown = GPUShutdown_bridge;
	GPU_configure = GPUConfigure_bridge;
	GPU_test = GPUTest_bridge;
	GPU_about = GPUAbout_bridge;
	GPU_open = GPUOpen_bridge;
	GPU_close = GPUClose_bridge;
	GPU_readStatus = GPUReadStatus_bridge;
	GPU_readData = GPUReadData_bridge;
	GPU_readDataMem = GPUReadDataMem_bridge;
	GPU_writeStatus = GPUWriteStatus_bridge;
	GPU_writeData = GPUWriteData_bridge;
	GPU_writeDataMem = GPUWriteDataMem_bridge;
	GPU_dmaChain = GPUDmaChain_bridge;
	GPU_keypressed = GPUKeypressed_bridge;
	GPU_displayText = NULL;
	GPU_makeSnapshot = GPUMakeSnapshot_bridge;
	GPU_freeze = (void*)GPUFreeze_bridge;
	GPU_getScreenPic = GPUGetScreenPic_bridge;
	GPU_showScreenPic = GPUShowScreenPic_bridge;
	GPU_clearDynarec = NULL;
	GPU_hSync = GPUHSync_bridge;
	GPU_vBlank = GPUVBlank_bridge;
	GPU_visualVibration = GPUVisualVibration_bridge;
	GPU_cursor = GPUCursor_bridge;
	GPU_addVertex = GPUAddVertex_bridge;
	GPU_setSpeed = GPUSetSpeed_bridge;
	
	CDR_init = CDRInit_bridge;
	CDR_shutdown = CDRShutdown_bridge;
	CDR_open = CDROpen_bridge;
	CDR_close = CDRClose_bridge;
	CDR_test = CDRTest_bridge;
	CDR_getTN = CDRGetTN_bridge;
	CDR_getTD = CDRGetTD_bridge;
	CDR_readTrack = CDRReadTrack_bridge;
	CDR_getBuffer = CDRGetBuffer_bridge;
	CDR_play = CDRPlay_bridge;
	CDR_stop = CDRStop_bridge;
	CDR_getStatus = CDRGetStatus_bridge;
	CDR_getDriveLetter = NULL;
	CDR_getBufferSub = CDRGetBufferSub_bridge;
	CDR_configure = CDRConfigure_bridge;
	CDR_about = CDRAbout_bridge;
	CDR_setfilename = NULL;
	CDR_readCDDA = CDRReadCDDA_bridge;
	CDR_getTE = CDRGetTE_bridge;
	
	SPU_configure = SPUConfigure_bridge;
	SPU_about = SPUAbout_bridge;
	SPU_init = SPUInit_bridge;
	SPU_shutdown = SPUShutdown_bridge;
	SPU_test = SPUTest_bridge;
	SPU_open = SPUOpen_bridge;
	SPU_close = SPUClose_bridge;
	SPU_playSample = NULL;
	SPU_writeRegister = SPUWriteRegister_bridge;
	SPU_readRegister = SPUReadRegister_bridge;
	SPU_writeDMA = SPUWriteDMA_bridge;
	SPU_readDMA = SPUReadDMA_bridge;
	SPU_writeDMAMem = SPUWriteDMAMem_bridge;
	SPU_readDMAMem = SPUReadDMAMem_bridge;
	SPU_playADPCMchannel = (void*)SPUPlayADPCMchannel_bridge;
	SPU_freeze = (void*)SPUFreeze_bridge;
	SPU_registerCallback = SPURegisterCallback_bridge;
	SPU_async = SPUAsync_bridge;
	SPU_playCDDAchannel = SPUPlayCDDAchannel_bridge;
	
	return 0;
}

void ClosePlugins(void)
{
	
}
