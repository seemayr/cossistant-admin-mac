import SwiftUI
import SFSafeSymbols

struct ConversationDetailView: View {
  let website: DashboardWebsite?
  let conversation: DashboardConversation?
  let listSnapshotConversation: DashboardConversation?
  let detail: DashboardConversationDetail?
  let visitor: DashboardVisitor?
  let visitorPresence: DashboardVisitorPresence?
  let timelineItems: [DashboardTimelineItem]
  let seenData: [DashboardConversationSeen]
  let typingEvent: DashboardRealtimeConversationTypingPayload?
  let aiProcessingState: DashboardRealtimeAIProcessingState?
  let realtimeConnectionState: DashboardRealtimeConnectionState
  let controls: ConversationWorkspaceControls
  let actions: ConversationWorkspaceActions
  let showDeveloperLogs: Bool
  let seenDebugState: ConversationSeenDebugState
  let translatedMessagesByID: [String: DashboardMessageTranslation]
  let translatedClarification: DashboardMessageTranslation?
  let loadState: ConversationSelectionLoadState

  var body: some View {
    Group {
      if let conversation {
        ConversationWorkspaceView(
          website: website,
          conversation: conversation,
          listSnapshotConversation: listSnapshotConversation,
          detail: detail,
          visitor: visitor,
          visitorPresence: visitorPresence,
          seenData: seenData,
          timelineItems: timelineItems,
          typingEvent: typingEvent,
          aiProcessingState: aiProcessingState,
          realtimeConnectionState: realtimeConnectionState,
          controls: controls,
          actions: actions,
          showDeveloperLogs: showDeveloperLogs,
          seenDebugState: seenDebugState,
          translatedMessagesByID: translatedMessagesByID,
          translatedClarification: translatedClarification,
          loadState: loadState
        )
      } else {
        ContentUnavailableView(
          "Pick a conversation",
          systemImage: SFSymbol.bubbleLeftAndBubbleRight.rawValue,
          description: Text("Select a thread from the queue to inspect the latest context.")
        )
      }
    }
  }
}
