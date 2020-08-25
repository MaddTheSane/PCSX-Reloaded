//
//  gcpad.h
//  DFInput
//
//  Created by C.W. Betts on 8/25/20.
//

#ifndef gcpad_h
#define gcpad_h

#include <stdio.h>
#include "psemu_plugin_defs.h"

#import <GameController/GameController.h>
#import <CoreHaptics/CoreHaptics.h>

typedef void *Display;

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

typedef NS_ENUM(uint8_t, JoyEvent) {
	NONE = 0,
	AXIS,
	HAT,
	BUTTON
};

typedef struct tagKeyDef {
	JoyEvent		JoyEvType;
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
    uint8_t         PhysicalVibration;
	KEYDEF			KeyDef[DKEY_TOTAL];
	KEYDEF			AnalogDef[ANALOG_TOTAL][4];
} PADDEF;

typedef struct tagEmuDef {
	uint16_t	EmuKeyEvent;
	KEYDEF		Mapping;
} EMUDEF;

typedef struct tagEmuDef2{
	EMUDEF		EmuDef[EMU_TOTAL];
	GCController	*EmuKeyDev;
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
	GCController		*JoyDev;
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
	CHHapticEngine		*haptic;
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

// cfg.c functions...
void LoadPADConfig(void);
void SavePADConfig(void);

// analog.c functions...
void InitAnalog(void);
void CheckAnalog(void);
int AnalogKeyPressed(uint16_t Key);
int AnalogKeyReleased(uint16_t Key);

// gcpad.c functions...
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

#endif /* gcpad_h */
