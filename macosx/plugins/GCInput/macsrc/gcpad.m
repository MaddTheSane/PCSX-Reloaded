//
//  gcpad.m
//  GCInput
//
//  Created by C.W. Betts on 8/25/20.
//

#import <Foundation/Foundation.h>
#include "gcpad.h"


static void (*gpuVisualVibration)(uint32_t, uint32_t) = NULL;

char *PSEgetLibName(void) {
	return "GameController framework Input";
}

uint32_t PSEgetLibType(void) {
	return PSE_LT_PAD;
}

uint32_t PSEgetLibVersion(void) {
	return (0 << 16) | (9 << 8);
}

static int padDataLenght[] = {0, 2, 3, 1, 1, 3, 3, 3};
void PADsetMode(const int pad, const int mode) {
	g.PadState[pad].PadMode = mode;
    
    if (g.cfg.PadDef[pad].Type == PSE_PAD_TYPE_ANALOGPAD) {
        g.PadState[pad].PadID = mode ? 0x73 : 0x41;
    }
    else {
        g.PadState[pad].PadID = (g.cfg.PadDef[pad].Type << 4) |
                                 padDataLenght[g.cfg.PadDef[pad].Type];
    }
    
	g.PadState[pad].Vib0 = 0;
	g.PadState[pad].Vib1 = 0;
	g.PadState[pad].VibF[0] = 0;
	g.PadState[pad].VibF[1] = 0;
}

long PADinit(long flags) {
	LoadPADConfig();

	PADsetMode(0, 0);
	PADsetMode(1, 0);

	gpuVisualVibration = NULL;

	return PSE_PAD_ERR_SUCCESS;
}

long PADshutdown(void) {
	PADclose();
	return PSE_PAD_ERR_SUCCESS;
}

char *PSEgetLibName(void);
uint32_t PSEgetLibType(void);
uint32_t PSEgetLibVersion(void);
long PADinit(long flags);
long PADshutdown(void);
long PADopen(unsigned long *Disp);
long PADclose(void);
long PADquery(void);
unsigned char PADstartPoll(int pad);
unsigned char PADpoll(unsigned char value);
long PADreadPort1(PadDataS *pad);
long PADreadPort2(PadDataS *pad);
long PADkeypressed(void);
long PADconfigure(void);
void PADabout(void);
long PADtest(void);
