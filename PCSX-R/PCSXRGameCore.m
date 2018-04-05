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
#include "cdriso.h"
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
#import "OEPSXSystemResponderClient.h"
#import "EmuThread.h"
#include "PlugInBridges.h"
#include "cdrom.h"

@interface PCSXRGameCore()
@property BOOL wasPausedBeforeDiscEject;

@end

#pragma mark SPU calls

__weak PCSXRGameCore *_current;
unsigned long gpuDisp;
#define SAMPLERATE 44100

// SETUP SOUND
void SetupSound(void)
{
	//GET_CURRENT_OR_RETURN();
	
	//OERingBuffer *ringBuf = [current ringBufferAtIndex:0];
	//ringBuf.length = 1024 * 2;
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
	GET_CURRENT_OR_RETURN();
	
	[[current ringBufferAtIndex:0] write:pSound maxLength:lBytes];
}

@implementation PCSXRGameCore {
	NSInteger _maxDiscs;
	NSMutableArray<NSString*> *_allCueSheetFiles;
}

- (id)init
{
    self = [super init];
    if(self)
    {
		_allCueSheetFiles = [[NSMutableArray alloc] initWithCapacity:1];
		memset(&Config, 0, sizeof(Config));
		Config.UseNet = NO;
		strcpy(Config.Net, "Disabled");
		Config.Cpu = CPU_DYNAREC;
		NSFileManager *manager = [NSFileManager defaultManager];
		NSURL *supportURL = [manager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
		NSURL *url = [supportURL URLByAppendingPathComponent:@"OpenEmu/BIOS"];
		if (![url checkResourceIsReachableAndReturnError:NULL])
			[manager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:NULL];
		url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PCSXR/MemCards"];
		if (![url checkResourceIsReachableAndReturnError:NULL])
			[manager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:NULL];
		url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PCSXR/Patches"];
		if (![url checkResourceIsReachableAndReturnError:NULL])
			[manager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:NULL];
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

- (BOOL)loadFileAtPath:(NSString*) path error:(NSError *__autoreleasing *)error
{
	if([[[path pathExtension] lowercaseString] isEqualToString:@"m3u"])
	{
		NSString *parentPath = [path stringByDeletingLastPathComponent];
		NSString *m3uString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
		NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@".*\\.cue|.*\\.ccd" options:NSRegularExpressionCaseInsensitive error:nil];
		NSUInteger numberOfMatches = [regex numberOfMatchesInString:m3uString options:0 range:NSMakeRange(0, m3uString.length)];
		
		NSLog(@"Loaded m3u containing %lu cue sheets or ccd", numberOfMatches);
		
		_maxDiscs = numberOfMatches;
		
		// Keep track of cue sheets for use with SBI files
		[regex enumerateMatchesInString:m3uString options:0 range:NSMakeRange(0, m3uString.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
			NSRange range = result.range;
			NSString *match = [m3uString substringWithRange:range];
			
			if([match containsString:@".cue"]) {
				[_allCueSheetFiles addObject:[[parentPath stringByAppendingPathComponent:[m3uString substringWithRange:range]] stringByStandardizingPath]];
			}
		}];
	} else {
		[_allCueSheetFiles addObject:path];
	}

	SetIsoFile([_allCueSheetFiles.firstObject fileSystemRepresentation]);
	cdrIsoInit();
	CDR_open();
	CheckCdrom();
	CDR_shutdown();
	{
		NSFileManager *manager = [NSFileManager defaultManager];
		NSURL *supportURL = [manager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
		NSURL *url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PCSXR/MemCards"];
		NSURL *memCardURL = nil;
		int i;
		for (i = 1; i <= 2; i++) {
			memCardURL = [url URLByAppendingPathComponent:[NSString stringWithFormat:@"%s-%3.3d.mcd", CdromId, i]];
			const char* mcdFile = [memCardURL fileSystemRepresentation];
			if (![manager fileExistsAtPath:[memCardURL path]]) {
				CreateMcd((char*)mcdFile);
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
	{
		NSFileManager *manager = [NSFileManager defaultManager];
		NSURL *supportURL = [manager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
		NSURL *url = [supportURL URLByAppendingPathComponent:@"OpenEmu/BIOS"];
		if (![url checkResourceIsReachableAndReturnError:NULL])
			[manager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:NULL];
		NSMutableArray<NSString *> *biosList = [NSMutableArray arrayWithCapacity:1];
        url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PCSXR/MemCards"];
		if (![url checkResourceIsReachableAndReturnError:NULL])
            [manager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:NULL];
		url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PCSXR/Patches"];
		if (![url checkResourceIsReachableAndReturnError:NULL])
            [manager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:NULL];

		url = [supportURL URLByAppendingPathComponent:@"OpenEmu/BIOS"];
		const char *str = [[url path] fileSystemRepresentation];
		if (str != nil) strncpy(Config.BiosDir, str, MAXPATHLEN);
		url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PCSXR/Patches"];
		str = [[url path] fileSystemRepresentation];
		if (str != nil) strncpy(Config.PatchesDir, str, MAXPATHLEN);

		NSString *biosDir = [manager stringWithFileSystemRepresentation:Config.BiosDir length:strlen(Config.BiosDir)];
		NSArray *bioses = [manager contentsOfDirectoryAtPath:biosDir error:NULL];
		if (bioses) {
			NSArray<NSString*> *goodBIOS = @[@"scph5501.bin", @"scph5500.bin", @"scph5502.bin"];
			
			for (NSString *file in bioses) {
				BOOL badVal = YES;
				for (NSString *gbName in goodBIOS) {
					if ([gbName compare:file options:NSCaseInsensitiveSearch] == NSOrderedSame) {
						badVal = NO;
						break;
					}
				}
				if (badVal) {
					continue;
				}
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
	
	_current = self;
}

- (void)setPauseEmulation:(BOOL)pauseEmulation
{
	if (pauseEmulation) {
		[EmuThread pauseSafe];
	} else {
		[EmuThread resume];
	}
	
	[super setPauseEmulation:pauseEmulation];
}

- (void)stopEmulation
{
	[EmuThread stop];
	_current = nil;
	
	[super stopEmulation];
}

# pragma mark -

- (void)startEmulation
{
	[EmuThread run];
}

- (void)executeFrame
{
	//TODO: find out the proper function(s) to call here!
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

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
	GPUFreeze_t tmpNum;
	char Text[256];
	BOOL wasPaused = [EmuThread pauseSafe];
	
	tmpNum.ulFreezeVersion=1;
	GPU_freeze(2, &tmpNum);
	int ret = SaveState([fileName fileSystemRepresentation]);
	
	if (!wasPaused) {
		[EmuThread resume];
	}
	
	if (ret == 0)
		snprintf(Text, sizeof(Text), _("*PCSXR*: Saved State %d"), 1);
	else
		snprintf(Text, sizeof(Text), _("*PCSXR*: Error Saving State %d"), 1);
	GPU_displayText(Text);
	
	block(ret == 0, nil);
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{    
	BOOL defrosted = [EmuThread defrostAt:fileName];
	block(defrosted, nil);
}

- (OEIntSize)bufferSize
{
	OEIntSize size;
	//TODO: Handle PAL/SECAM sizes?
	size.width = 640;
	size.height = 480;
	return size;
}

- (OEIntSize)aspectSize
{
	OEIntSize size;
	//TODO: Handle PAL/SECAM sizes?
	size.width = 4;
	size.height = 3;
	return size;
}

- (void)setDisc:(NSUInteger)discNumber
{
	NSInteger index = discNumber - 1; // 0-based index
	self.wasPausedBeforeDiscEject = [EmuThread pauseSafe];
	/* close connection to current cd */
	if ([EmuThread active]) {
		CDR_close();
	}
	//if (UsingIso()) //ALWAYS!
	
	SetIsoFile([_allCueSheetFiles[index] fileSystemRepresentation]);
	// Open/eject needs a bit of delay, so wait 1 second until inserting new disc
	SetCdOpenCaseTime(time(NULL) + 2);
	LidInterrupt();

	
	if ([EmuThread active])
		CDR_open();
	
	if (!self.wasPausedBeforeDiscEject) {
		[EmuThread resume];
	}
}

- (NSUInteger)discCount
{
	return _maxDiscs ? _maxDiscs : 1;
}

- (BOOL)hasAlternateRenderingThread
{
	return YES;
}

- (BOOL)needsDoubleBufferedFBO
{
	return YES;
}

- (BOOL)tryToResizeVideoTo:(OEIntSize)size
{
	return GPUResize(size);
	return YES;
}

@end

void ReadConfig(void)
{
	bChangeRes=FALSE;
	bWindowMode=TRUE;
	iUseScanLines=0;
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
	iUseMask=1;
	iZBufferDepth=16;
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
	iVRamSize=64; //There should be at least 64 MiB of RAM on any modern Mac.
	iTexGarbageCollection=1;
	iBlurBuffer=1;
	iHiResTextures=1;
	iForceVSync=1;
}

int OpenPlugins(void)
{
	long ret;
	ret = CDR_open();
	if (ret < 0) { SysMessage("%s", _("Error Opening CDR Plugin")); return -1; }
	ret = SPU_open();
	if (ret < 0) { SysMessage("%s", _("Error Opening SPU Plugin")); return -1; }
	SPU_registerCallback(SPUirq);
	ret = GPU_open(&gpuDisp, "PCSXR", NULL);
	if (ret < 0) { SysMessage("%s", _("Error Opening GPU Plugin")); return -1; }
	ret = PAD1_open(&gpuDisp);
	if (ret < 0) { SysMessage("%s", _("Error Opening PAD1 Plugin")); return -1; }
	PAD1_registerVibration(GPU_visualVibration);
	PAD1_registerCursor(GPU_cursor);
	ret = PAD2_open(&gpuDisp);
	if (ret < 0) { SysMessage("%s", _("Error Opening PAD2 Plugin")); return -1; }
	PAD2_registerVibration(GPU_visualVibration);
	PAD2_registerCursor(GPU_cursor);

	return 0;
}

void ClosePlugins(void)
{
	long ret;
	ret = CDR_close();
	if (ret < 0) { SysMessage("%s", _("Error Closing CDR Plugin")); return; }
	ret = SPU_close();
	if (ret < 0) { SysMessage("%s", _("Error Closing SPU Plugin")); return; }
	ret = PAD1_close();
	if (ret < 0) { SysMessage("%s", _("Error Closing PAD1 Plugin")); return; }
	ret = PAD2_close();
	if (ret < 0) { SysMessage("%s", _("Error Closing PAD2 Plugin")); return; }
	ret = GPU_close();
	if (ret < 0) { SysMessage("%s", _("Error Closing GPU Plugin")); return; }
}
