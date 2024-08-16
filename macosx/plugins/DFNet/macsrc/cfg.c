//
// DF Netplay Plugin
//
// Based on netSock 0.2 by linuzappz.
// The Plugin is free source code.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "dfnet.h"

void AboutDlgProc(void);
void ConfDlgProc(void);
void ReadConfig(void);

void NETabout(void) {
	AboutDlgProc();
}

long NETconfigure(void) {
	ConfDlgProc();
	
	return 0;
}

void LoadConf(void) {
	ReadConfig();
}
