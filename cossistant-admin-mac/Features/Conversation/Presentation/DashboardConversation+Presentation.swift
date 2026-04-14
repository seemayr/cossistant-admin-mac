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
}
