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
#include "stdafx_spu.h"
#define _IN_OSS
#include "externals_spu.h"
#undef BOOL
#import "PCSXRGameCore.h"
#import "PCSXRGameController.h"
#import <OERingBuffer.h>
#include <sys/time.h>
#import <OpenGL/gl.h>
#import "OEPCSXRSystemResponderClient.h"
#import "EmuThread.h"

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

@synthesize romPath;

- (id)init
{
    self = [super init];
    if(self)
    {
		
    }
    return self;
}

- (const void *)videoBuffer
{
	return PSXVideoBuffer();
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
		NSURL *url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PSX/Bios"];
		if (![url checkResourceIsReachableAndReturnError:NULL])
			[manager createDirectoryAtPath:[url path] withIntermediateDirectories:YES attributes:nil error:NULL];
		NSMutableArray *biosList = [NSMutableArray arrayWithCapacity:1];
        url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PSX/MemCards"];
		if (![url checkResourceIsReachableAndReturnError:NULL])
            [manager createDirectoryAtPath:[url path] withIntermediateDirectories:YES attributes:nil error:NULL];
		url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PSX/Patches"];
		if (![url checkResourceIsReachableAndReturnError:NULL])
            [manager createDirectoryAtPath:[url path] withIntermediateDirectories:YES attributes:nil error:NULL];

		url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PSX/Bios"];
		const char *str = [[url path] fileSystemRepresentation];
		if (str != nil) strncpy(Config.BiosDir, str, MAXPATHLEN);
		url = [supportURL URLByAppendingPathComponent:@"OpenEmu/PSX/Patches"];
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
			str = [(NSString *)[biosList objectAtIndex:0] fileSystemRepresentation];
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

- (void)didPushPCSXRButton:(OEPCSXRButton)button forPlayer:(NSUInteger)player;
{
    //controls->pad[player - 1].buttons |=  NESControlValues[button];
}

- (void)didReleasePCSXRButton:(OEPCSXRButton)button forPlayer:(NSUInteger)player;
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
