import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct ConversationThreadCanvasView: View {
  let website: DashboardWebsite?
  let conversation: DashboardConversation
  let visitor: DashboardVisitor?
  let visitorPresence: DashboardVisitorPresence?
  let timelineItems: [DashboardTimelineItem]
  let seenData: [DashboardConversationSeen]
  let typingEvent: DashboardRealtimeConversationTypingPayload?
  let aiProcessingState: DashboardRealtimeAIProcessingState?
  let realtimeConnectionState: DashboardRealtimeConnectionState
  let loadState: ConversationSelectionLoadState
  let showDeveloperLogs: Bool
  let translatedMessagesByID: [String: DashboardMessageTranslation]
  let timelinePresentation: DashboardTimelinePresentationBundle?
  let canLoadMoreTimeline: Bool
  let isLoadingMoreTimeline: Bool
  let onLoadMoreTimeline: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      if typingEvent != nil || aiProcessingState != nil {
        ConversationLiveStatusSection(
          website: website,
          conversation: conversation,
          visitor: visitor,
          visitorPresence: visitorPresence,
          typingEvent: typingEvent,
          aiProcessingState: aiProcessingState
        )
        .padding(.horizontal, ConversationWorkspaceLayout.panePadding)
        .padding(.vertical, 16)

        Divider()
      }

      threadContent
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  @ViewBuilder
  private var threadContent: some View {
    switch loadState {
    case .idle where timelineItems.isEmpty, .loading where timelineItems.isEmpty:
      VStack(spacing: 14) {
        ProgressView()
          .controlSize(.large)

        Text("Loading conversation activity…")
          .font(.title3.weight(.medium))
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

    case .failed(let message) where timelineItems.isEmpty:
      ContentUnavailableView(
        "Timeline Unavailable",
        systemImage: SFSymbol.exclamationmarkTriangle.rawValue,
        description: Text(message)
      )

    default:
      ScrollView {
        ConversationTimelineView(
          website: website,
          conversation: conversation,
          visitor: visitor,
          items: timelineItems,
          seenData: seenData,
          translatedMessagesByID: translatedMessagesByID,
          showDeveloperLogs: showDeveloperLogs,
          canLoadMoreTimeline: canLoadMoreTimeline,
          isLoadingMoreTimeline: isLoadingMoreTimeline,
          onLoadMoreTimeline: onLoadMoreTimeline,
          presentation: timelinePresentation
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, ConversationWorkspaceLayout.panePadding)
        .padding(.top, 28)
        .padding(.bottom, 34)
      }
      .background(Color.clear)
    }
  }
}
