//
//  PcsxrMemoryObject.swift
//  Pcsxr
//
//  Created by C.W. Betts on 11/9/14.
//
//

import Cocoa
import SwiftAdditions

private func imagesFromMcd(_ theBlock: UnsafePointer<McdBlock>) -> [NSImage] {
	struct PSXRGBColor {
		var r: UInt8
		var g: UInt8
		var b: UInt8
	}

	var toRet = [NSImage]()
	let iconArray: [Int16] = try! arrayFromObject(reflecting: theBlock.pointee.Icon)
	for i in 0..<theBlock.pointee.IconCount {
		if let imageRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 16, pixelsHigh: 16, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: NSColorSpaceName.calibratedRGB, bytesPerRow: 16 * 3, bitsPerPixel: 24) {
			imageRep.bitmapData?.withMemoryRebound(to: PSXRGBColor.self, capacity: 256, { (cocoaImageData) -> Void in
				for v in 0..<256 {
					//let x = v % 16
					//let y = v / 16
					let c = iconArray[Int(i * 256) + v]
					let r = (c & 0x001F) << 3
					let g = ((c & 0x03E0) >> 5) << 3
					let b = ((c & 0x7C00) >> 10) << 3
					cocoaImageData[v] = PSXRGBColor(r: UInt8(r), g: UInt8(g), b: UInt8(b))
				}
			})
			let memImage = NSImage()
			memImage.addRepresentation(imageRep)
			memImage.size = NSSize(width: 32, height: 32)
			toRet.append(memImage)
		}
	}
	return toRet
}

private func memoryLabelFromFlag(_ flagNameIndex: PcsxrMemoryObject.MemoryFlag) -> String {
	switch (flagNameIndex) {
	case .endLink:
		return MemLabelEndLink;
		
	case .link:
		return MemLabelLink;
		
	case .used:
		return MemLabelUsed;
		
	case .deleted:
		return MemLabelDeleted;
		
	default:
		return MemLabelFree;
	}
}

private let MemLabelDeleted		= NSLocalizedString("MemCard_Deleted", comment: "MemCard_Deleted")
private let MemLabelFree		= NSLocalizedString("MemCard_Free", comment: "MemCard_Free")
private let MemLabelUsed		= NSLocalizedString("MemCard_Used", comment: "MemCard_Used")
private let MemLabelLink		= NSLocalizedString("MemCard_Link", comment: "MemCard_Link")
private let MemLabelEndLink		= NSLocalizedString("MemCard_EndLink", comment: "MemCard_EndLink")
private let MemLabelMultiSave	= NSLocalizedString("MemCard_MultiSave", comment: "MemCard_MultiSave")

private var attribMemLabelDeleted	= NSAttributedString()
private var attribMemLabelFree		= NSAttributedString()
private var attribMemLabelUsed		= NSAttributedString()
private var attribMemLabelLink		= NSAttributedString()
private var attribMemLabelEndLink	= NSAttributedString()
private var attribMemLabelMultiSave	= NSAttributedString()

private let imageBlank: NSImage = {
	let imageRect = NSRect(x: 0, y: 0, width: 16, height: 16)
	let anImg = NSImage(size: imageRect.size)
	anImg.lockFocus()
	NSColor.black.set()
	NSBezierPath.fill(imageRect)
	anImg.unlockFocus()
	return anImg
}()

private func blankImage() -> NSImage {
	return imageBlank.copy() as! NSImage
}

func MemFlagsFromBlockFlags(_ blockFlags: UInt8) -> PcsxrMemoryObject.MemoryFlag {
	if ((blockFlags & 0xF0) == 0xA0) {
		if ((blockFlags & 0xF) >= 1 && (blockFlags & 0xF) <= 3) {
			return .deleted;
		} else {
			return .free
		}
	} else if ((blockFlags & 0xF0) == 0x50) {
		if ((blockFlags & 0xF) == 0x1) {
			return .used
		} else if ((blockFlags & 0xF) == 0x2) {
			return .link
		} else if ((blockFlags & 0xF) == 0x3) {
			return .endLink
		}
	} else {
		return .free;
	}
	
	//Xcode complains unless we do this...
	NSLog("Unknown flag %x", blockFlags)
	return .free;
}

final class PcsxrMemoryObject: NSObject {
	@objc(PCSXRMemFlag) enum MemoryFlag: Int8 {
		case deleted
		case free
		case used
		case link
		case endLink
	};

