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

let padDataLength: [PSXPadType: Int] = [.mouse: 2, .negCon: 3, .konamiGun: 1, .standard: 1, .analogJoystick: 3, .namcoGun: 3, .analogPad: 3]

class GlobalData: NSObject {
	@objc(globalDataInstance) private(set) static var instance: GlobalData? = nil
	
	var display: Display? = nil
	@objc var gpuVisualVibration: (@convention(c) (UInt32, UInt32) -> Void)? = nil
	
	@objc static func setUp() {
		instance = GlobalData()
	}
	
	@objc static func shutDown() {
		_=instance?.close()
		instance = nil
	}
	
	func close() {
		NotificationCenter.default.removeObserver(self, name: .GCControllerDidConnect, object: nil)
		NotificationCenter.default.removeObserver(self, name: .GCControllerDidDisconnect, object: nil)
		display = nil
	}
	
	@objc func open(display disp: UnsafeMutableRawPointer) -> CLong {
		display = disp.assumingMemoryBound(to: UnsafeMutableRawPointer.self).pointee
		return CLong(PSE_PAD_ERR_SUCCESS)
	}
	
	@objc class func startConfiguration() {
		
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
	
	@objc func startPoll(pad: CInt) -> UInt8 {
		//CurPad = pad - 1;
		//CurByte = 0;
		return 0xff
	}
	
	@objc func poll(value: UInt8) -> UInt8 {
		return 0
	}
	
	@objc func keyPressed() -> CLong {
		return 0
	}
	
	@objc func setMode(_ mode: CInt, forPad pad: CInt) {
		
	}
}
