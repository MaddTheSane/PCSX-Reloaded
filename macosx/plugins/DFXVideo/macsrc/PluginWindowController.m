/***************************************************************************
    PluginWindowController.m
    PeopsSoftGPU
  
    Created by Gil Pedersen on Tue April 12 2004.
    Copyright (c) 2004 Gil Pedersen.
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version. See also the license.txt file for *
 *   additional informations.                                              *
 *                                                                         *
 ***************************************************************************/

#import "PluginWindowController.h"
#import "PluginWindow.h"
#include "externals.h"
#undef BOOL

void CALLBACK GPUdisplayText(char * pText)             // some debug func
{
	if(!pText) {
		szDebugText[0] = 0;
		return;
	}
	if (strlen(pText) > 511)
		return;
	strcpy(szDebugText,pText);
	gameController.outputString = @(szDebugText);
}

NSWindow *gameWindow;
NetSfPeopsSoftGPUPluginWindowController *gameController;
NSRect windowFrame;

@interface NetSfPeopsSoftGPUPluginWindowController ()
//@property (strong) NSTimer *textFadeOutTimer;
@end

@implementation NetSfPeopsSoftGPUPluginWindowController
@synthesize glView;

+ (id)openGameView
{
	if (gameWindow == nil) {
		if (gameController == nil) {
			gameController = [[PluginWindowController alloc] initWithWindowNibName:@"NetSfPeopsSoftGPUInterface"];
		}
		gameWindow = [gameController window];
	}
	
	windowFrame = NSMakeRect(0, 0, iResX, iResY);
	
	windowFrame = [NSWindow contentRectForFrameRect:windowFrame styleMask:NSTitledWindowMask];

	
	if (windowFrame.size.width != 0) {
		[gameWindow setFrame:windowFrame display:NO];
	}
	[gameWindow center];

	[gameWindow makeKeyAndOrderFront:nil];
	[gameController showWindow:nil];
	
	CGDirectDisplayID display = (CGDirectDisplayID)[[[gameWindow screen] deviceDescription][@"NSScreenNumber"] unsignedIntValue];
	if (CGDisplayIsCaptured(display)) {
		[gameController setFullscreen:YES];
	}
	
	return gameController;
}

- (PluginGLView *)openGLView
{
	return glLayer;
}

- (void)dealloc
{
	if (fullWindow) {
		[fullWindow orderOut:self];
	}
	fullWindow = nil;
	[self removeObserver:self forKeyPath:@"outputString"];
	
	windowFrame = [[self window] frame];
}

// forget keyDownEvents
- (void)keyDown:(NSEvent *)theEvent
{
	// Not required any more
}

- (void)mouseDown:(NSEvent *)theEvent
{
	if (self.fullscreen) {
		[self setFullscreen:NO];
	}
}

- (instancetype)initWithWindow:(NSWindow *)window
{
	if (self = [super initWithWindow:window]) {
		[self addObserver:self forKeyPath:@"outputString" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
	}
	
	return self;
}

-(void)awakeFromNib
{
	glLayer = [PluginGLView layer];
	glLayer.asynchronous = YES;
	[glView setLayer:glLayer];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self && [keyPath isEqualToString:@"outputString"]) {
		NSString *theStr = change[NSKeyValueChangeNewKey];
		NSUInteger stringLen;
		if ([theStr isKindOfClass:[NSNull class]]) {
			stringLen = 0;
		} else
			stringLen = [theStr length];
		if (stringLen != 0) {
			CATextLayer *titleLayer = [CATextLayer layer];
			titleLayer.string = theStr;
			titleLayer.font = (__bridge CFTypeRef)(@"Helvetica");
			titleLayer.fontSize = glView.bounds.size.height / 6;
			titleLayer.alignmentMode = kCAAlignmentCenter;
			titleLayer.bounds = CGRectMake(0, 0, glView.bounds.size.width, glView.bounds.size.height / 6);
			titleLayer.foregroundColor = [[NSColor redColor]CGColor];
			titleLayer.opacity = 0.0;

			
			//create a fadeInOut CAKeyframeAnimation on opacticy
			CAKeyframeAnimation *fadeInAndOut = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
			
			//set duration
			fadeInAndOut.duration = 5.0;
			
			//autoreverses defaults to NO so we don't need this.
			//fadeInAndOut.autoreverses = NO;
			
			//keyTimes are time points on duration timeline as a fraction of animation duration (here 5 seconds).
			fadeInAndOut.keyTimes = @[@0.0f,
									  @0.20f,
									  @0.80f,
									  @1.0f];
			
			
			//set opacity values at various points during the 5second animation
			fadeInAndOut.values = @[@0.0f,//opacity 0 at 0s (corresponds to keyTime = 0s/5s)
									@1.0f,//opacity 1 at 1s (corresponds to keyTime = 1s/5s)
									@1.0f,//opacity 1 upto 4s (corresponds to keyTime = 4s/5s)
									@0.0f];//opacity 0 at 5s (corresponds to keyTime = 5s/5s)
			
			//delay in start of animation. What we are essentially saying is to start the 5second animation after 1second.
			fadeInAndOut.beginTime = 1.0;
			fadeInAndOut.autoreverses = NO;

			//don't remove the animation on completion.
			fadeInAndOut.removedOnCompletion = NO;
			
			//fill mode. In most cases we won't need this.
			fadeInAndOut.fillMode = kCAFillModeBoth;
			
			//add the animation to layer
			[titleLayer addAnimation:fadeInAndOut forKey:@"myAnim"];
		}
    }
}

