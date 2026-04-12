import Foundation

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
  case notResolved

  var label: String {
    switch self {
    case .emptyResolved:
      "Auto resolved due empty convo"
    case .resolved:
      "Auto-resolved"
    case .notResolved:
      "Not resolved"
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

struct AutoResolveResult: Identifiable, Hashable, Sendable {
  let id: UUID
  let conversationID: String
  let visitorID: String
  let outcome: AutoResolveResultOutcome
  let category: AutoResolveConversationCategory
  let title: String
  let body: String?
  let createdAt: Date

  init(
    id: UUID = UUID(),
    conversationID: String,
    visitorID: String,
    outcome: AutoResolveResultOutcome,
    category: AutoResolveConversationCategory,
    title: String,
    body: String? = nil,
    createdAt: Date = .now
  ) {
    self.id = id
    self.conversationID = conversationID
    self.visitorID = visitorID
    self.outcome = outcome
    self.category = category
    self.title = title
    self.body = body
    self.createdAt = createdAt
  }
}

struct OpenAIConversationResolutionVerdict: Sendable {
  let isResolved: Bool
  let category: AutoResolveConversationCategory
  let title: String
  let body: String
}
