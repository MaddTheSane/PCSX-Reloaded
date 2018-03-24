// Copyright (c) 2018, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "PCSXRGameCore+Input.h"
#include "psemu_plugin_defs.h"

// code taken from dfinput and repurposed
static uint8_t stdpar[2][8] = {
	{0xFF, 0x5A, 0xFF, 0xFF, 0x80, 0x80, 0x80, 0x80},
	{0xFF, 0x5A, 0xFF, 0xFF, 0x80, 0x80, 0x80, 0x80}
};

static uint8_t unk46[2][8] = {
	{0xFF, 0x5A, 0x00, 0x00, 0x01, 0x02, 0x00, 0x0A},
	{0xFF, 0x5A, 0x00, 0x00, 0x01, 0x02, 0x00, 0x0A}
};

static uint8_t unk47[2][8] = {
	{0xFF, 0x5A, 0x00, 0x00, 0x02, 0x00, 0x01, 0x00},
	{0xFF, 0x5A, 0x00, 0x00, 0x02, 0x00, 0x01, 0x00}
};

static uint8_t unk4c[2][8] = {
	{0xFF, 0x5A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
	{0xFF, 0x5A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}
};

static uint8_t unk4d[2][8] = {
	{0xFF, 0x5A, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF},
	{0xFF, 0x5A, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF}
};

static uint8_t stdcfg[2][8]   = {
	{0xFF, 0x5A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
	{0xFF, 0x5A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}
};

static uint8_t stdmode[2][8]  = {
	{0xFF, 0x5A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
	{0xFF, 0x5A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}
};

static uint8_t stdmodel[2][8] = {
	{0xFF,
		0x5A,
		0x01, // 03 - dualshock2, 01 - dualshock
		0x02, // number of modes
		0x01, // current mode: 01 - analog, 00 - digital
		0x02,
		0x01,
		0x00},
	{0xFF,
		0x5A,
		0x01, // 03 - dualshock2, 01 - dualshock
		0x02, // number of modes
		0x01, // current mode: 01 - analog, 00 - digital
		0x02,
		0x01,
		0x00}
};

typedef void *Display;
#define ThreadID ThreadID_MACOSX

enum {
	DKEY_SELECT = 0,
	DKEY_L3,
	DKEY_R3,
	DKEY_START,
	DKEY_UP,
	DKEY_RIGHT,
	DKEY_DOWN,
	DKEY_LEFT,
	DKEY_L2,
	DKEY_R2,
	DKEY_L1,
	DKEY_R1,
	DKEY_TRIANGLE,
	DKEY_CIRCLE,
	DKEY_CROSS,
	DKEY_SQUARE,
	DKEY_ANALOG,
	
	DKEY_TOTAL
};

enum {
	EMU_INCREMENTSTATE=0,
	EMU_FASTFORWARDS,
	EMU_LOADSTATE,
	EMU_SAVESTATE,
	EMU_SCREENSHOT,
	EMU_ESCAPE,
	EMU_REWIND,
	EMU_ALTSPEED1,
	EMU_ALTSPEED2,
	
	EMU_TOTAL
};

enum {
	ANALOG_LEFT = 0,
	ANALOG_RIGHT,
	
	ANALOG_TOTAL
};

typedef NS_ENUM(uint8_t, JoyEvType) {
	NONE = 0,
	AXIS,
	HAT,
	BUTTON
};

typedef struct tagKeyDef {
	JoyEvType		joyEvType;
	union {
		int16_t		d;
		int16_t		Axis;   // positive=axis+, negative=axis-, abs(Axis)-1=axis index
		uint16_t	Hat;	// 8-bit for hat number, 8-bit for direction
		uint16_t	Button; // button number
	} J;
	uint16_t		Key;
	uint8_t			ReleaseEventPending;
} KEYDEF;

enum { ANALOG_XP = 0, ANALOG_XM, ANALOG_YP, ANALOG_YM };

typedef struct tagPadDef {
	int8_t			DevNum;
	uint16_t		Type;
	uint8_t			VisualVibration;
	KEYDEF			KeyDef[DKEY_TOTAL];
	KEYDEF			AnalogDef[ANALOG_TOTAL][4];
} PADDEF;

typedef struct tagEmuDef {
	uint16_t	EmuKeyEvent;
	KEYDEF		Mapping;
} EMUDEF;

typedef struct tagEmuDef2{
	EMUDEF		EmuDef[EMU_TOTAL];
	int8_t		DevNum;
} EMUDEF2;

typedef struct tagConfig {
	uint8_t			Threaded;
	uint8_t			HideCursor;
	uint8_t			PreventScrSaver;
	PADDEF			PadDef[2];
	EMUDEF2			E;
} CONFIG;

typedef struct tagPadState {
	uint8_t				PadMode;
	uint8_t				PadID;
	uint8_t				PadModeKey;
	volatile uint8_t	PadModeSwitch;
	volatile uint16_t	KeyStatus;
	volatile uint16_t	JoyKeyStatus;
	volatile uint8_t	AnalogStatus[ANALOG_TOTAL][2]; // 0-255 where 127 is center position
	volatile uint8_t	AnalogKeyStatus[ANALOG_TOTAL][4];
	volatile int8_t		MouseAxis[2][2];
	uint8_t				Vib0, Vib1;
	volatile uint8_t	VibF[2];
} PADSTATE;

typedef struct tagGlobalData {
	CONFIG				cfg;
	
	uint8_t				Opened;
	Display				*Disp;
	
	PADSTATE			PadState[2];
	volatile long		KeyLeftOver;
} GLOBALDATA;

extern GLOBALDATA		g;

enum {
	CMD_READ_DATA_AND_VIBRATE = 0x42,
	CMD_CONFIG_MODE = 0x43,
	CMD_SET_MODE_AND_LOCK = 0x44,
	CMD_QUERY_MODEL_AND_MODE = 0x45,
	CMD_QUERY_ACT = 0x46, // ??
	CMD_QUERY_COMB = 0x47, // ??
	CMD_QUERY_MODE = 0x4C, // QUERY_MODE ??
	CMD_VIBRATION_TOGGLE = 0x4D
};

// end dfinput code.

@implementation PCSXRGameCore (Input)

@end

long PADTest(void)
{
	return PSE_PAD_ERR_SUCCESS;
}

void PADAbout(void)
{
	
}

long PADConfigure(void)
{
	return PSE_PAD_ERR_SUCCESS;
}

long PADQuery(void)
{
	return PSE_PAD_USE_PORT1 | PSE_PAD_USE_PORT2;
}

long PADClose(void)
{
	return PSE_PAD_ERR_SUCCESS;
}

long PADOpen(unsigned long *Disp)
{
	return PSE_PAD_ERR_SUCCESS;
}

long PADShutdown(void)
{
	return PSE_PAD_ERR_SUCCESS;
}

long PADInit(long flags)
{
	return PSE_PAD_ERR_SUCCESS;
}

void PADSetMode(const int pad, const int mode)
{
	
}

char *PADGetLibName(void) {
	return "Gamepad/Keyboard/Mouse Input";
}

uint32_t PADGetLibType(void) {
	return PSE_LT_PAD;
}

uint32_t PADGetLibVersion(void) {
	return (1 << 16) | (2 << 8);
}

static long PADreadPort(int num, PadDataS *pad)
{
	return 0;
}

long PADReadPort1(PadDataS *pad)
{
	return PADreadPort(0, pad);
}

long PADReadPort2(PadDataS *pad)
{
	return PADreadPort(2, pad);
}

long PADKeyPressed(void)
{
	return 0;
}

unsigned char PADStartPoll(int pad)
{
	//CurPad = pad - 1;
	//CurByte = 0;
	
	return 0xFF;
}

unsigned char PADPoll(unsigned char value)
{
	return 0;
}
