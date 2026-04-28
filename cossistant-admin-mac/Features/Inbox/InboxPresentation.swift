import Foundation
import CossistantAdmin

enum InboxSortMode: String, CaseIterable, Identifiable, Sendable {
  case latestActivity
  case priority
  case sentiment
  case createdAt

  var id: String { rawValue }

  var label: String {
    switch self {
    case .latestActivity:
      "Latest Activity"
    case .priority:
      "Priority"
    case .sentiment:
      "Sentiment"
    case .createdAt:
      "Created"
    }
  }
}

enum InboxPriorityFilter: String, CaseIterable, Identifiable, Sendable {
  case all
  case low
  case normal
  case high
  case urgent

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      "Any Priority"
    case .low:
      "Low"
    case .normal:
      "Normal"
    case .high:
      "High"
    case .urgent:
      "Urgent"
    }
  }

  func includes(_ priority: DashboardConversation.Priority) -> Bool {
    switch self {
    case .all:
      true
    case .low:
      priority == .low
    case .normal:
      priority == .normal
    case .high:
      priority == .high
    case .urgent:
      priority == .urgent
    }
  }
}

enum InboxSentimentFilter: String, CaseIterable, Identifiable, Sendable {
  case all
  case positive
  case neutral
  case negative
  case unknown

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      "Any Sentiment"
    case .positive:
      "Positive"
    case .neutral:
      "Neutral"
    case .negative:
      "Negative"
    case .unknown:
      "Unknown"
    }
  }

  func includes(_ sentiment: DashboardConversationSentiment) -> Bool {
    switch self {
    case .all:
      true
    case .positive:
      sentiment == .positive
    case .neutral:
      sentiment == .neutral
    case .negative:
      sentiment == .negative
    case .unknown:
      sentiment == .unknown
    }
  }
}

enum InboxMetadataFilterKey: String, CaseIterable, Identifiable, Sendable {
  case source
  case category

  var id: String { rawValue }

  var label: String {
    rawValue.capitalized
  }
}

struct InboxMetadataFilterOption: Identifiable, Hashable, Sendable {
  let key: InboxMetadataFilterKey
  let value: JSONValue

  var id: String {
    "\(key.rawValue):\(value.dashboardPrettyPrintedJSONString ?? value.dashboardDisplayText)"
  }

  var label: String {
    value.dashboardDisplayText
  }
}

struct InboxMetadataFilterSection: Identifiable, Hashable, Sendable {
  let key: InboxMetadataFilterKey
  let options: [InboxMetadataFilterOption]

  var id: String { key.rawValue }
  var label: String { key.label }
}

struct InboxChannelFilterOption: Identifiable, Hashable, Sendable {
  let value: String

  var id: String { value }

  var label: String {
    value.replacingOccurrences(of: "_", with: " ").capitalized
  }
}
