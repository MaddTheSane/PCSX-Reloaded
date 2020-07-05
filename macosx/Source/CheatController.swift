//
//  CheatController.swift
//  Pcsxr
//
//  Created by C.W. Betts on 11/11/14.
//
//

import Cocoa
import SwiftAdditions

let kTempCheatCodesName = "cheatValues"
let kCheatsName = "cheats"

final class CheatController: NSWindowController, NSWindowDelegate {
	@objc var cheats: [CheatObject]
	@objc var cheatValues = [CheatValue]()
	@IBOutlet weak var cheatView: NSTableView!
	@IBOutlet weak var editCheatWindow: NSWindow!
	@IBOutlet weak var editCheatView: NSTableView!
	@IBOutlet weak var addressFormatter: PcsxrHexadecimalFormatter!
	@IBOutlet weak var valueFormatter: PcsxrHexadecimalFormatter!
	
	required init?(coder: NSCoder) {
		cheats = [CheatObject]()
		
		super.init(coder: coder)
	}
	
	override init(window: NSWindow?) {
		cheats = [CheatObject]()
		
		super.init(window: window)
	}
	
	class func newController() -> CheatController {
		let toRet = CheatController(windowNibName: NSNib.Name("CheatWindow"))
		
		return toRet
	}
	
	override var windowNibName: NSNib.Name? {
		return NSNib.Name("CheatWindow")
	}
	
	@objc func refresh() {
		cheatView.reloadData()
		refreshCheatArray()
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		valueFormatter.hexPadding = 4
		addressFormatter.hexPadding = 8
		refreshCheatArray()
		self.addObserver(self, forKeyPath: kCheatsName, options: [.new, .old], context: nil)
	}
	
