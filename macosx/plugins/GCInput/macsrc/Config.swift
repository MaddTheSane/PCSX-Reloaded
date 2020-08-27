//
//  Config.swift
//  GCInput
//
//  Created by C.W. Betts on 8/26/20.
//

import Cocoa

struct KeyDef {
	enum JoyEvent {
		case none
		/// positive=axis+, negative=axis-, abs(Axis)-1=axis index
		case axis(Int16)
		/// 8-bit for hat number, 8-bit for direction
		case hat(index: UInt8, direction: UInt8)
		/// button number
		case button(UInt16)
	}
	var joy = JoyEvent.none
	var key: UInt16 = 0
	var releaseEventPending: UInt8 = 0
}

class GlobalData: NSObject {
	@objc(globalDataInstance) static var instance: GlobalData? = nil
}

/*
typedef struct tagKeyDef {
	KeyJoyEvent		JoyEvType;
	union {
		int16_t		d;
		int16_t		Axis;   // positive=axis+, negative=axis-, abs(Axis)-1=axis index
		uint16_t	Hat;	// 8-bit for hat number, 8-bit for direction
		uint16_t	Button; // button number
	} J;
	uint16_t		Key;
	uint8_t			ReleaseEventPending;
} KEYDEF;

*/
