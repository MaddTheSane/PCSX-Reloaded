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

#ifndef PlugInBridges_h
#define PlugInBridges_h

#include <stdio.h>

typedef struct GPUFreeze_t *GPUFreeze_p;
typedef struct CdrStat *CdrStat_p;
typedef struct xa_decode_t *xa_decode_p;
typedef struct SPUFreeze_t *SPUFreeze_p;

extern long GPUOpen_bridge(unsigned long *, char *, char *);
extern long GPUInit_bridge(void);
extern long GPUShutdown_bridge(void);
extern long GPUClose_bridge(void);
extern void GPUWriteStatus_bridge(uint32_t);
extern void GPUWriteData_bridge(uint32_t);
extern void GPUWriteDataMem_bridge(uint32_t *, int);
extern uint32_t GPUReadStatus_bridge(void);
extern uint32_t GPUReadData_bridge(void);
extern void GPUReadDataMem_bridge(uint32_t *, int);
extern long GPUDmaChain_bridge(uint32_t *,uint32_t);
extern void GPUUpdateLace_bridge(void);
extern long GPUConfigure_bridge(void);
extern long GPUTest_bridge(void);
extern void GPUAbout_bridge(void);
extern void GPUMakeSnapshot_bridge(void);
extern void GPUKeypressed_bridge(int);
extern long GPUFreeze_bridge(uint32_t, GPUFreeze_p);
extern long GPUGetScreenPic_bridge(unsigned char *);
extern long GPUShowScreenPic_bridge(unsigned char *);
extern void GPUHSync_bridge(int);
extern void GPUVBlank_bridge(int);
extern void GPUVisualVibration_bridge(uint32_t, uint32_t);
extern void GPUCursor_bridge(int, int, int);
extern void GPUAddVertex_bridge(short,short,long long,long long,long long);
extern void GPUSetSpeed_bridge(float); // 1.0 = natural speed
extern unsigned long PSEgetLibTypeGPU(void);
extern unsigned long PSEgetLibVersionGPU(void);
extern char *PSEgetLibNameGPU(void);


extern long SPUOpen_bridge(void);
extern long SPUInit_bridge(void);
extern long SPUShutdown_bridge(void);
extern long SPUClose_bridge(void);
extern void SPUWriteRegister_bridge(unsigned long, unsigned short);
extern unsigned short SPUReadRegister_bridge(unsigned long reg);
extern void SPUWriteDMA_bridge(unsigned short);
extern unsigned short SPUReadDMA_bridge(void);
extern void SPUWriteDMAMem_bridge(unsigned short *, int);
extern void SPUReadDMAMem_bridge(unsigned short *, int);
extern void SPUPlayADPCMchannel_bridge(xa_decode_p);
extern long SPUConfigure_bridge(void);
extern long SPUTest_bridge(void);
extern void SPUAbout_bridge(void);
extern long SPUFreeze_bridge(uint32_t, SPUFreeze_p);
extern void SPUAsync_bridge(uint32_t);
extern void SPUPlayCDDAchannel_bridge(short *, int);
extern void SPURegisterCallback_bridge(void (*callback)(void));
extern unsigned long PSEgetLibTypeSPU(void);
extern unsigned long PSEgetLibVersionSPU(void);
extern char *PSEgetLibNameSPU(void);



#endif /* PlugInBridges_h */
