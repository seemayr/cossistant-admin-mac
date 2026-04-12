import Foundation

struct DashboardTimelinePage: Decodable, Sendable {
  let items: [DashboardTimelineItem]
  let nextCursor: String?
  let hasNextPage: Bool
}

enum DashboardTimelineItemVisibility: String, Codable, Hashable, Sendable {
  case `public`
  case `private`

  var label: String {
    switch self {
    case .public:
      "Public"
    case .private:
      "Private"
    }
  }
}

enum DashboardTimelineItemType: String, Codable, Hashable, Sendable {
  case message
  case event
  case identification
  case tool
}

enum DashboardToolTimelineLogType: String, Codable, Hashable, Sendable {
  case customerFacing = "customer_facing"
  case log
  case decision
}

struct DashboardTimelineItem: Identifiable, Decodable, Hashable, Sendable {
  let id: String
  let conversationId: String
  let organizationId: String
  let visibility: DashboardTimelineItemVisibility
  let type: DashboardTimelineItemType
  let text: String?
  let tool: String?
  let parts: [DashboardTimelinePart]
  let userId: String?
  let aiAgentId: String?
  let visitorId: String?
  let createdAt: String
  let deletedAt: String?

  enum CodingKeys: String, CodingKey {
    case id
    case conversationId
    case organizationId
    case visibility
    case type
    case text
    case tool
    case parts
    case userId
    case aiAgentId
    case visitorId
    case createdAt
    case deletedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    conversationId = try container.decode(String.self, forKey: .conversationId)
    organizationId = try container.decode(String.self, forKey: .organizationId)
    visibility = try container.decode(DashboardTimelineItemVisibility.self, forKey: .visibility)
    type = try container.decode(DashboardTimelineItemType.self, forKey: .type)
    text = try container.decodeIfPresent(String.self, forKey: .text)
    tool = try container.decodeIfPresent(String.self, forKey: .tool)
    parts = try container.decodeIfPresent([DashboardTimelinePart].self, forKey: .parts) ?? []
    userId = try container.decodeIfPresent(String.self, forKey: .userId)
    aiAgentId = try container.decodeIfPresent(String.self, forKey: .aiAgentId)
    visitorId = try container.decodeIfPresent(String.self, forKey: .visitorId)
    createdAt = try container.decode(String.self, forKey: .createdAt)
    deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
  }

  var createdAtDate: Date? {
    DashboardTimestampParser.date(from: createdAt)
  }

  var createdRelativeText: String {
    guard let createdAtDate else { return createdAt }
    return RelativeDateTimeFormatter.dashboard.localizedString(for: createdAtDate, relativeTo: .now)
  }

  var createdTimeText: String {
    guard let createdAtDate else { return createdAt }
    return createdAtDate.formatted(.dateTime.hour().minute())
  }

  var textParts: [DashboardTimelineTextPart] {
    parts.compactMap {
      guard case .text(let part) = $0 else { return nil }
      return part
    }
  }

  var fileParts: [DashboardTimelineFilePart] {
    parts.compactMap {
      guard case .file(let part) = $0 else { return nil }
      return part
    }
  }

  var imageParts: [DashboardTimelineImagePart] {
    parts.compactMap {
      guard case .image(let part) = $0 else { return nil }
      return part
    }
  }

  var metadataParts: [DashboardTimelineMetadataPart] {
    parts.compactMap {
      guard case .metadata(let part) = $0 else { return nil }
      return part
    }
  }

  var toolPart: DashboardTimelineToolPart? {
    parts.first {
      guard case .tool = $0 else { return false }
      return true
    }.flatMap {
      guard case .tool(let part) = $0 else { return nil }
      return part
    }
  }

  var eventPart: DashboardTimelineEventPart? {
    parts.first {
      guard case .event = $0 else { return false }
      return true
    }.flatMap {
      guard case .event(let part) = $0 else { return nil }
      return part
    }
  }

  var renderedText: String? {
    let collectedText = textParts
      .map(\.text)
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .joined(separator: "\n\n")

    if !collectedText.isEmpty {
      return collectedText
    }

    if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return text
    }

