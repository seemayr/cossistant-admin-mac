import Foundation
import CossistantAdmin

enum AIWorkflowFormatting {
  static func senderLabel(for item: DashboardTimelineItem) -> String {
    if item.visitorId != nil {
      return "Visitor"
    }

    if item.userId != nil {
      return "Admin"
    }

    if item.aiAgentId != nil {
      return "Agent"
    }

    return "System"
  }

  static func indentedMarkdownText(
    _ text: String,
    indentation: String
  ) -> String {
    text
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { "\(indentation)\($0)" }
      .joined(separator: "\n")
  }

  static func markdownAttachmentSummary(for item: DashboardTimelineItem) -> String? {
    let imageCount = item.imageParts.count
    let fileCount = item.fileParts.count
    let parts = [
      imageCount > 0 ? "\(imageCount) image attachment\(imageCount == 1 ? "" : "s") added" : nil,
      fileCount > 0 ? "\(fileCount) file attachment\(fileCount == 1 ? "" : "s") added" : nil,
    ].compactMap { $0 }

    guard !parts.isEmpty else { return nil }
    return parts.joined(separator: " • ")
  }
}
