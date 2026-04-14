import AppKit
import CossistantAdmin

extension DashboardComposerAttachment {
  var thumbnailImage: NSImage? {
    guard isImage else { return nil }
    return NSImage(data: data)
  }
}
