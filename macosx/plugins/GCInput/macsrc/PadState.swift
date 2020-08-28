//
//  PadState.swift
//  GCInput
//
//  Created by C.W. Betts on 8/27/20.
//

import Foundation
import GameController
import CoreHaptics

struct PadState {
	var device: GCController? = nil
	var hapticsLeft: CHHapticEngine? = nil
	var hapticsRight: CHHapticEngine? = nil
	var mode: UInt8 = 0
	var padIdentifier: UInt8 = 0
	var padType: PSXPadType = .standard
}
