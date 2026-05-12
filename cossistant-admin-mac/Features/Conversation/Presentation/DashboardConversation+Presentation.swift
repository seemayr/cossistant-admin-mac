import SwiftUI
import SFSafeSymbols
import CossistantAdmin

extension DashboardConversation.Status {
  var tint: Color {
    switch self {
    case .open:
      .green
    case .resolved:
      .secondary
    case .spam:
      .red
    }
  }
}

extension DashboardConversation.Priority {
  var tint: Color {
    switch self {
    case .low:
      .secondary
    case .normal:
      .blue
    case .high:
      .orange
    case .urgent:
      .red
    }
  }
}

extension DashboardConversation {
  func displayTitle(showBackendTranslatedSubjects: Bool) -> String {
    if !showBackendTranslatedSubjects,
       titleSource == "ai",
       let visitorTitle = visitorTitle?.nilIfEmpty {
      return visitorTitle
    }

    return displayTitle
  }

  var attentionWaitingTint: Color {
    guard let attentionWaitingDuration else { return .orange }

    switch attentionWaitingDuration {
    case ..<TimeInterval(24 * 60 * 60):
      return .orange
    case ..<TimeInterval(72 * 60 * 60):
      return .yellow
    default:
      return .red
    }
  }

  var visitorWaitingTint: Color {
    guard let visitorWaitingDuration else { return .orange }

    switch visitorWaitingDuration {
    case ..<TimeInterval(24 * 60 * 60):
      return .orange
    case ..<TimeInterval(72 * 60 * 60):
      return .yellow
    default:
      return .red
    }
  }

  var visitorWaitingSinceDate: Date? {
    guard status == .open,
          lastMessageTimelineItem?.visitorId != nil else {
      return nil
    }

    if let createdAt = lastMessageTimelineItem?.createdAt,
       let createdAtDate = DashboardTimestampParser.date(from: createdAt) {
      return createdAtDate
    }

    return lastMessageAtDate
  }

  var visitorWaitingDuration: TimeInterval? {
    guard let visitorWaitingSinceDate else { return nil }
    return max(0, Date.now.timeIntervalSince(visitorWaitingSinceDate))
  }

  var showsVisitorWaitingBadge: Bool {
    guard let visitorWaitingDuration else { return false }
    return visitorWaitingDuration >= 2 * 24 * 60 * 60
  }

  var visitorWaitingLabel: String? {
    guard let visitorWaitingDuration, showsVisitorWaitingBadge else {
      return nil
    }

    let hours = Int(visitorWaitingDuration / 3600)
    if hours < 24 {
      return "Waiting \(hours)h"
    }

    let days = hours / 24
    return "Waiting \(days)d"
  }

  var statusBadgeSymbol: SFSymbol? {
    switch status {
    case .open:
      return nil
    case .resolved:
      return .checkmark
    case .spam:
      return nil
    }
  }

  var statusBadgeTint: Color {
    status.tint
  }

  var priorityIndicatorSymbol: SFSymbol? {
    switch priority {
    case .low:
      return .arrowDown
    case .normal:
      return nil
    case .high:
      return .arrowUp
    case .urgent:
      return .exclamationmark
    }
  }

  var priorityIndicatorTint: Color {
    switch priority {
    case .low:
      return .secondary
    case .normal:
      return .secondary
    case .high:
      return .orange
    case .urgent:
      return .red
    }
  }

  var platformIndicatorSymbol: SFSymbol? {
    switch normalizedChannel {
    case "android":
      return .aCircleFill
    case "apple", "ios":
      return .appleLogo
    default:
      return nil
    }
  }

  var platformIndicatorLabel: String? {
    switch normalizedChannel {
    case "android":
      return "Android"
    case "apple", "ios":
      return "Apple"
    default:
      return nil
    }
  }

  var platformIndicatorTint: Color {
    switch normalizedChannel {
    case "android":
      return .green
    case "apple", "ios":
      return .secondary
    default:
      return .secondary
    }
  }

  var appVersionIndicatorText: String? {
    Self.appVersionMetadataKeys
      .lazy
      .compactMap(metadataText)
      .first
  }

  private var normalizedChannel: String {
    channel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private func metadataText(forKey key: String) -> String? {
    guard let value = metadata?[key], value != .null else { return nil }

    let trimmedValue = value.dashboardDisplayText.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedValue.isEmpty ? nil : trimmedValue
  }

  private static let appVersionMetadataKeys = [
    "appVersion",
    "app_version",
    "version",
    "versionName",
    "appVersionName",
    "app_version_name",
    "clientVersion",
    "client_version",
  ]
}

extension DashboardConversationDetail {
  func displayTitle(
    fallback conversation: DashboardConversation,
    showBackendTranslatedSubjects: Bool
  ) -> String {
    if !showBackendTranslatedSubjects,
       conversation.titleSource == "ai",
       let visitorTitle = (visitorTitle ?? conversation.visitorTitle)?.nilIfEmpty {
      return visitorTitle
    }

    return title?.nilIfEmpty ?? conversation.displayTitle(showBackendTranslatedSubjects: showBackendTranslatedSubjects)
  }
}
