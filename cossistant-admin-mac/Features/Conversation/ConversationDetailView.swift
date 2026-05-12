import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct ConversationDetailView: View {
  @Binding var composerDraftText: String
  @Binding var composerVisibility: DashboardTimelineItemVisibility
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
  let timelinePresentation: DashboardTimelinePresentationBundle?
  let onViewContact: (String) -> Void

  var body: some View {
    Group {
      if let conversation {
        ConversationWorkspaceView(
          composerDraftText: $composerDraftText,
          composerVisibility: $composerVisibility,
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
          loadState: loadState,
          timelinePresentation: timelinePresentation,
          onViewContact: onViewContact
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