    return nil
  }

  var previewText: String {
    if let renderedText {
      return renderedText
    }

    if let eventPreviewText {
      return eventPreviewText
    }

    if let toolSummary {
      return toolSummary
    }

    if !imageParts.isEmpty {
      return "\(imageParts.count) image\(imageParts.count == 1 ? "" : "s")"
    }

    if !fileParts.isEmpty {
      return "\(fileParts.count) file\(fileParts.count == 1 ? "" : "s")"
    }

    return "No text payload"
  }

  var sourceLabel: String? {
    guard let source = metadataParts.first?.source else { return nil }
    return source.replacingOccurrences(of: "_", with: " ").capitalized
  }

  var toolDisplayName: String? {
    if let toolName = toolPart?.toolName, !toolName.isEmpty {
      return Self.humanizeToolName(toolName)
    }

    guard let tool, !tool.isEmpty else { return nil }
    return Self.humanizeToolName(tool)
  }

  var toolSummary: String? {
    if let text, !text.isEmpty {
      return text
    }

    if let progressMessage = toolPart?.progressMessage, !progressMessage.isEmpty {
      return progressMessage
    }

    return toolDisplayName
  }

  var toolLogType: DashboardToolTimelineLogType {
    if let metadataType = toolPart?.toolTimelineMetadata?.logType {
      return metadataType
    }

    return .log
  }

  var isCustomerFacingTool: Bool {
    type == .tool && toolLogType == .customerFacing
  }

  var isDeveloperLog: Bool {
    type == .tool && toolLogType != .customerFacing
  }

  var isPrivateNote: Bool {
    type == .message && visibility == .private
  }

  var eventPreviewText: String? {
    if let message = eventPart?.message, !message.isEmpty {
      return message
    }

    if let text, !text.isEmpty {
      return text
    }

    guard let eventPart else { return nil }
    return Self.defaultEventText(for: eventPart.eventType)
  }

  var attachmentSummary: String? {
    let imageCount = imageParts.count
    let fileCount = fileParts.count
    let parts = [
      imageCount > 0 ? "\(imageCount) image\(imageCount == 1 ? "" : "s")" : nil,
      fileCount > 0 ? "\(fileCount) file\(fileCount == 1 ? "" : "s")" : nil,
    ].compactMap { $0 }

    guard !parts.isEmpty else { return nil }
    return parts.joined(separator: " • ")
  }

  static func humanizeToolName(_ rawValue: String) -> String {
    let withSeparators = rawValue
      .unicodeScalars
      .enumerated()
      .reduce(into: "") { result, entry in
        let (index, scalar) = entry
        let character = Character(scalar)

        if character == "-" || character == "_" {
          result.append(" ")
          return
        }

        if index > 0, CharacterSet.uppercaseLetters.contains(scalar) {
          result.append(" ")
        }

        result.append(character)
      }

    return withSeparators
      .split(whereSeparator: \.isWhitespace)
      .map { $0.capitalized }
      .joined(separator: " ")
  }

  static func defaultEventText(for eventType: String) -> String {
    switch eventType {
    case "assigned":
      "Assigned the conversation"
    case "unassigned":
      "Unassigned the conversation"
    case "participant_requested":
      "Requested a team member to join"
    case "participant_joined":
      "Joined the conversation"
    case "participant_left":
      "Left the conversation"
    case "status_changed":
      "Changed the status"
    case "priority_changed":
      "Changed the priority"
    case "tag_added":
      "Added a tag"
    case "tag_removed":
      "Removed a tag"
    case "resolved":
      "Resolved the conversation"
    case "reopened":
      "Reopened the conversation"
    case "visitor_blocked":
      "Blocked the visitor"
    case "visitor_unblocked":
      "Unblocked the visitor"
    case "visitor_identified":
      "Identified the visitor"
    case "ai_paused":
      "Paused AI answers"
    case "ai_resumed":
      "Resumed AI answers"
    default:
      eventType.replacingOccurrences(of: "_", with: " ").capitalized
    }
  }
}

extension DashboardTimelineItem: Encodable {
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(conversationId, forKey: .conversationId)
    try container.encode(organizationId, forKey: .organizationId)
    try container.encode(visibility, forKey: .visibility)
    try container.encode(type, forKey: .type)
    try container.encodeIfPresent(text, forKey: .text)
    try container.encodeIfPresent(tool, forKey: .tool)
    try container.encode(parts, forKey: .parts)
    try container.encodeIfPresent(userId, forKey: .userId)
    try container.encodeIfPresent(aiAgentId, forKey: .aiAgentId)
    try container.encodeIfPresent(visitorId, forKey: .visitorId)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
  }
}

enum DashboardTimelinePart: Hashable, Sendable {
  case text(DashboardTimelineTextPart)
  case reasoning(DashboardTimelineReasoningPart)
  case tool(DashboardTimelineToolPart)
  case sourceURL(DashboardTimelineSourceURLPart)
  case sourceDocument(DashboardTimelineSourceDocumentPart)
  case stepStart
  case file(DashboardTimelineFilePart)
  case image(DashboardTimelineImagePart)
  case event(DashboardTimelineEventPart)
  case metadata(DashboardTimelineMetadataPart)
  case unknown(DashboardTimelineUnknownPart)
}