	private static var __once: () = {
			func SetupAttrStr(_ mutStr: NSMutableAttributedString, txtclr: NSColor) {
				let wholeStrRange = NSMakeRange(0, mutStr.length)
				let ourAttrs: [NSAttributedString.Key: Any] = [.font : NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small)),
					.foregroundColor: txtclr]
				mutStr.addAttributes(ourAttrs, range: wholeStrRange)
				mutStr.setAlignment(.center, range: wholeStrRange)
			}
			
			var tmpStr = NSMutableAttributedString(string: MemLabelFree)
			SetupAttrStr(tmpStr, txtclr: NSColor.systemGreen)
			attribMemLabelFree = NSAttributedString(attributedString: tmpStr)
			
			#if DEBUG
				tmpStr = NSMutableAttributedString(string: MemLabelEndLink)
				SetupAttrStr(tmpStr, txtclr: NSColor.systemBlue)
				attribMemLabelEndLink = NSAttributedString(attributedString: tmpStr)
				
				tmpStr = NSMutableAttributedString(string: MemLabelLink)
				SetupAttrStr(tmpStr, txtclr: NSColor.systemBlue)
				attribMemLabelLink = NSAttributedString(attributedString: tmpStr)
				
				tmpStr = NSMutableAttributedString(string: MemLabelUsed)
				SetupAttrStr(tmpStr, txtclr: NSColor.controlTextColor)
				attribMemLabelUsed = NSAttributedString(attributedString: tmpStr)
			#else
				tmpStr = NSMutableAttributedString(string: MemLabelMultiSave)
				SetupAttrStr(tmpStr, txtclr: NSColor.systemBlue)
				attribMemLabelEndLink = NSAttributedString(attributedString: tmpStr)
				attribMemLabelLink = attribMemLabelEndLink

				//display nothing
				attribMemLabelUsed = NSAttributedString(string: "")
			#endif
			
			tmpStr = NSMutableAttributedString(string: MemLabelDeleted)
			SetupAttrStr(tmpStr, txtclr: NSColor.systemRed)
			attribMemLabelDeleted = NSAttributedString(attributedString: tmpStr)
		}()
	@objc let title: String
	@objc let name: String
	@objc let identifier: String
	let imageArray: [NSImage]
	@objc let flag: MemoryFlag
	@objc let indexes: IndexSet
	@objc let hasImages: Bool
	
	@objc var blockSize: Int {
		return indexes.count
	}
	
	@objc init(mcdBlock infoBlock: UnsafePointer<McdBlock>, blockIndexes: IndexSet) {
		self.indexes = blockIndexes
		let unwrapped = infoBlock.pointee
		flag = MemFlagsFromBlockFlags(unwrapped.Flags)
		if flag == .free {
			imageArray = []
			hasImages = false
			title = "Free block"
			identifier = ""
			name = ""
		} else {
			let sjisName: [CChar] = try! arrayFromObject(reflecting: unwrapped.sTitle, appendLastObject: 0)
			if let aname = String(cString: sjisName, encoding: String.Encoding.shiftJIS) {
				title = aname
			} else {
				let usName: [CChar] = try! arrayFromObject(reflecting: unwrapped.Title, appendLastObject: 0)
				title = String(cString: usName, encoding: String.Encoding.ascii)!
			}
			imageArray = imagesFromMcd(infoBlock)
			if imageArray.count == 0 {
				hasImages = false
			} else {
				hasImages = true
			}
			let memNameCArray: [CChar] = try! arrayFromObject(reflecting: unwrapped.Name, appendLastObject: 0)
			let memIDCArray: [CChar] = try! arrayFromObject(reflecting: unwrapped.ID, appendLastObject: 0)
			name = String(validatingUTF8: memNameCArray)!
			identifier = String(validatingUTF8: memIDCArray)!
		}
		
		super.init()
	}
	
	@objc convenience init(mcdBlock infoBlock: UnsafePointer<McdBlock>, startingIndex startIdx: Int, size memSize: Int) {
		self.init(mcdBlock: infoBlock, blockIndexes: IndexSet(integersIn: Range(NSRange(location: startIdx, length: memSize))!))
	}
	
	@objc var iconCount: Int {
		return imageArray.count
	}

	@objc class func memFlagsFromBlockFlags(_ blockFlags: UInt8) -> MemoryFlag {
		return MemFlagsFromBlockFlags(blockFlags)
	}
	
	@objc private(set) lazy var image: NSImage = {
		if (self.hasImages == false) {
			let tmpBlank = blankImage()
			tmpBlank.size = NSSize(width: 32, height: 32)
			return tmpBlank
		}
		
		let gifData = NSMutableData()
		
		let dst = CGImageDestinationCreateWithData(gifData, kUTTypeGIF, self.iconCount, nil)!
		let gifPrep: NSDictionary = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: Float(0.30)]];
		for theImage in self.imageArray {
			let imageRef = theImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!
			CGImageDestinationAddImage(dst, imageRef, gifPrep)
		}
		CGImageDestinationFinalize(dst);
		
		let _memImage = NSImage(data: gifData as Data)!
		_memImage.size = NSSize(width: 32, height: 32)
		return _memImage
		}()
	
	@objc var attributedFlagName: NSAttributedString {
		_ = PcsxrMemoryObject.__once
		
		switch (flag) {
		case .endLink:
			return attribMemLabelEndLink;
			
		case .link:
			return attribMemLabelLink;
			
		case .used:
			return attribMemLabelUsed;
			
		case .deleted:
			return attribMemLabelDeleted;
			
		default:
			return attribMemLabelFree;
		}
	}
	
	@objc var firstImage: NSImage {
		if hasImages == false {
			return blankImage()
		}
		return imageArray[0]
	}
	
	@objc(memoryLabelFromFlag:) class func memoryLabel(from flagNameIdx: MemoryFlag) -> String {
		return memoryLabelFromFlag(flagNameIdx)
	}
	
	@objc var flagName: String {
		return memoryLabelFromFlag(flag)
	}

	override var description: String {
		return "\(title): Name: \(name) ID: \(identifier), type: \(flagName), indexes: \(indexes)"
	}
	
	@objc var showCount: Bool {
		if flag == .free {
			//Always show the size of the free blocks
			return true;
		} else {
			return blockSize != 1;
		}
	}
}
