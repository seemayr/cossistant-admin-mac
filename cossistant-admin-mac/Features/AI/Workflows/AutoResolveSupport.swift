import Foundation
import CossistantAdmin

enum AutoResolveSourceScope: String, CaseIterable, Identifiable, Sendable {
  case open
  case unseen

  var id: String { rawValue }

  var label: String {
    switch self {
    case .open:
      "Open"
    case .unseen:
      "Unseen"
    }
  }

  var inboxScope: InboxScope {
    switch self {
    case .open:
      .open
    case .unseen:
      .unseen
    }
  }
}

enum AutoResolveResultOutcome: String, Sendable {
  case emptyResolved
  case resolved
  case manuallyResolved
  case notResolved

  var label: String {
    switch self {
    case .emptyResolved:
      "Auto resolved due empty convo"
    case .resolved:
      "Auto-resolved"
    case .manuallyResolved:
      "Resolved manually"
    case .notResolved:
      "Not resolved"
    }
  }
}

enum AutoResolveResultFilter: String, CaseIterable, Identifiable, Sendable {
  case resolved
  case keptOpen
  case resolvedButKeptOpen

  var id: String { rawValue }

  var label: String {
    switch self {
    case .resolved:
      "Resolved"
    case .keptOpen:
      "Kept open"
    case .resolvedButKeptOpen:
      "Resolved, but kept open"
    }
  }

  func includes(_ result: AutoResolveResult) -> Bool {
    switch self {
    case .resolved:
      result.outcome == .resolved || result.outcome == .manuallyResolved
    case .keptOpen:
      result.outcome == .notResolved
    case .resolvedButKeptOpen:
      result.outcome == .notResolved && result.aiMarkedResolved == true
    }
  }
}

enum AutoResolveDateRange: String, CaseIterable, Identifiable, Sendable {
  case all
  case last24Hours
  case last7Days
  case last30Days

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      "Any Date"
    case .last24Hours:
      "Last 24h"
    case .last7Days:
      "Last 7d"
    case .last30Days:
      "Last 30d"
    }
  }

  func includes(
    _ conversation: DashboardConversation,
    basis: AutoResolveDateBasis,
    now: Date
  ) -> Bool {
    guard let cutoffDate = cutoffDate(relativeTo: now) else {
      return true
    }
    guard let date = basis.date(for: conversation) else {
      return false
    }
    return date >= cutoffDate
  }

  private func cutoffDate(relativeTo now: Date) -> Date? {
    switch self {
    case .all:
      nil
    case .last24Hours:
      now.addingTimeInterval(-24 * 60 * 60)
    case .last7Days:
      now.addingTimeInterval(-7 * 24 * 60 * 60)
    case .last30Days:
      now.addingTimeInterval(-30 * 24 * 60 * 60)
    }
  }
}

enum AutoResolveDateBasis: String, CaseIterable, Identifiable, Sendable {
  case latestActivity
  case created

  var id: String { rawValue }

  var label: String {
    switch self {
    case .latestActivity:
      "Updated"
    case .created:
      "Created"
    }
  }

  func date(for conversation: DashboardConversation) -> Date? {
    switch self {
    case .latestActivity:
      conversation.latestActivityDate
    case .created:
      conversation.createdAtDate
    }
  }
}

enum AutoResolveAttentionFilter: String, CaseIterable, Identifiable, Sendable {
  case all
  case noAttentionFlags
  case unread
  case humanIntervention
  case clarification

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      "Any Attention"
    case .noAttentionFlags:
      "No Attention Flags"
    case .unread:
      "Unread"
    case .humanIntervention:
      "Needs Human"
    case .clarification:
      "Clarification"
    }
  }

  func includes(
    _ conversation: DashboardConversation,
    isUnread: Bool
  ) -> Bool {
    switch self {
    case .all:
      true
    case .noAttentionFlags:
      !isUnread
        && !conversation.needsHumanIntervention
        && !conversation.needsClarification
    case .unread:
      isUnread
    case .humanIntervention:
      conversation.needsHumanIntervention
    case .clarification:
      conversation.needsClarification
    }
  }
}

enum AutoResolveConversationCategory: String, CaseIterable, Sendable {
  case feedback
  case gameProblem
  case productQuestion
  case groupProblem
  case accountProblem
  case generalProblem
  case other
  case unknown

  var label: String {
    switch self {
    case .feedback:
      "Feedback"
    case .gameProblem:
      "Game Problem"
    case .productQuestion:
      "Product Question"
    case .groupProblem:
      "Group Problem"
    case .accountProblem:
      "Account Problem"
    case .generalProblem:
      "General Problem"
    case .other:
      "Other"
    case .unknown:
      "Unknown"
    }
  }

  nonisolated init?(aiValue: String) {
    let normalized = aiValue
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "-", with: "")
      .replacingOccurrences(of: "_", with: "")
      .replacingOccurrences(of: " ", with: "")
      .lowercased()

    switch normalized {
    case "feedback":
      self = .feedback
    case "gameproblem":
      self = .gameProblem
    case "productquestion":
      self = .productQuestion
    case "groupproblem":
      self = .groupProblem
    case "accountproblem":
      self = .accountProblem
    case "generalproblem":
      self = .generalProblem
    case "other":
      self = .other
    case "unknown":
      self = .unknown
    default:
      return nil
    }
  }
}

enum AutoResolveMetadataKey {
  static let lastAutoResolve = "lastAutoResolve"
  static let summary = "summary"
}

struct AutoResolveTextFilterOption: Identifiable, Hashable, Sendable {
  let value: String

  var id: String { value }
  var label: String { value }
}

struct AutoResolveResult: Identifiable, Hashable, Sendable {
  let id: UUID
  let conversationID: String
  let visitorID: String
  var outcome: AutoResolveResultOutcome
  var aiMarkedResolved: Bool?
  let category: AutoResolveConversationCategory
  let title: String
  let summary: String?
  let body: String?
  var decisionNote: String?
  let rawAIResponseText: String?
  let createdAt: Date
  var isSeen: Bool
  var isMarkingSeen: Bool
  var isResolvingAnyway: Bool

  init(
    id: UUID = UUID(),
    conversationID: String,
    visitorID: String,
    outcome: AutoResolveResultOutcome,
    aiMarkedResolved: Bool? = nil,
    category: AutoResolveConversationCategory,
    title: String,
    summary: String? = nil,
    body: String? = nil,
    decisionNote: String? = nil,
    rawAIResponseText: String? = nil,
    createdAt: Date = .now,
    isSeen: Bool = false,
    isMarkingSeen: Bool = false,
    isResolvingAnyway: Bool = false
  ) {
    self.id = id
    self.conversationID = conversationID
    self.visitorID = visitorID
    self.outcome = outcome
    self.aiMarkedResolved = aiMarkedResolved
    self.category = category
    self.title = title
    self.summary = summary
    self.body = body
    self.decisionNote = decisionNote
    self.rawAIResponseText = rawAIResponseText
    self.createdAt = createdAt
    self.isSeen = isSeen
    self.isMarkingSeen = isMarkingSeen
    self.isResolvingAnyway = isResolvingAnyway
  }
}

struct OpenAIConversationResolutionVerdict: Sendable {
  let isResolved: Bool
  let category: AutoResolveConversationCategory
  let title: String
  let body: String
  let summary: String
  let rawResponseText: String
}
