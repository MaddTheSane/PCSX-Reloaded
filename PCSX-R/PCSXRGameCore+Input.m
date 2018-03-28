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
	BUTTON,
	EMUBUTTON
};

typedef struct tagKeyDef {
	JoyEvType		joyEvType;
	union {
		int16_t		d;
		int16_t		Axis;   // positive=axis+, negative=axis-, abs(Axis)-1=axis index
		uint16_t	Hat;	// 8-bit for hat number, 8-bit for direction
		uint16_t	Button; // button number
		OEPSXButton	EmuButton;
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
	BOOL			Threaded;
	BOOL			HideCursor;
	BOOL			PreventScrSaver;
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

static GLOBALDATA		g;

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
void PADSetMode(const int pad, const int mode);
int JoyHapticRumble(int pad, uint32_t low, uint32_t high);

static void bdown(int pad, int bit)
{
	if (bit < 16) {
		g.PadState[pad].JoyKeyStatus &= ~(1 << bit);
	} else if (bit == DKEY_ANALOG) {
		if (++g.PadState[pad].PadModeKey == 10) {
			g.PadState[pad].PadModeSwitch = 1;
		} else if (g.PadState[pad].PadModeKey > 10) {
			g.PadState[pad].PadModeKey = 11;
		}
	}
}

static void bup(int pad, int bit)
{
	if (bit < 16) {
		g.PadState[pad].JoyKeyStatus |= (1 << bit);
	} else if(bit == DKEY_ANALOG) {
		g.PadState[pad].PadModeKey = 0;
	}
}

static void keydown(int pad, int bit)
{
	if(bit < 16)
		g.PadState[pad].KeyStatus &= ~(1 << bit);
	else if(bit == DKEY_ANALOG)
		g.PadState[pad].PadModeSwitch = 1;
}

static void keyup(int pad, int bit)
{
	if(bit < 16)
		g.PadState[pad].KeyStatus |= (1 << bit);
}

// end dfinput code.

enum {
	DKEY_ANALOGSTICK = -1,
	DKEY_INVALID = -2
};

static int OEPSXButtonToPCSXButton(OEPSXButton toConv)
{
	switch (toConv) {
			//Get the analog entries out of the way first
		case OEPSXLeftAnalogUp:
		case OEPSXLeftAnalogDown:
		case OEPSXLeftAnalogLeft:
		case OEPSXLeftAnalogRight:
		case OEPSXRightAnalogUp:
		case OEPSXRightAnalogDown:
		case OEPSXRightAnalogLeft:
		case OEPSXRightAnalogRight:
			return DKEY_ANALOGSTICK;
			break;
			
		case OEPSXButtonUp:
			return DKEY_UP;
			break;
			
		case OEPSXButtonDown:
			return DKEY_DOWN;
			break;
			
		case OEPSXButtonLeft:
			return DKEY_LEFT;
			break;
			
		case OEPSXButtonRight:
			return DKEY_RIGHT;
			break;
			
		case OEPSXButtonTriangle:
			return DKEY_TRIANGLE;
			break;
			
		case OEPSXButtonCircle:
			return DKEY_CIRCLE;
			break;
			
		case OEPSXButtonCross:
			return DKEY_CROSS;
			break;
			
		case OEPSXButtonSquare:
			return DKEY_SQUARE;
			break;
			
		case OEPSXButtonL1:
			return DKEY_L1;
			break;
			
		case OEPSXButtonL2:
			return DKEY_L2;
			break;
			
		case OEPSXButtonL3:
			return DKEY_L3;
			break;
			
		case OEPSXButtonR1:
			return DKEY_R1;
			break;
			
		case OEPSXButtonR2:
			return DKEY_R2;
			break;
			
		case OEPSXButtonR3:
			return DKEY_R3;
			break;
			
		case OEPSXButtonStart:
			return DKEY_START;
			break;
			
		case OEPSXButtonSelect:
			return DKEY_SELECT;
			break;
			
		case OEPSXButtonAnalogMode:
			return DKEY_ANALOG;
			break;

		default:
			return DKEY_INVALID;
			break;
	}
}

@implementation PCSXRGameCore (Input)

- (oneway void)didMovePSXJoystickDirection:(OEPSXButton)button withValue:(CGFloat)value forPlayer:(NSUInteger)player
{
	//TODO: implement
	value *= 32767; // de-normalize

	//	val += 32640;
	//	val /= 256;

	switch (button) {
		case OEPSXLeftAnalogUp:
			
			break;
			
		case OEPSXLeftAnalogDown:
			
			break;
			
		case OEPSXLeftAnalogLeft:
			
			break;
			
		case OEPSXLeftAnalogRight:
			
			break;
			
		case OEPSXRightAnalogUp:
			
			break;
			
		case OEPSXRightAnalogDown:
			
			break;
			
		case OEPSXRightAnalogLeft:
			
			break;
			
		case OEPSXRightAnalogRight:
			
			break;
			
		default:
			break;
	}
}

- (oneway void)didPushPSXButton:(OEPSXButton)button forPlayer:(NSUInteger)player;
{
	int PCSXbutton = OEPSXButtonToPCSXButton(button);
	NSAssert(PCSXbutton > -1, @"Was returned a negative value of %i for button %i", PCSXbutton, button);
	bdown((int)player-1, PCSXbutton);
}

- (oneway void)didReleasePSXButton:(OEPSXButton)button forPlayer:(NSUInteger)player;
{
	int PCSXbutton = OEPSXButtonToPCSXButton(button);
	NSAssert(PCSXbutton > -1, @"Was returned a negative value of %i for button %i", PCSXbutton, button);
	bup((int)player-1, PCSXbutton);
}

@end

// code taken from dfinput and repurposed
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
	if (g.Opened) {

	}
	g.Opened = 0;

	return PSE_PAD_ERR_SUCCESS;
}

long PADOpen(unsigned long *Disp)
{
	g.Disp = (Display *)*Disp;
	if (!g.Opened) {
		g.PadState[0].JoyKeyStatus = 0xFFFF;
		g.PadState[1].JoyKeyStatus = 0xFFFF;

		/* InitAnalog() */
		g.PadState[0].AnalogStatus[ANALOG_LEFT][0] = 127;
		g.PadState[0].AnalogStatus[ANALOG_LEFT][1] = 127;
		g.PadState[0].AnalogStatus[ANALOG_RIGHT][0] = 127;
		g.PadState[0].AnalogStatus[ANALOG_RIGHT][1] = 127;
		g.PadState[1].AnalogStatus[ANALOG_LEFT][0] = 127;
		g.PadState[1].AnalogStatus[ANALOG_LEFT][1] = 127;
		g.PadState[1].AnalogStatus[ANALOG_RIGHT][0] = 127;
		g.PadState[1].AnalogStatus[ANALOG_RIGHT][1] = 127;
		
		memset((void *)g.PadState[0].AnalogKeyStatus, 0, sizeof(g.PadState[0].AnalogKeyStatus));
		memset((void *)g.PadState[1].AnalogKeyStatus, 0, sizeof(g.PadState[1].AnalogKeyStatus));

		/* InitKeyboard() */
		g.PadState[0].KeyStatus = 0xFFFF;
		g.PadState[1].KeyStatus = 0xFFFF;

		g.KeyLeftOver = 0;
	}
	
	g.Opened = 1;

	return PSE_PAD_ERR_SUCCESS;
}

long PADShutdown(void)
{
	return PSE_PAD_ERR_SUCCESS;
}

long PADInit(long flags)
{
	g.cfg.PadDef[0].Type = PSE_PAD_TYPE_ANALOGPAD;
	g.cfg.PadDef[1].Type = PSE_PAD_TYPE_ANALOGPAD;
	PADSetMode(0, 0);
	PADSetMode(1, 0);
	g.PadState[0].JoyKeyStatus = 0xFFFF;
	g.PadState[1].JoyKeyStatus = 0xFFFF;
	return PSE_PAD_ERR_SUCCESS;
}

static int padDataLenght[] = {0, 2, 3, 1, 1, 3, 3, 3};
void PADSetMode(const int pad, const int mode)
{
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

char *PADGetLibName(void) {
	return "Gamepad/Keyboard/Mouse Input";
}

uint32_t PADGetLibType(void) {
	return PSE_LT_PAD;
}

uint32_t PADGetLibVersion(void) {
	return (1 << 16) | (2 << 8);
}

static void UpdateInput(void) {
	int pad;
	// we are setting the variables directly, no need to spin a seperate thread to poll.
	//if (!g.cfg.Threaded) CheckJoy();
	for(pad = 0; pad < 2; pad++) {
		if(g.PadState[pad].PadModeSwitch) {
			g.PadState[pad].PadModeSwitch = 0;
			PADSetMode(pad, 1 - g.PadState[pad].PadMode);
		}
	}
	//CheckKeyboard();
}

static long PADreadPort(int num, PadDataS *pad)
{
	UpdateInput();
	
	pad->buttonStatus = (g.PadState[num].KeyStatus & g.PadState[num].JoyKeyStatus);
	
	// ePSXe different from pcsxr, swap bytes
	pad->buttonStatus = (pad->buttonStatus >> 8) | (pad->buttonStatus << 8);
	
	switch (g.cfg.PadDef[num].Type) {
		case PSE_PAD_TYPE_ANALOGPAD: // Analog Controller SCPH-1150
			pad->controllerType = PSE_PAD_TYPE_ANALOGPAD;
			pad->rightJoyX = g.PadState[num].AnalogStatus[ANALOG_RIGHT][0];
			pad->rightJoyY = g.PadState[num].AnalogStatus[ANALOG_RIGHT][1];
			pad->leftJoyX = g.PadState[num].AnalogStatus[ANALOG_LEFT][0];
			pad->leftJoyY = g.PadState[num].AnalogStatus[ANALOG_LEFT][1];
			break;
			
		case PSE_PAD_TYPE_STANDARD: // Standard Pad SCPH-1080, SCPH-1150
		default:
			pad->controllerType = PSE_PAD_TYPE_STANDARD;
			break;
	}
	
	return PSE_PAD_ERR_SUCCESS;
}

long PADReadPort1(PadDataS *pad)
{
	return PADreadPort(0, pad);
}

long PADReadPort2(PadDataS *pad)
{
	return PADreadPort(1, pad);
}

long PADKeyPressed(void)
{
	long s;
	
	static int frame = 0;
	if (!frame) {
		UpdateInput();
	}
	frame ^= 1;
	
	s = g.KeyLeftOver;
	g.KeyLeftOver = 0;
	
	return s;
}

static uint8_t CurPad = 0, CurByte = 0, CurCmd = 0, CmdLen = 0;

unsigned char PADStartPoll(int pad)
{
	CurPad = pad - 1;
	CurByte = 0;
	
	return 0xFF;
}

unsigned char PADPoll(unsigned char value)
{
	static uint8_t		*buf = NULL;
	uint16_t			n;
	
	if (CurByte == 0) {
		CurByte++;
		
		// Don't enable Analog/Vibration for a standard pad
		if (g.cfg.PadDef[CurPad].Type != PSE_PAD_TYPE_ANALOGPAD) {
			CurCmd = CMD_READ_DATA_AND_VIBRATE;
		} else {
			CurCmd = value;
		}
		
		switch (CurCmd) {
			case CMD_CONFIG_MODE:
				CmdLen = 8;
				buf = stdcfg[CurPad];
				if (stdcfg[CurPad][3] == 0xFF) return 0xF3;
				else return g.PadState[CurPad].PadID;
				
			case CMD_SET_MODE_AND_LOCK:
				CmdLen = 8;
				buf = stdmode[CurPad];
				return 0xF3;
				
			case CMD_QUERY_MODEL_AND_MODE:
				CmdLen = 8;
				buf = stdmodel[CurPad];
				buf[4] = g.PadState[CurPad].PadMode;
				return 0xF3;
				
			case CMD_QUERY_ACT:
				CmdLen = 8;
				buf = unk46[CurPad];
				return 0xF3;
				
			case CMD_QUERY_COMB:
				CmdLen = 8;
				buf = unk47[CurPad];
				return 0xF3;
				
			case CMD_QUERY_MODE:
				CmdLen = 8;
				buf = unk4c[CurPad];
				return 0xF3;
				
			case CMD_VIBRATION_TOGGLE:
				CmdLen = 8;
				buf = unk4d[CurPad];
				return 0xF3;
				
			case CMD_READ_DATA_AND_VIBRATE:
			default:
				n = g.PadState[CurPad].KeyStatus;
				n &= g.PadState[CurPad].JoyKeyStatus;
				
				stdpar[CurPad][2] = n & 0xFF;
				stdpar[CurPad][3] = n >> 8;
				
				if (g.PadState[CurPad].PadMode == 1) {
					CmdLen = 8;
					
					stdpar[CurPad][4] = g.PadState[CurPad].AnalogStatus[ANALOG_RIGHT][0];
					stdpar[CurPad][5] = g.PadState[CurPad].AnalogStatus[ANALOG_RIGHT][1];
					stdpar[CurPad][6] = g.PadState[CurPad].AnalogStatus[ANALOG_LEFT][0];
					stdpar[CurPad][7] = g.PadState[CurPad].AnalogStatus[ANALOG_LEFT][1];
				}
				else if(g.PadState[CurPad].PadID == 0x12)
				{
					CmdLen = 6;
					
					stdpar[CurPad][4] = g.PadState[0].MouseAxis[0][0];
					stdpar[CurPad][5] = g.PadState[0].MouseAxis[0][1];
				}
				else {
					CmdLen = 4;
				}
				
				buf = stdpar[CurPad];
				return g.PadState[CurPad].PadID;
		}
	}
	
	//makes it so that the following switch doesn't try to dereference a null pointer
	//quiets a warning in the Clang static analyzer.
	if (buf == NULL) {
		return 0;
	}
	
	switch (CurCmd) {
		case CMD_READ_DATA_AND_VIBRATE:
			if (g.cfg.PadDef[CurPad].Type == PSE_PAD_TYPE_ANALOGPAD) {
				if (CurByte == g.PadState[CurPad].Vib0) {
					g.PadState[CurPad].VibF[0] = value;
					
					if (g.PadState[CurPad].VibF[0] != 0 || g.PadState[CurPad].VibF[1] != 0) {
							if (!JoyHapticRumble(CurPad, g.PadState[CurPad].VibF[0], g.PadState[CurPad].VibF[1])) {
								//gpuVisualVibration(g.PadState[CurPad].VibF[0], g.PadState[CurPad].VibF[1]);
							}
						
						//if(gpuVisualVibration != NULL &&
						//   g.cfg.PadDef[CurPad].VisualVibration) {
						//	gpuVisualVibration(g.PadState[CurPad].VibF[0], g.PadState[CurPad].VibF[1]);
						//}
					}
				}
				
				if (CurByte == g.PadState[CurPad].Vib1) {
					g.PadState[CurPad].VibF[1] = value;
					
					if (g.PadState[CurPad].VibF[0] != 0 || g.PadState[CurPad].VibF[1] != 0) {
							if (!JoyHapticRumble(CurPad, g.PadState[CurPad].VibF[0], g.PadState[CurPad].VibF[1])) {
								//gpuVisualVibration(g.PadState[CurPad].VibF[0], g.PadState[CurPad].VibF[1]);
							}
						
						//if(gpuVisualVibration != NULL &&
						//   g.cfg.PadDef[CurPad].VisualVibration) {
						//	gpuVisualVibration(g.PadState[CurPad].VibF[0], g.PadState[CurPad].VibF[1]);
						//}
					}
				}
			}
			break;
			
		case CMD_CONFIG_MODE:
			if (CurByte == 2) {
				switch (value) {
					case 0:
						buf[2] = 0;
						buf[3] = 0;
						break;
						
					case 1:
						buf[2] = 0xFF;
						buf[3] = 0xFF;
						break;
				}
			}
			break;
			
		case CMD_SET_MODE_AND_LOCK:
			if (CurByte == 2) {
				PADSetMode(CurPad, value);
			}
			break;
			
		case CMD_QUERY_ACT:
			if (CurByte == 2) {
				switch (value) {
					case 0: // default
						buf[5] = 0x02;
						buf[6] = 0x00;
						buf[7] = 0x0A;
						break;
						
					case 1: // Param std conf change
						buf[5] = 0x01;
						buf[6] = 0x01;
						buf[7] = 0x14;
						break;
				}
			}
			break;
			
		case CMD_QUERY_MODE:
			if (CurByte == 2) {
				switch (value) {
					case 0: // mode 0 - digital mode
						buf[5] = PSE_PAD_TYPE_STANDARD;
						break;
						
					case 1: // mode 1 - analog mode
						buf[5] = PSE_PAD_TYPE_ANALOGPAD;
						break;
				}
			}
			break;
			
		case CMD_VIBRATION_TOGGLE:
			if (CurByte >= 2 && CurByte < CmdLen) {
				if (CurByte == g.PadState[CurPad].Vib0) {
					buf[CurByte] = 0;
				}
				if (CurByte == g.PadState[CurPad].Vib1) {
					buf[CurByte] = 1;
				}
				
				if (value == 0) {
					g.PadState[CurPad].Vib0 = CurByte;
					if ((g.PadState[CurPad].PadID & 0x0f) < (CurByte - 1) / 2) {
						g.PadState[CurPad].PadID = (g.PadState[CurPad].PadID & 0xf0) + (CurByte - 1) / 2;
					}
				} else if (value == 1) {
					g.PadState[CurPad].Vib1 = CurByte;
					if ((g.PadState[CurPad].PadID & 0x0f) < (CurByte - 1) / 2) {
						g.PadState[CurPad].PadID = (g.PadState[CurPad].PadID & 0xf0) + (CurByte - 1) / 2;
					}
				}
			}
			break;
	}
	
	if (CurByte >= CmdLen) return 0;
	if (buf == NULL) return 0;
	return buf[CurByte++];
}

int JoyHapticRumble(int pad, uint32_t low, uint32_t high)
{
	return 0;
}
// end dfinput code.