extension DashboardTimelinePart: Decodable {
  private enum CodingKeys: String, CodingKey {
    case type
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "text":
      self = .text(try DashboardTimelineTextPart(from: decoder))
    case "reasoning":
      self = .reasoning(try DashboardTimelineReasoningPart(from: decoder))
    case "source-url":
      self = .sourceURL(try DashboardTimelineSourceURLPart(from: decoder))
    case "source-document":
      self = .sourceDocument(try DashboardTimelineSourceDocumentPart(from: decoder))
    case "step-start":
      self = .stepStart
    case "file":
      self = .file(try DashboardTimelineFilePart(from: decoder))
    case "image":
      self = .image(try DashboardTimelineImagePart(from: decoder))
    case "event":
      self = .event(try DashboardTimelineEventPart(from: decoder))
    case "metadata":
      self = .metadata(try DashboardTimelineMetadataPart(from: decoder))
    default:
      if type.hasPrefix("tool-") {
        self = .tool(try DashboardTimelineToolPart(from: decoder))
      } else {
        self = .unknown(try DashboardTimelineUnknownPart(from: decoder))
      }
    }
  }
}

extension DashboardTimelinePart: Encodable {
  func encode(to encoder: Encoder) throws {
    switch self {
    case .text(let part):
      try part.encode(to: encoder)
    case .reasoning(let part):
      try part.encode(to: encoder)
    case .tool(let part):
      try part.encode(to: encoder)
    case .sourceURL(let part):
      try part.encode(to: encoder)
    case .sourceDocument(let part):
      try part.encode(to: encoder)
    case .stepStart:
      var container = encoder.container(keyedBy: DashboardTimelinePartCodingKeys.self)
      try container.encode("step-start", forKey: .type)
    case .file(let part):
      try part.encode(to: encoder)
    case .image(let part):
      try part.encode(to: encoder)
    case .event(let part):
      try part.encode(to: encoder)
    case .metadata(let part):
      try part.encode(to: encoder)
    case .unknown(let part):
      try part.encode(to: encoder)
    }
  }
}

private enum DashboardTimelinePartCodingKeys: String, CodingKey {
  case type
}

struct DashboardTimelineTextPart: Codable, Hashable, Sendable {
  let type: String
  let text: String
  let state: String?
}

struct DashboardTimelineReasoningPart: Codable, Hashable, Sendable {
  let type: String
  let text: String
  let state: String?
}

struct DashboardTimelineSourceURLPart: Codable, Hashable, Sendable {
  let type: String
  let sourceId: String
  let url: String
  let title: String?
}

struct DashboardTimelineSourceDocumentPart: Codable, Hashable, Sendable {
  let type: String
  let sourceId: String
  let mediaType: String
  let title: String
  let filename: String?
}

struct DashboardTimelineFilePart: Codable, Hashable, Sendable {
  let type: String
  let url: String
  let mediaType: String
  let filename: String?
  let size: Int?
}

struct DashboardTimelineImagePart: Codable, Hashable, Sendable {
  let type: String
  let url: String
  let mediaType: String
  let filename: String?
  let size: Int?
  let width: Int?
  let height: Int?
}

struct DashboardTimelineEventPart: Codable, Hashable, Sendable {
  let type: String
  let eventType: String
  let actorUserId: String?
  let actorAiAgentId: String?
  let targetUserId: String?
  let targetAiAgentId: String?
  let message: String?
}

struct DashboardTimelineMetadataPart: Codable, Hashable, Sendable {
  let type: String
  let source: String
}

struct DashboardTimelineToolPart: Codable, Hashable, Sendable {
  let type: String
  let toolCallId: String
  let toolName: String
  let input: [String: JSONValue]?
  let output: JSONValue?
  let state: String
  let errorText: String?
  let callProviderMetadata: DashboardTimelineProviderMetadata?
  let providerMetadata: DashboardTimelineProviderMetadata?

  var progressMessage: String? {
    callProviderMetadata?.cossistant?.progressMessage
      ?? providerMetadata?.cossistant?.progressMessage
  }

  var toolTimelineMetadata: DashboardTimelineToolMetadata? {
    callProviderMetadata?.cossistant?.toolTimeline
      ?? providerMetadata?.cossistant?.toolTimeline
  }
}

struct DashboardTimelineProviderMetadata: Codable, Hashable, Sendable {
  let cossistant: DashboardTimelineCossistantMetadata?
}

struct DashboardTimelineCossistantMetadata: Codable, Hashable, Sendable {
  let visibility: DashboardTimelineItemVisibility?
  let progressMessage: String?
  let knowledgeId: String?
  let toolTimeline: DashboardTimelineToolMetadata?
}

struct DashboardTimelineToolMetadata: Codable, Hashable, Sendable {
  let logType: DashboardToolTimelineLogType?
  let triggerMessageId: String?
  let workflowRunId: String?
  let triggerVisibility: DashboardTimelineItemVisibility?
}

struct DashboardTimelineUnknownPart: Decodable, Hashable, Sendable {
  let type: String
  let payload: [String: JSONValue]

  private enum CodingKeys: String, CodingKey {
    case type
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    payload = try container.decode([String: JSONValue].self)
    type = payload["type"]?.stringValue ?? "unknown"
  }
}

extension DashboardTimelineUnknownPart: Encodable {
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(payload)
  }
}

private extension JSONValue {
  var stringValue: String? {
    guard case .string(let value) = self else { return nil }
    return value
  }
}
