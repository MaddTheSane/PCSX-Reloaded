/*
 * Copyright (c) 2010, Wei Mingzhi <whistler_wmz@users.sf.net>.
 * All Rights Reserved.
 *
 * Based on: HIDInput by Gil Pedersen.
 * Copyright (c) 2004, Gil Pedersen.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses>.
 */

#import "PadView.h"
#include "gcpad.h"

@implementation PadView
@synthesize controllerList = controller;

- (id)initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame:frameRect]) {
		controller = [[ControllerList alloc] initWithConfig];
		[self setController:0];
	}
	return self;
}

- (void)drawRect:(NSRect)rect
{
	
}

- (IBAction)setType:(id)sender
{
	g.cfg.PadDef[[ControllerList currentController]].Type =
		([sender indexOfSelectedItem] > 0 ? PSE_PAD_TYPE_ANALOGPAD : PSE_PAD_TYPE_STANDARD);
	
	[self.tableView reloadData];
}

- (IBAction)setDevice:(id)sender
{
	g.cfg.PadDef[[ControllerList currentController]].DevNum = (int)[sender indexOfSelectedItem] - 1;
}

- (void)setController:(int)which
{
	int i;
	
	[ControllerList setCurrentController:which];
	[self.tableView setDataSource:controller];
	
	[self.deviceMenu removeAllItems];
	[self.deviceMenu addItemWithTitle:[[NSBundle bundleForClass:[self class]] localizedStringForKey:@"(Keyboard only)" value:@"" table:nil]];
	
#if 0
	for (i = 0; i < SDL_NumJoysticks(); i++) {
		NSMenuItem *joystickItem;
		joystickItem = [[NSMenuItem alloc] initWithTitle:@(SDL_JoystickName(i)) action:NULL keyEquivalent:@""];
		[joystickItem setTag:i + 1];
        [[self.deviceMenu menu] addItem:joystickItem];
	}
	
	if (g.cfg.PadDef[which].DevNum >= SDL_NumJoysticks()) {
		g.cfg.PadDef[which].DevNum = -1;
	}
#endif
	
	[self.deviceMenu selectItemAtIndex:g.cfg.PadDef[which].DevNum + 1];
	[self.typeMenu selectItemAtIndex:(g.cfg.PadDef[which].Type == PSE_PAD_TYPE_ANALOGPAD ? 1 : 0)];
	
	[self.tableView reloadData];
}

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor
{
	return false;
}

/* handles key events on the pad list */
- (void)keyDown:(NSEvent *)theEvent
{
	unsigned short key = [theEvent keyCode];
	
	if ([[theEvent window] firstResponder] == self.tableView) {
		if (key == 51 || key == 117) {
			// delete keys - remove the mappings for the selected item
			[controller deleteRow:[self.tableView selectedRow]];
			[self.tableView reloadData];
			return;
		} else if (key == 36) {
			// return key - configure the selected item
			[self.tableView editColumn:[self.tableView columnWithIdentifier:@"button"] row:[self.tableView selectedRow] withEvent:nil select:YES];
			return;
		}
	}
	
	[super keyDown:theEvent];
}

@end
