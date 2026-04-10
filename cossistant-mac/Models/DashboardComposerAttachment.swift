import AppKit
import Foundation
import UniformTypeIdentifiers

struct DashboardComposerAttachment: Identifiable, Hashable, Sendable {
  let id: UUID
  let data: Data
  let fileName: String
  let contentType: String

  init(
    id: UUID = UUID(),
    data: Data,
    fileName: String,
    contentType: String
  ) {
    self.id = id
    self.data = data
    self.fileName = fileName
    self.contentType = contentType
  }

  var isImage: Bool {
    contentType.hasPrefix("image/")
  }

  var fileSizeBytes: Int {
    data.count
  }

  var formattedSize: String {
    ByteCountFormatter.string(fromByteCount: Int64(fileSizeBytes), countStyle: .file)
  }

  var thumbnailImage: NSImage? {
    guard isImage else { return nil }
    return NSImage(data: data)
  }
}

enum DashboardAttachmentValidationError: LocalizedError {
  case fileTooLarge(fileName: String, maxMB: Int)
  case unsupportedType(fileName: String)
  case tooManyFiles(max: Int)
  case unreadableFile(fileName: String)

  var errorDescription: String? {
    switch self {
    case .fileTooLarge(let fileName, let maxMB):
      "\(fileName) is too large. Maximum size is \(maxMB) MB."
    case .unsupportedType(let fileName):
      "\(fileName) is not a supported file type."
    case .tooManyFiles(let max):
      "You can attach up to \(max) files per message."
    case .unreadableFile(let fileName):
      "Could not read \(fileName)."
    }
  }
}

enum DashboardUploadConstants {
  static let maxFileSizeBytes = 5 * 1024 * 1024
  static let maxFilesPerMessage = 3

  static let allowedMIMETypes: Set<String> = [
    "image/jpeg", "image/png", "image/gif", "image/webp",
    "application/pdf",
    "text/plain", "text/csv", "text/markdown",
    "application/zip",
  ]

  static var importableTypes: [UTType] {
    var types: [UTType] = [
      .jpeg, .png, .gif, .pdf, .plainText, .commaSeparatedText, .zip
    ]

    if let webP = UTType(mimeType: "image/webp") {
      types.append(webP)
    }

    if let markdown = UTType(filenameExtension: "md") {
      types.append(markdown)
    }

    return types
  }

  static func validate(_ attachment: DashboardComposerAttachment) -> DashboardAttachmentValidationError? {
    if attachment.fileSizeBytes > maxFileSizeBytes {
      return .fileTooLarge(
        fileName: attachment.fileName,
        maxMB: maxFileSizeBytes / (1024 * 1024)
      )
    }

    if !allowedMIMETypes.contains(attachment.contentType) {
      return .unsupportedType(fileName: attachment.fileName)
    }

    return nil
  }
}
