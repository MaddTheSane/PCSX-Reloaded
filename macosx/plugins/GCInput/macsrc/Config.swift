//
//  Config.swift
//  GCInput
//
//  Created by C.W. Betts on 8/26/20.
//

import Cocoa
import GameController
import CoreHaptics

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
	@objc(globalDataInstance) private(set) static var instance: GlobalData? = nil
	@objc static func setUp() {
		instance = GlobalData()
	}
	
	@objc static func shutDown() {
		instance?.close()
		instance = nil
	}
	
	func close() {
		NotificationCenter.default.removeObserver(self, name: .GCControllerDidConnect, object: nil)
		NotificationCenter.default.removeObserver(self, name: .GCControllerDidDisconnect, object: nil)
	}
	
	override init() {
		super.init()
		NotificationCenter.default.addObserver(self, selector: #selector(self.controllerDidConnect(_:)) , name: .GCControllerDidConnect, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(self.controllerDidDisconnect(_:)) , name: .GCControllerDidDisconnect, object: nil)
	}
	
	@objc private func controllerDidConnect(_ note: Notification) {
		
	}

	@objc private func controllerDidDisconnect(_ note: Notification) {
		
	}
	
	@objc func readPadPort(num: CInt, pad: UnsafeMutablePointer<PadDataS>) -> CLong {
		return CLong(PSE_PAD_ERR_SUCCESS)
	}
}
