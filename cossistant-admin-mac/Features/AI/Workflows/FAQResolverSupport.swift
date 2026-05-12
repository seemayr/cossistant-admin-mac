import Foundation
import CossistantAdmin

enum FAQResolverSourceScope: String, CaseIterable, Identifiable, Sendable {
  case all
  case open
  case unseen
  case updated
  case humanIntervention
  case clarification

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      "All Open"
    case .open:
      "Open"
    case .unseen:
      "Unseen"
    case .updated:
      "Updated"
    case .humanIntervention:
      "Needs Human"
    case .clarification:
      "Clarification"
    }
  }

  var inboxScope: InboxScope {
    switch self {
    case .all:
      .all
    case .open:
      .open
    case .unseen:
      .unseen
    case .updated:
      .updated
    case .humanIntervention:
      .humanIntervention
    case .clarification:
      .clarification
    }
  }
}

enum FAQResolverSummaryFilter: String, CaseIterable, Identifiable, Sendable {
  case all
  case hasSummary
  case noSummary

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      "Any Summary"
    case .hasSummary:
      "Has Summary"
    case .noSummary:
      "No Summary"
    }
  }

  func includes(_ conversation: DashboardConversation) -> Bool {
    switch self {
    case .all:
      true
    case .hasSummary:
      conversation.inboxMetadataSummaryPreviewText != nil
    case .noSummary:
      conversation.inboxMetadataSummaryPreviewText == nil
    }
  }
}

enum FAQResolverVisitorWaitingFilter: String, CaseIterable, Identifiable, Sendable {
  case all
  case visitorWaiting
  case teamAlreadyReplied

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      "Any Reply State"
    case .visitorWaiting:
      "Visitor Waiting"
    case .teamAlreadyReplied:
      "Team Replied"
    }
  }

  func includes(_ conversation: DashboardConversation) -> Bool {
    switch self {
    case .all:
      true
    case .visitorWaiting:
      conversation.lastMessageTimelineItem?.visitorId != nil
    case .teamAlreadyReplied:
      conversation.lastMessageTimelineItem?.visitorId == nil
    }
  }
}

enum FAQResolverTeamActionFilter: String, CaseIterable, Identifiable, Sendable {
  case all
  case exclude

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      "Any Team Need"
    case .exclude:
      "Exclude Needs Team"
    }
  }

  func includes(_ conversation: DashboardConversation) -> Bool {
    switch self {
    case .all:
      true
    case .exclude:
      conversation.teamActionNeededPreviewText == nil
    }
  }
}

enum FAQResolverAssignmentSource: String, Sendable {
  case manual
  case autoAssigned

  var label: String {
    switch self {
    case .manual:
      "Manual"
    case .autoAssigned:
      "Auto"
    }
  }
}

enum FAQResolverMetadataKey {
  static let teamActionNeeded = "teamActionNeeded"
  static let handledAt = "faqResolverHandledAt"
}

enum FAQResolverRowStatus: Equatable, Sendable {
  case idle
  case assigning
  case assigned
  case resolving
  case pendingConfirmation
  case confirming
  case markedSeen
  case needsTeam
  case sent
  case resolved
  case skipped(String)
  case failed(String)

  var label: String? {
    switch self {
    case .idle:
      nil
    case .assigning:
      "Assigning"
    case .assigned:
      "Assigned"
    case .resolving:
      "Preparing"
    case .pendingConfirmation:
      "Pending Confirmation"
    case .confirming:
      "Confirming"
    case .markedSeen:
      "Marked Seen"
    case .needsTeam:
      "Needs Team"
    case .sent:
      "Sent"
    case .resolved:
      "Resolved"
    case .skipped(let message):
      "Skipped: \(message)"
    case .failed(let message):
      "Failed: \(message)"
    }
  }
}

enum FAQResolverPendingAction: String, CaseIterable, Hashable, Sendable {
  case pauseAI
  case sendAnswer
  case markRead
  case resolveAfterAnswer
  case resolveNow
  case markUnread
  case doNothing

  var label: String {
    switch self {
    case .pauseAI:
      "Pause AI 1h"
    case .sendAnswer:
      "Send answer"
    case .markRead:
      "Mark as read"
    case .resolveAfterAnswer:
      "Mark as resolved after answer"
    case .resolveNow:
      "Mark as resolved now"
    case .markUnread:
      "Mark as unseen"
    case .doNothing:
      "Do nothing"
    }
  }
}

struct FAQResolverPendingConfirmation: Equatable, Sendable {
  var message: String?
  var translatedMessage: DashboardMessageTranslation?
  var translationErrorMessage: String?
  var actions: [FAQResolverPendingAction]
  var teamActionNeeded: String?
}

struct FAQResolverConversationState: Equatable, Sendable {
  var assignedFAQIDs: [DashboardKnowledge.ID] = []
  var assignmentSource: FAQResolverAssignmentSource?
  var canResolveWithoutReply = false
  var noActionNeeded = false
  var urgentlyNeedsTeam = false
  var teamActionNeeded: String?
  var pendingConfirmation: FAQResolverPendingConfirmation?
  var status: FAQResolverRowStatus = .idle

  var hasAssignments: Bool {
    !assignedFAQIDs.isEmpty
  }

  var hasResolvableWork: Bool {
    hasAssignments || canResolveWithoutReply || noActionNeeded || urgentlyNeedsTeam
  }

  var hasPendingResolveWork: Bool {
    hasResolvableWork && status != .needsTeam && pendingConfirmation == nil
  }
}

struct FAQResolverFAQMatch: Decodable, Sendable {
  let faqIds: [String]
  let canResolveWithoutReply: Bool
  let noActionNeeded: Bool
  let urgentlyNeedsTeam: Bool
  let teamActionNeeded: String
}

struct FAQResolverDraftResponse: Decodable, Sendable {
  let message: String
  let autoResolve: Bool
  let noActionNeeded: Bool
  let urgentlyNeedsTeam: Bool
  let teamActionNeeded: String
}

struct FAQResolverTextFilterOption: Identifiable, Hashable, Sendable {
  let value: String

  var id: String { value }
  var label: String { value }
}
