import Foundation
import SFSafeSymbols

enum InboxScope: String, CaseIterable, Identifiable, Hashable {
  case all
  case unseen
  case open
  case humanIntervention
  case clarification
  case resolved
  case spam

  var id: String { rawValue }

  var title: String {
    switch self {
    case .all:
      "All Conversations"
    case .unseen:
      "Unseen"
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
    }
  }

  var shortTitle: String {
    switch self {
    case .all:
      "All"
    case .unseen:
      "Unseen"
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
    }
  }

  var systemSymbol: SFSymbol {
    switch self {
    case .all:
      .trayFull
    case .unseen:
      .eyeSlash
    case .open:
      .bubbleLeftAndBubbleRight
    case .humanIntervention:
      .handRaised
    case .clarification:
      .questionmarkBubble
    case .resolved:
      .checkmarkCircle
    case .spam:
      .exclamationmarkShield
    }
  }
}

extension InboxScope {
  func includes(_ conversation: DashboardConversation) -> Bool {
    switch self {
    case .all:
      true
    case .unseen:
      conversation.hasUnreadActivity
    case .open:
      conversation.status == .open
    case .humanIntervention:
      conversation.needsHumanIntervention
    case .clarification:
      conversation.needsClarification
    case .resolved:
      conversation.status == .resolved
    case .spam:
      conversation.status == .spam
    }
  }
}

enum WorkspaceRoute: Hashable {
  case inbox(InboxScope)
  case contacts
  case knowledge
  case analytics

  var title: String {
    switch self {
    case .inbox(let scope):
      scope.title
    case .contacts:
      "Contacts"
    case .knowledge:
      "Knowledge"
    case .analytics:
      "Analytics"
    }
  }

  var symbol: SFSymbol {
    switch self {
    case .inbox(let scope):
      scope.systemSymbol
    case .contacts:
      .person2
    case .knowledge:
      .booksVertical
    case .analytics:
      .chartXyaxisLine
    }
  }
}
