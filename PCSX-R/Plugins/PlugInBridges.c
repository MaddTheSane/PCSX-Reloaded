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

// This file simply bridges the plug-in functions with

#include "PlugInBridges.h"

typedef long long s64;

extern long GPUopen(unsigned long *, char *, char *);
extern long GPUinit(void);
extern long GPUshutdown(void);
extern long GPUclose(void);
extern void GPUwriteStatus(uint32_t);
extern void GPUwriteData(uint32_t);
extern void GPUwriteDataMem(uint32_t *, int);
extern uint32_t GPUreadStatus(void);
extern uint32_t GPUreadData(void);
extern void GPUreadDataMem(uint32_t *, int);
extern long GPUdmaChain(uint32_t *,uint32_t);
extern void GPUupdateLace(void);
extern long GPUconfigure(void);
extern long GPUtest(void);
extern void GPUabout(void);
extern void GPUmakeSnapshot(void);
extern void GPUkeypressed(int);
extern long GPUfreeze(uint32_t, GPUFreeze_p);
extern long GPUgetScreenPic(unsigned char *);
extern long GPUshowScreenPic(unsigned char *);
extern void GPUhSync(int);
extern void GPUvBlank(int);
extern void GPUvisualVibration(uint32_t, uint32_t);
extern void GPUcursor(int, int, int);
extern void GPUaddVertex(short,short,s64,s64,s64);
extern void GPUsetSpeed(float); // 1.0 = natural speed

extern long CDRinit(void);
extern long CDRshutdown(void);
extern long CDRopen(void);
extern long CDRclose(void);
extern long CDRgetTN(unsigned char *);
extern long CDRgetTD(unsigned char, unsigned char *);
extern long CDRreadTrack(unsigned char *);
extern unsigned char* CDRgetBuffer(void);
extern unsigned char* CDRgetBufferSub(void);
extern long CDRconfigure(void);
extern long CDRtest(void);
extern void CDRabout(void);
extern long CDRplay(unsigned char *);
extern long CDRstop(void);
extern long CDRgetStatus(CdrStat_p);
extern long CDRreadCDDA(unsigned char, unsigned char, unsigned char, unsigned char *);
extern long CDRgetTE(unsigned char, unsigned char *, unsigned char *, unsigned char *);

extern long SPUinit(void);
extern long SPUshutdown(void);
extern long SPUclose(void);
extern long SPUopen(void);
extern void SPUwriteRegister(unsigned long, unsigned short);
extern unsigned short SPUreadRegister(unsigned long);
extern void SPUwriteDMA(unsigned short);
extern unsigned short SPUreadDMA(void);
extern void SPUwriteDMAMem(unsigned short *, int);
extern void SPUreadDMAMem(unsigned short *, int);
extern void SPUplayADPCMchannel(xa_decode_p);
extern void SPUregisterCallback(void (*callback)(void));
extern long SPUconfigure(void);
extern long SPUtest(void);
extern void SPUabout(void);
extern long SPUfreeze(uint32_t, SPUFreeze_p);
extern void SPUasync(uint32_t);
extern void SPUplayCDDAchannel(short *, int);
extern unsigned short SPUreadRegister(unsigned long);

extern long GPUOpen_bridge(unsigned long *x, char *y, char *z)
{
	return GPUopen(x, y, z);
}

long GPUInit_bridge(void)
{
	return GPUinit();
}

long GPUShutdown_bridge(void)
{
	return GPUshutdown();
}

long GPUClose_bridge(void)
{
	return GPUclose();
}

void GPUWriteStatus_bridge(uint32_t x)
{
	GPUwriteStatus(x);
}

void GPUWriteData_bridge(uint32_t x)
{
	GPUwriteData(x);
}

void GPUWriteDataMem_bridge(uint32_t *x, int y)
{
	GPUwriteDataMem(x, y);
}

uint32_t GPUReadStatus_bridge(void)
{
	return GPUreadStatus();
}

uint32_t GPUReadData_bridge(void)
{
	return GPUreadData();
}

void GPUReadDataMem_bridge(uint32_t *x, int y)
{
	return GPUreadDataMem(x, y);
}

long GPUDmaChain_bridge(uint32_t *x,uint32_t y)
{
	return GPUdmaChain(x, y);
}

void GPUUpdateLace_bridge(void)
{
	GPUupdateLace();
}

long GPUConfigure_bridge(void)
{
	return GPUconfigure();
}

long GPUTest_bridge(void)
{
	return GPUtest();
}

void GPUAbout_bridge(void)
{
	return GPUabout();
}

