import Foundation

struct DashboardConversationPage: Decodable, Sendable {
  let items: [DashboardConversation]
  let nextCursor: String?
}

struct DashboardConversation: Identifiable, Decodable, Hashable, Sendable {
  struct Clarification: Decodable, Hashable, Sendable {
    let requestId: String
    let status: String
    let question: String?
    let updatedAt: String
  }

  struct Visitor: Decodable, Hashable, Sendable {
    struct Contact: Decodable, Hashable, Sendable {
      let id: String
      let name: String?
      let email: String?
      let image: URL?
      let metadata: DashboardMetadata?
    }

    let id: String
    let lastSeenAt: String?
    let isBlocked: Bool
    let contact: Contact?
  }

  struct TimelineItem: Decodable, Hashable, Sendable {
    let id: String?
    let type: String
    let text: String?
    let parts: [DashboardTimelinePart]
    let userId: String?
    let aiAgentId: String?
    let visitorId: String?
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
      case id
      case type
      case text
      case parts
      case userId
      case aiAgentId
      case visitorId
      case createdAt
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try container.decodeIfPresent(String.self, forKey: .id)
      type = try container.decode(String.self, forKey: .type)
      text = try container.decodeIfPresent(String.self, forKey: .text)
      parts = try container.decodeIfPresent([DashboardTimelinePart].self, forKey: .parts) ?? []
      userId = try container.decodeIfPresent(String.self, forKey: .userId)
      aiAgentId = try container.decodeIfPresent(String.self, forKey: .aiAgentId)
      visitorId = try container.decodeIfPresent(String.self, forKey: .visitorId)
      createdAt = try container.decode(String.self, forKey: .createdAt)
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

      guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
      }

      return text
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

    var eventPreviewText: String? {
      if let message = eventPart?.message, !message.isEmpty {
        return message
      }

      guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
      }

