//
//  gcpad.m
//  GCInput
//
//  Created by C.W. Betts on 8/25/20.
//

#import <Foundation/Foundation.h>
#import "GCInput-Swift.h"
#import "gcpad.h"


void (*gpuVisualVibration)(uint32_t, uint32_t) = NULL;

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
	[GlobalData setUp];
	//LoadPADConfig();

	PADsetMode(0, 0);
	PADsetMode(1, 0);

	gpuVisualVibration = NULL;

	return PSE_PAD_ERR_SUCCESS;
}

long PADshutdown(void) {
	PADclose();
	return PSE_PAD_ERR_SUCCESS;
}


long	PADquery(void)
{
	return PSE_PAD_USE_PORT1 | PSE_PAD_USE_PORT2;
}

unsigned char PADstartPoll(int pad)
{
	//CurPad = pad - 1;
	//CurByte = 0;

	return 0xFF;

}

unsigned char PADpoll(unsigned char value)
{
	return 0;
}

static long PADreadPort(int num, PadDataS *pad) {
	return [[GlobalData globalDataInstance] readPadPortWithNum:num pad:pad];
}

long PADreadPort1(PadDataS *pad) {
	return PADreadPort(0, pad);
}

long PADreadPort2(PadDataS *pad) {
	return PADreadPort(1, pad);
}

void PADregisterVibration(void (*callback)(uint32_t, uint32_t)) {
	gpuVisualVibration = callback;
}

long PADkeypressed(void)
{
	return 0;
}

long PADclose(void) {
	if (g.Opened) {
		[GlobalData shutDown];
	}
	g.Opened = 0;

	return PSE_PAD_ERR_SUCCESS;
}

long PADopen(unsigned long *Disp) {
	g.Disp = (Display *)*Disp;

	if (!g.Opened) {
		
	}

	g.Opened = 1;

	return PSE_PAD_ERR_SUCCESS;
}

long PADtest(void) {
	return PSE_PAD_ERR_SUCCESS;
}
