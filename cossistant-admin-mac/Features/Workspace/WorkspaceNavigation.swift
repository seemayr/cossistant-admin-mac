import Foundation
import SFSafeSymbols
import CossistantAdmin

enum InboxScope: String, CaseIterable, Identifiable, Hashable {
  case all
  case unseen
  case updated
  case open
  case humanIntervention
  case clarification
  case resolved
  case spam
  case archived

  var id: String { rawValue }

  var title: String {
    switch self {
    case .all:
      "All Conversations"
    case .unseen:
      "Unseen"
    case .updated:
      "Updated"
    case .open:
      "Open"
    case .humanIntervention:
      "Human Intervention Needed"
    case .clarification:
      "Clarification Needed"
    case .resolved:
      "Resolved"
    case .spam:
      "Spam"
    case .archived:
      "Archived"
    }
  }

  var shortTitle: String {
    switch self {
    case .all:
      "All"
    case .unseen:
      "Unseen"
    case .updated:
      "Updated"
    case .open:
      "Open"
    case .humanIntervention:
      "Human"
    case .clarification:
      "Clarification"
    case .resolved:
      "Resolved"
    case .spam:
      "Spam"
    case .archived:
      "Archived"
    }
  }

  var systemSymbol: SFSymbol {
    switch self {
    case .all:
      .trayFull
    case .unseen:
      .eyeSlash
    case .updated:
      .bubbleLeftAndBubbleRight
    case .open:
      .message
    case .humanIntervention:
      .handRaised
    case .clarification:
      .questionmarkBubble
    case .resolved:
      .checkmarkCircle
    case .spam:
      .exclamationmarkShield
    case .archived:
      .archivebox
    }
  }
}

extension InboxScope {
  func includes(_ conversation: DashboardConversation) -> Bool {
    switch self {
    case .all:
      !conversation.isArchived
    case .unseen:
      !conversation.isArchived && conversation.hasUnreadActivity
    case .updated:
      !conversation.isArchived && conversation.hasUpdatesSinceLastSeen
    case .open:
      !conversation.isArchived && conversation.status == .open
    case .humanIntervention:
      !conversation.isArchived && conversation.needsHumanIntervention
    case .clarification:
      !conversation.isArchived && conversation.needsClarification
    case .resolved:
      !conversation.isArchived && conversation.status == .resolved
    case .spam:
      !conversation.isArchived && conversation.status == .spam
    case .archived:
      conversation.isArchived
    }
  }
}

enum WorkspaceRoute: Hashable {
  case inbox(InboxScope)
  case statistics
  case contacts
  case knowledge
  case settings
  case aiAgents
  case aiSummarize
  case aiAutoResolve
  case aiFAQResolver
  case faq

  var title: String {
    switch self {
    case .inbox(let scope):
      scope.title
    case .statistics:
      "Statistics"
    case .contacts:
      "Contacts"
    case .knowledge:
      "Knowledge"
    case .settings:
      "Settings"
    case .aiAgents:
      "AI Agents"
    case .aiSummarize:
      "Summarize"
    case .aiAutoResolve:
      "Auto-Resolve"
    case .aiFAQResolver:
      "FAQ Resolver"
    case .faq:
      "FAQ"
    }
  }

  var symbol: SFSymbol {
    switch self {
    case .inbox(let scope):
      scope.systemSymbol
    case .statistics:
      .chartBar
    case .contacts:
      .person2
    case .knowledge:
      .booksVertical
    case .settings:
      .gearshape
    case .aiAgents:
      .sparkles
    case .aiSummarize:
      .chartXyaxisLine
    case .aiAutoResolve:
      .sparkles
    case .aiFAQResolver:
      .questionmarkBubble
    case .faq:
      .questionmarkBubble
    }
  }
}