	private func refreshCheatArray() {
		var tmpArray = [CheatObject]()
		for i in 0..<Int(NumCheats) {
			let tmpObj = CheatObject(cheat: Cheats[i])
			tmpArray.append(tmpObj)
		}
		cheats = tmpArray
		setDocumentEdited(false)
	}
	
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if keyPath == kCheatsName {
			setDocumentEdited(true)
		}
	}
	
	private func reloadCheats() {
		let manager = FileManager.default
		let tmpURL = (try! manager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: Bundle.main.bundleURL, create: true)).appendingPathComponent("temp.cht", isDirectory: false)
		let tmp = cheats.map { (val) -> String in
			return val.description
		}
		let tmpStr = tmp.joined(separator: "\n")
		do {
			try tmpStr.write(to: tmpURL, atomically: false, encoding: .utf8)
		} catch _ {
			NSSound.beep()
			return
		}
		tmpURL.withUnsafeFileSystemRepresentation { (fsr) -> Void in
			LoadCheats(fsr)
		}
		do {
			try manager.removeItem(at: tmpURL)
		} catch _ {
		}
	}
	
	@IBAction func loadCheats(_ sender: AnyObject?) {
		let openDlg = NSOpenPanel()
		openDlg.allowsMultipleSelection = false
		openDlg.allowedFileTypes = PcsxrCheatHandler.supportedUTIs
		openDlg.beginSheetModal(for: window!, completionHandler: { (retVal) -> Void in
			if retVal.rawValue == NSFileHandlingPanelOKButton {
				let file = openDlg.url!
				LoadCheats((file as NSURL).fileSystemRepresentation)
				self.refresh()
			}
		})
	}
	
	@IBAction func saveCheats(_ sender: AnyObject?) {
		let saveDlg = NSSavePanel()
		saveDlg.allowedFileTypes = PcsxrCheatHandler.supportedUTIs
		saveDlg.canSelectHiddenExtension = true
		saveDlg.canCreateDirectories = true
		saveDlg.prompt = NSLocalizedString("Save Cheats", comment: "")
		saveDlg.beginSheetModal(for: window!, completionHandler: { (retVal) -> Void in
			if retVal.rawValue == NSFileHandlingPanelOKButton {
				let url = saveDlg.url!
				let saveString: String = {
					var toRet = ""
					for ss in self.cheats {
						toRet += ss.description + "\n"
					}
					
					return toRet
					}()
				do {
					//let saveString = (self.cheats as NSArray).componentsJoinedByString("\n") as NSString
					try saveString.write(to: url, atomically: true, encoding: .utf8)
				} catch _ {
					NSSound.beep()
				}
			}
		})
	}
	
	@IBAction func clear(_ sender: AnyObject?) {
		cheats = []
	}
	
	@IBAction func closeCheatEdit(_ sender: NSButton) {
		window!.endSheet(editCheatWindow, returnCode: sender.tag == 1 ? NSApplication.ModalResponse.cancel : NSApplication.ModalResponse.OK)
	}
	
	@IBAction func changeCheat(_ sender: AnyObject?) {
		self.setDocumentEdited(true)
	}
	
	@IBAction func removeCheatValue(_ sender: AnyObject?) {
		if editCheatView.selectedRow < 0 {
			NSSound.beep()
			return
		}
		
		let toRemoveIndex = editCheatView.selectedRowIndexes
		willChange(.removal, valuesAt: toRemoveIndex, forKey: kTempCheatCodesName)
		cheatValues.remove(indexes: toRemoveIndex)
		didChange(.removal, valuesAt: toRemoveIndex, forKey: kTempCheatCodesName)
	}
	
	@IBAction func addCheatValue(_ sender: AnyObject?) {
		let newSet = IndexSet(integer: cheatValues.count)
		willChange(.insertion, valuesAt: newSet, forKey: kTempCheatCodesName)
		cheatValues.append(CheatValue())
		didChange(.insertion, valuesAt: newSet, forKey: kTempCheatCodesName)
	}
	
	
	@IBAction func editCheat(_ sender: AnyObject?) {
		if cheatView.selectedRow < 0 {
			NSSound.beep()
			return;
		}
		let tmpArray = cheats[cheatView.selectedRow].values
		let newCheats: [CheatValue] = {
			var tmpCheat = [CheatValue]()
			for che in tmpArray {
				tmpCheat.append(che.copy() as! CheatValue)
			}
			
			return tmpCheat
		}()
		
		cheatValues = newCheats
		editCheatView.reloadData()
		window!.beginSheet(editCheatWindow, completionHandler: { (returnCode) -> Void in
			if returnCode == NSApplication.ModalResponse.OK {
				let tmpCheat = self.cheats[self.cheatView.selectedRow]
				if tmpCheat.values != self.cheatValues {
					tmpCheat.values = self.cheatValues
					self.setDocumentEdited(true)
				}
			}
			self.editCheatWindow.orderOut(nil)
		})
	}
	
	@IBAction func addCheat(_ sender: AnyObject?) {
		let newSet = IndexSet(integer: cheats.count)
		willChange(.insertion, valuesAt: newSet, forKey: kCheatsName)
		let tmpCheat = CheatObject(name: NSLocalizedString("New Cheat", comment: "New Cheat Name"))
		cheats.append(tmpCheat)
		didChange(.insertion, valuesAt: newSet, forKey: kCheatsName)
		setDocumentEdited(true)
	}
	
	@IBAction func applyCheats(_ sender: AnyObject?) {
		reloadCheats()
		setDocumentEdited(false)
	}
	
	func windowShouldClose(_ sender: NSWindow) -> Bool {
		if (!sender.isDocumentEdited || sender != window) {
			return true
		} else {
			let alert = NSAlert()
			alert.messageText = NSLocalizedString("Unsaved Changes", comment: "Unsaved changes")
			alert.informativeText = NSLocalizedString("The cheat codes have not been applied. Unapplied cheats will not run nor be saved. Do you wish to save?", comment: "")
			alert.addButton(withTitle: NSLocalizedString("Save", comment: "Save"))
			alert.addButton(withTitle: NSLocalizedString("Don't Save", comment: "Don't Save"))
			alert.addButton(withTitle: NSLocalizedString("Cancel", comment:"Cancel"))
			
			alert.beginSheetModal(for: window!, completionHandler: { (response) -> Void in
				switch response {
				case NSApplication.ModalResponse.alertFirstButtonReturn:
					self.reloadCheats()
					self.close()
					
				case NSApplication.ModalResponse.alertThirdButtonReturn:
					break
					
				case NSApplication.ModalResponse.alertSecondButtonReturn:
					self.refreshCheatArray()
					self.close()
					
				default:
					break
				}
			})
			return false
		}
	}
	
	@IBAction func removeCheats(_ sender: AnyObject?) {
		if cheatView.selectedRow < 0 {
			NSSound.beep()
			return
		}
		
		let toRemoveIndex = cheatView.selectedRowIndexes
		willChange(.removal, valuesAt: toRemoveIndex, forKey: kCheatsName)
		cheats.remove(indexes: toRemoveIndex)
		didChange(.removal, valuesAt: toRemoveIndex, forKey: kCheatsName)
		setDocumentEdited(true)
	}
}
