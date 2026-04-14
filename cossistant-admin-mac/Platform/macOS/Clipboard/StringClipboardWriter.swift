import AppKit
import Foundation
import CossistantAdmin

enum StringClipboardWriter {
  static func copy(_ string: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
  }
}
