import SwiftUI

struct AutoSeenTrigger: Hashable {
  let route: WorkspaceRoute
  let selectedConversationID: String?
  let selectedConversationDetailID: String?
  let loadState: ConversationSelectionLoadState
  let hasUnreadActivity: Bool
  let isManuallyMarkedUnread: Bool
  let shouldAutoMarkSeenOnOpen: Bool
  let scenePhase: ScenePhase
  let controlActiveState: ControlActiveState

  var shouldAttemptAutoSeen: Bool {
    guard case .inbox = route else { return false }
    guard shouldAutoMarkSeenOnOpen else { return false }
    guard let selectedConversationID, selectedConversationDetailID == selectedConversationID else {
      return false
    }
    guard loadState == .loaded else { return false }
    guard hasUnreadActivity else { return false }
    guard !isManuallyMarkedUnread else { return false }
    guard scenePhase == .active else { return false }
    return controlActiveState != .inactive
  }
}
