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

// cfg.c functions...
void LoadPADConfig(void);
void SavePADConfig(void);

// sdljoy.c functions...
void InitSDLJoy(void);
void DestroySDLJoy(void);
void CheckJoy(void);

// xkb.c functions...
void InitKeyboard(void);
void DestroyKeyboard(void);
void CheckKeyboard(void);

// analog.c functions...
void InitAnalog(void);
void CheckAnalog(void);
int AnalogKeyPressed(uint16_t Key);
int AnalogKeyReleased(uint16_t Key);

// pad.c functions...
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
