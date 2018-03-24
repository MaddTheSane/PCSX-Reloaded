//
//  PCSXRHelpers.c
//  PCSXR
//
//  Created by Charles Betts on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PCSXRGameController.h"
#import "PCSXRGameCore.h"
#import "EmuThread.h"
#include "psxcommon.h"
#include "sio.h"

static BOOL sysInited = NO;

char* Pcsxr_locale_text(char* toloc){
	NSBundle *mainBundle = [NSBundle bundleForClass:[PCSXRGameCore class]];
	NSString *origString = nil, *transString = nil;
	origString = [NSString stringWithCString:toloc encoding:NSUTF8StringEncoding];
	transString = [mainBundle localizedStringForKey:origString value:nil table:nil];
	return [transString cStringUsingEncoding:NSUTF8StringEncoding];
}

int SysInit() {
	if (!sysInited) {
#ifdef EMU_LOG
#ifndef LOG_STDOUT
		emuLog = fopen("emuLog.txt","wb");
#else
		emuLog = stdout;
#endif
		setvbuf(emuLog, NULL, _IONBF, 0);
#endif
		
		if (EmuInit() != 0)
			return -1;
		
		sysInited = YES;
	}
	
	if (LoadPlugins() == -1) {
		return -1;
	}
	
	LoadMcds(Config.Mcd1, Config.Mcd2);
		
	return 0;
}

void SysReset() {
    [EmuThread resetNow];
    //EmuReset();
}

void SysPrintf(const char *fmt, ...) {
    va_list list;
    char msg[512];
	
    va_start(list, fmt);
    vsprintf(msg, fmt, list);
    va_end(list);
	
    if (Config.PsxOut) printf ("%s", msg);
#ifdef EMU_LOG
#ifndef LOG_STDOUT
    fprintf(emuLog, "%s", msg);
#endif
#endif
}

void SysMessage(const char *fmt, ...) {
	va_list list;
	
	NSString *locFmtString = NSLocalizedString([NSString stringWithCString:fmt encoding:NSUTF8StringEncoding], nil);
	
	va_start(list, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:locFmtString arguments:list];
	va_end(list);
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:msg forKey:NSLocalizedFailureReasonErrorKey];
    [NSApp presentError:[NSError errorWithDomain:@"Unknown Domain" code:-1 userInfo:userInfo]];
}

// Close mem and plugins
void SysClose() {
    EmuShutdown();
    ReleasePlugins();
		
    if (emuLog != NULL) fclose(emuLog);
	
    sysInited = NO;
}

void OnFile_Exit() {
    SysClose();
    //exit(0);
}

// Called periodically from the emu thread
void SysUpdate() {
	PAD1_keypressed();
	PAD2_keypressed();
	[emuThread handleEvents];
}

// Returns to the Gui
void SysRunGui() {
	
}

#define SHOULDNOTUSE NSLog(@"The function %s shouldn't be used under OpenEmu!", __FUNCTION__)

void *SysLoadLibrary(const char *lib) {
	SHOULDNOTUSE;
	return NULL;
}

void *SysLoadSym(void *lib, const char *sym) {
	SHOULDNOTUSE;
	return NULL;
}

const char *SysLibError() {
	SHOULDNOTUSE;
	return "not available";
}

void SysCloseLibrary(void *lib) {
	SHOULDNOTUSE;
}