void GPUMakeSnapshot_bridge(void)
{
	 GPUmakeSnapshot();
}

void GPUKeypressed_bridge(int x)
{
	GPUkeypressed(x);
}

long GPUFreeze_bridge(uint32_t x, GPUFreeze_p y)
{
	return GPUfreeze(x, y);
}

long GPUGetScreenPic_bridge(unsigned char *x)
{
	return GPUgetScreenPic(x);
}

long GPUShowScreenPic_bridge(unsigned char *x)
{
	return GPUshowScreenPic(x);
}

void GPUHSync_bridge(int x)
{
	GPUhSync(x);
}

void GPUVBlank_bridge(int x)
{
	GPUvBlank(x);
}

void GPUVisualVibration_bridge(uint32_t x, uint32_t y)
{
	GPUvisualVibration(x, y);
}

void GPUCursor_bridge(int x, int y, int z)
{
	GPUcursor(x, y, z);
}

void GPUAddVertex_bridge(short x, short y, s64 z, s64 a, s64 b)
{
	GPUaddVertex(x, y, z, a, b);
}

void GPUSetSpeed_bridge(float x)
{
	GPUsetSpeed(x);
}

long CDRInit_bridge(void)
{
	return CDRinit();
}

long CDRShutdown_bridge(void)
{
	return CDRshutdown();
}

long CDROpen_bridge(void)
{
	return CDRopen();
}

long CDRClose_bridge(void)
{
	return CDRclose();
}

long CDRGetTN_bridge(unsigned char *x)
{
	return CDRgetTN(x);
}

long CDRGetTD_bridge(unsigned char x, unsigned char *y)
{
	return CDRgetTD(x, y);
}

long CDRReadTrack_bridge(unsigned char *x)
{
	return CDRreadTrack(x);
}

unsigned char* CDRGetBuffer_bridge(void)
{
	return CDRgetBuffer();
}

unsigned char* CDRGetBufferSub_bridge(void)
{
	return CDRgetBufferSub();
}

long CDRConfigure_bridge(void)
{
	return CDRconfigure();
}

long CDRTest_bridge(void)
{
	return CDRtest();
}

void CDRAbout_bridge(void)
{
	return CDRabout();
}

long CDRPlay_bridge(unsigned char *x)
{
	return CDRplay(x);
}

long CDRStop_bridge(void)
{
	return CDRstop();
}

long CDRGetStatus_bridge(struct CdrStat *x)
{
	return CDRgetStatus(x);
}

long CDRReadCDDA_bridge(unsigned char x, unsigned char y, unsigned char z, unsigned char *a)
{
	return CDRreadCDDA(x, y, z, a);
}

long CDRGetTE_bridge(unsigned char x, unsigned char *y, unsigned char *z, unsigned char *a)
{
	return CDRgetTE(x, y, z, a);
}

long SPUOpen_bridge(void)
{
	return SPUopen();
}

long SPUInit_bridge(void)
{
	return SPUinit();
}

long SPUShutdown_bridge(void)
{
	return SPUshutdown();
}

long SPUClose_bridge(void)
{
	return SPUclose();
}

unsigned short SPUReadRegister_bridge(unsigned long reg)
{
	return SPUreadRegister(reg);
}

void SPUWriteRegister_bridge(unsigned long x, unsigned short y)
{
	return SPUwriteRegister(x, y);
}

void SPUWriteDMA_bridge(unsigned short x)
{
	return SPUwriteDMA(x);
}

unsigned short SPUReadDMA_bridge(void)
{
	return SPUreadDMA();
}

void SPUWriteDMAMem_bridge(unsigned short *x, int y)
{
	return SPUwriteDMAMem(x, y);
}

void SPUReadDMAMem_bridge(unsigned short *x, int y)
{
	return SPUreadDMAMem(x, y);
}

void SPUPlayADPCMchannel_bridge(xa_decode_p x)
{
	return SPUplayADPCMchannel(x);
}

long SPUConfigure_bridge(void)
{
	return SPUconfigure();
}

long SPUTest_bridge(void)
{
	return SPUtest();
}

void SPUAbout_bridge(void)
{
	return SPUabout();
}

long SPUFreeze_bridge(uint32_t x, SPUFreeze_p y)
{
	return SPUfreeze(x, y);
}

void SPUAsync_bridge(uint32_t x)
{
	return SPUasync(x);
}

void SPUPlayCDDAchannel_bridge(short * x, int y)
{
	return SPUplayCDDAchannel(x, y);
}

void SPURegisterCallback_bridge(void (*callback)(void))
{
	SPUregisterCallback(callback);
}

