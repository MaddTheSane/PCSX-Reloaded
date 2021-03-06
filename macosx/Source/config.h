//
// Copyright (c) 2008, Wei Mingzhi. All rights reserved.
//
// Use, redistribution and modification of this code is unrestricted as long as this
// notice is preserved.
//

#ifndef CONFIG_H
#define CONFIG_H

#ifndef MAXPATHLEN
// Somewhere along the line, Mac OS X added MAXPATHLEN.
#include <sys/param.h>
#endif

#ifndef PACKAGE_VERSION
#define PACKAGE_VERSION "1.9"
#endif

#ifndef PREFIX
#define PREFIX "./"
#endif

#ifndef inline
#ifdef _DEBUG
#define inline /* */
#else
#define inline __inline__
#endif
#endif

#endif
