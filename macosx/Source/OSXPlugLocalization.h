//
//  OSXPlugLocalization.h
//  Pcsxr
//
//  Created by C.W. Betts on 7/8/13.
//
//

#ifndef Pcsxr_OSXPlugLocalization_h
#define Pcsxr_OSXPlugLocalization_h

#define PLUGLOCIMP(klass) \
char* PLUGLOC(char *toloc) \
{ \
static char localizedStorage[4096];\
static NSMutableDictionary *transStorage; \
if (transStorage == nil) { \
transStorage = [[NSMutableDictionary alloc] init]; \
} \
NSBundle *mainBundle = [NSBundle bundleForClass:klass]; \
NSString *origString = @(toloc), *transString = nil; \
if ([transStorage objectForKey:origString]) { \
strlcpy(localizedStorage, [[transStorage objectForKey:origString] UTF8String], sizeof(localizedStorage)); \
return localizedStorage;\
} \
transString = [mainBundle localizedStringForKey:origString value:@"" table:nil]; \
[transStorage setObject:transString forKey:origString]; \
strlcpy(localizedStorage, [transString UTF8String], sizeof(localizedStorage)); \
return localizedStorage;\
}

#endif
