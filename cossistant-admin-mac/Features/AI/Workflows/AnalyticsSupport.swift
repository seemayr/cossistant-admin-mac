import Foundation
import CossistantAdmin

enum AnalyticsSummaryRangeMode: String, CaseIterable, Identifiable, Sendable {
  case lastHours
  case lastDays
  case custom

  var id: String {
    rawValue
  }

  var label: String {
    switch self {
    case .lastHours:
      "Last Hours"
    case .lastDays:
      "Last Days"
    case .custom:
      "Custom Range"
    }
  }
}

enum AnalyticsSummaryStatusFilter: String, CaseIterable, Identifiable, Sendable {
  case all
  case open
  case resolved
  case spam

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      "Any Status"
    case .open:
      "Open"
    case .resolved:
      "Resolved"
    case .spam:
      "Spam"
    }
  }

  func includes(_ status: DashboardConversation.Status) -> Bool {
    switch self {
    case .all:
      true
    case .open:
      status == .open
    case .resolved:
      status == .resolved
    case .spam:
      status == .spam
    }
  }
}

struct AnalyticsSummaryDateRange: Sendable {
  let start: Date
  let end: Date

  var label: String {
    "\(start.formatted(.dateTime.year().month().day().hour().minute())) → \(end.formatted(.dateTime.year().month().day().hour().minute()))"
  }
}

enum AnalyticsSummaryChatRole: String, Sendable {
  case assistant
  case user
}

struct AnalyticsSummaryChatMessage: Identifiable, Hashable, Sendable {
  let id: UUID
  let role: AnalyticsSummaryChatRole
  let text: String
  let createdAt: Date

  init(
    id: UUID = UUID(),
    role: AnalyticsSummaryChatRole,
    text: String,
    createdAt: Date = .now
  ) {
    self.id = id
    self.role = role
    self.text = text
    self.createdAt = createdAt
  }
}

struct AnalyticsConversationSection: Sendable {
  let markdown: String
  let messageCount: Int
}

struct AnalyticsConversationCorpus: Sendable {
  let document: String
  let chunks: [String]
  let conversationCount: Int
  let messageCount: Int
}

struct OpenAIAnalyticsTurn: Sendable {
  let responseID: String
  let text: String
}