- (BOOL)isFullscreen
{
	return (fullWindow != nil);
}

- (void)setFullscreen:(BOOL)flag
{
	NSWindow *window = [self window];
	NSScreen *screen = [window screen];
	CGDirectDisplayID display = (CGDirectDisplayID)[[screen deviceDescription][@"NSScreenNumber"] unsignedIntValue];
	
	NSDisableScreenUpdates();
	
	if (flag) {
		if (!CGDisplayIsCaptured(display)) {
			CGDisplayCapture(display);
			
			CGDisplayCount count = 10;
			CGDirectDisplayID displays[10];
			CGGetActiveDisplayList(10, displays, &count);
			if (count == 1) {
				CGDisplayHideCursor(display);
				CGAssociateMouseAndMouseCursorPosition(NO);
			}
			
			//[window orderOut:self];
		}
		
		size_t width = CGDisplayPixelsWide(display);
		size_t height = CGDisplayPixelsHigh(display);
		
		// assume square pixel ratio on the monitor
		if ((width*3)/4 < height) {
			height = (width*3)/4;
		} else {
			width = (height*4)/3;
		}

		fullWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect((CGDisplayPixelsWide(display)-width)/2, 
																						  (CGDisplayPixelsHigh(display)-height)/2, 
																						  width, height)
							styleMask:NSBorderlessWindowMask
							backing:NSBackingStoreRetained
							defer:NO
							screen:screen];
		
		//[[glView openGLContext] setFullScreen];
		
		//[[glView openGLContext] setView:[fullWindow contentView]];
		//[glView reshape];
		//[[glView openGLContext] update];
		//[fullWindow setContentView:glView];
		
		[fullWindow setBackgroundColor:[NSColor blackColor]];
		[fullWindow setHasShadow:NO];
		[fullWindow setDelegate:self];
		
		[fullWindow setLevel:CGShieldingWindowLevel()];
		[fullWindow makeKeyAndOrderFront:self];

		[[self window] makeKeyAndOrderFront:self];
	} else {
		CGDisplayRelease(display);
		//CGReleaseAllDisplays();

		CGAssociateMouseAndMouseCursorPosition(YES);
		CGDisplayShowCursor(display);

		if (fullWindow) {
			[fullWindow orderOut:self];
			fullWindow = nil;
			
			//[[glView openGLContext] setView:glView];
			//[glView reshape];
			//[window setContentView:glView];
		}
		
		[[self window] makeKeyAndOrderFront:self];
	}
	
	NSEnableScreenUpdates();
}

- (BOOL)windowShouldZoom:(NSWindow *)sender toFrame:(NSRect)newFrame
{
	self.fullscreen = YES;
	
	return NO;
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
	if (!(([sender resizeFlags] & NSShiftKeyMask) == NSShiftKeyMask)) {
		NSRect oldSize = [sender frame];
		NSRect viewSize = [glView frame];
		
		float xDiff = NSWidth(oldSize) - NSWidth(viewSize);
		float yDiff = NSHeight(oldSize) - NSHeight(viewSize);
		
		//if ((proposedFrameSize.height / proposedFrameSize.width) < (3.0/4.0))
		//	proposedFrameSize.height = ((proposedFrameSize.width - xDiff) * 3.0) / 4.0 + yDiff;
		//else
			proposedFrameSize.width = ((proposedFrameSize.height - yDiff) * 4.0) / 3.0 + xDiff;
	}
	
	return proposedFrameSize;
}

- (void)windowWillMiniaturize:(NSNotification *)aNotification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"emuWindowWantPause" object:self];
}

- (void)windowDidDeminiaturize:(NSNotification *)aNotification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"emuWindowWantResume" object:self];
}

- (BOOL)windowShouldClose:(id)sender
{
	if (fullWindow) {
		return NO;
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:@"emuWindowDidClose" object:self];
	gameController = nil;
	gameWindow = nil;
	
	return YES;
}

@end