      return text
    }

    var previewText: String {
      if let renderedText {
        return renderedText
      }

      if type == "event", let eventPreviewText {
        return eventPreviewText
      }

      if let attachmentSummary {
        return attachmentSummary
      }

      return "No message content yet."
    }
  }

  enum Status: String, Decodable, Hashable, Sendable {
    case open
    case resolved
    case spam

    var label: String {
      rawValue.capitalized
    }
  }

  enum Priority: String, Decodable, Hashable, Sendable {
    case low
    case normal
    case high
    case urgent

    var label: String {
      rawValue.capitalized
    }
  }

  let id: String
  let status: Status
  let priority: Priority
  let organizationId: String
  let visitorId: String
  let visitor: Visitor
  let websiteId: String
  let metadata: DashboardMetadata?
  let channel: String
  let title: String?
  let sentiment: String?
  let sentimentConfidence: Double?
  let visitorRating: Int?
  let createdAt: String
  let updatedAt: String
  let deletedAt: String?
  let lastMessageAt: String?
  let lastSeenAt: String?
  let teamLastSeenAt: String?
  let escalatedAt: String?
  let escalationHandledAt: String?
  let aiPausedUntil: String?
  let lastMessageTimelineItem: TimelineItem?
  let lastTimelineItem: TimelineItem?
  let activeClarification: Clarification?
  let dashboardLocked: Bool?
  let dashboardLockReason: String?

  var displayTitle: String {
    resolvedTitle
  }

  var resolvedTitle: String {
    if let title, !title.isEmpty {
      return title
    }

    return "Untitled conversation"
  }

  var visitorDisplayName: String {
    DashboardIdentity.visitorDisplayName(
      contactName: visitor.contact?.name,
      email: visitor.contact?.email,
      visitorID: visitor.id
    )
  }

  var visitorSecondaryLine: String {
    if let email = visitor.contact?.email, !email.isEmpty {
      return email
    }

    return "Visitor \(visitor.id.suffix(6))"
  }

  var visitorShortID: String {
    String(visitor.id.prefix(4))
  }

  var showsVisitorIDInSecondaryLine: Bool {
    if let email = visitor.contact?.email, !email.isEmpty {
      return false
    }

    return true
  }

  var previewText: String {
    if let lastMessageTimelineItem {
      return lastMessageTimelineItem.previewText
    }

    if let lastTimelineItem {
      return lastTimelineItem.previewText
    }

    return "No message content yet."
  }

  var hasContent: Bool {
    lastMessageTimelineItem != nil
  }

  var updatedAtDate: Date? {
    DashboardTimestampParser.date(from: updatedAt)
  }

  var createdAtDate: Date? {
    DashboardTimestampParser.date(from: createdAt)
  }

  var lastMessageAtDate: Date? {
    guard let lastMessageAt else { return nil }
    return DashboardTimestampParser.date(from: lastMessageAt)
  }

  var lastSeenAtDate: Date? {
    guard let lastSeenAt else { return nil }
    return DashboardTimestampParser.date(from: lastSeenAt)
  }

  var teamLastSeenAtDate: Date? {
    guard let teamLastSeenAt else { return nil }
    return DashboardTimestampParser.date(from: teamLastSeenAt)
  }

  var latestMessageWasSentByHumanTeammate: Bool {
    lastMessageTimelineItem?.userId != nil
  }

  var effectiveSeenDate: Date? {
    [lastSeenAtDate, teamLastSeenAtDate]
      .compactMap { $0 }
      .max()
  }

  var latestActivityDate: Date {
    lastMessageAtDate ?? updatedAtDate ?? createdAtDate ?? .distantPast
  }

  var isArchived: Bool {
    deletedAt != nil
  }

  var hasUnreadActivity: Bool {
    guard hasContent else { return false }
    if latestMessageWasSentByHumanTeammate {
      return false
    }

    guard let effectiveSeenDate else { return true }
    return latestActivityDate > effectiveSeenDate
  }

  var isSeenByTeam: Bool {
    !hasUnreadActivity
  }

  var createdRelativeText: String {
    guard let createdAtDate else { return createdAt }
    return Self.relativeFormatter.localizedString(for: createdAtDate, relativeTo: .now)
  }

  var lastActivityRelativeText: String {
    let referenceDate = lastMessageAtDate ?? updatedAtDate ?? createdAtDate
    guard let referenceDate else { return updatedAt }
    return Self.relativeFormatter.localizedString(for: referenceDate, relativeTo: .now)
  }

  var needsHumanIntervention: Bool {
    escalatedAt != nil && escalationHandledAt == nil
  }

  var needsClarification: Bool {
    activeClarification != nil && !needsHumanIntervention
  }

  var attentionWaitingSinceDate: Date? {
    guard status == .open else { return nil }

    if needsHumanIntervention, let escalatedAt {
      return DashboardTimestampParser.date(from: escalatedAt)
    }

    if needsClarification, let updatedAt = activeClarification?.updatedAt {
      return DashboardTimestampParser.date(from: updatedAt)
    }

    return nil
  }

  var attentionWaitingDuration: TimeInterval? {
    guard let attentionWaitingSinceDate else { return nil }
    return max(0, Date.now.timeIntervalSince(attentionWaitingSinceDate))
  }

  var showsAttentionWaitingBadge: Bool {
    guard let attentionWaitingDuration else { return false }
    return attentionWaitingDuration >= 10 * 60 * 60
  }

  var attentionWaitingLabel: String? {
    guard let attentionWaitingDuration, showsAttentionWaitingBadge else {
      return nil
    }

    let hours = Int(attentionWaitingDuration / 3600)
    if hours < 24 {
      return "Waiting \(hours)h"
    }

    let days = hours / 24
    return "Waiting \(days)d"
  }

  var showsPriorityIndicator: Bool {
    priority != .normal
  }

  var sentimentCategory: DashboardConversationSentiment {
    guard let sentiment,
          let category = DashboardConversationSentiment(rawValue: sentiment) else {
      return .unknown
    }

    return category
  }

  var sentimentSortRank: Int {
    switch sentimentCategory {
    case .negative:
      3
    case .neutral:
      2
    case .positive:
      1
    case .unknown:
      0
    }
  }

  var channelLabel: String {
    channel.replacingOccurrences(of: "_", with: " ").capitalized
  }

  var sentimentSummary: String {
    [
      sentiment?.capitalized,
      sentimentConfidence.map {
        "Confidence \($0.formatted(.number.precision(.fractionLength(2))))"
      },
    ]
      .compactMap { $0 }
      .joined(separator: " • ")
      .dashboardFallback("Not available yet")
  }

  var ratingSummary: String {
    [
      visitorRating.map { "Visitor rating \($0)/5" },
      (dashboardLocked ?? false)
        ? "Dashboard locked: \(dashboardLockReason ?? "conversation_limit")"
        : "Dashboard access available",
    ]
      .compactMap { $0 }
      .joined(separator: " • ")
  }

  var visitorAvatarURL: URL? {
    visitor.contact?.image
  }

  var visitorAvatarSeed: String {
    visitor.contact?.email ?? visitor.id
  }

  func withLastSeenAt(_ value: String?) -> DashboardConversation {
    DashboardConversation(
      id: id,
      status: status,
      priority: priority,
      organizationId: organizationId,
      visitorId: visitorId,
      visitor: visitor,
      websiteId: websiteId,
      metadata: metadata,
      channel: channel,
      title: title,
      sentiment: sentiment,
      sentimentConfidence: sentimentConfidence,
      visitorRating: visitorRating,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      lastMessageAt: lastMessageAt,
      lastSeenAt: value,
      teamLastSeenAt: teamLastSeenAt,
      escalatedAt: escalatedAt,
      escalationHandledAt: escalationHandledAt,
      aiPausedUntil: aiPausedUntil,
      lastMessageTimelineItem: lastMessageTimelineItem,
      lastTimelineItem: lastTimelineItem,
      activeClarification: activeClarification,
      dashboardLocked: dashboardLocked,
      dashboardLockReason: dashboardLockReason
    )
  }

  func withTeamLastSeenAt(_ value: String?) -> DashboardConversation {
    DashboardConversation(
      id: id,
      status: status,
      priority: priority,
      organizationId: organizationId,
      visitorId: visitorId,
      visitor: visitor,
      websiteId: websiteId,
      metadata: metadata,
      channel: channel,
      title: title,
      sentiment: sentiment,
      sentimentConfidence: sentimentConfidence,
      visitorRating: visitorRating,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      lastMessageAt: lastMessageAt,
      lastSeenAt: lastSeenAt,
      teamLastSeenAt: value,
      escalatedAt: escalatedAt,
      escalationHandledAt: escalationHandledAt,
      aiPausedUntil: aiPausedUntil,
      lastMessageTimelineItem: lastMessageTimelineItem,
      lastTimelineItem: lastTimelineItem,
      activeClarification: activeClarification,
      dashboardLocked: dashboardLocked,
      dashboardLockReason: dashboardLockReason
    )
  }

  var priorityRank: Int {
    switch priority {
    case .urgent:
      4
    case .high:
      3
    case .normal:
      2
    case .low:
      1
    }
  }

  private static let relativeFormatter = RelativeDateTimeFormatter.dashboard
}

private extension String {
  func dashboardFallback(_ fallback: String) -> String {
    isEmpty ? fallback : self
  }
}

extension ISO8601DateFormatter {
  static let withFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  static let internetDateTime: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()
}

extension RelativeDateTimeFormatter {
  static let dashboard: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter
  }()
}
