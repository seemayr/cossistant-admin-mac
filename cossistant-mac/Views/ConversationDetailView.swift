import SwiftUI
import SFSafeSymbols

struct ConversationDetailView: View {
  let website: DashboardWebsite?
  let conversation: DashboardConversation?
  let detail: DashboardConversationDetail?
  let visitor: DashboardVisitor?
  let visitorPresence: DashboardVisitorPresence?
  let timelineItems: [DashboardTimelineItem]
  let seenData: [DashboardConversationSeen]
  let typingEvent: DashboardRealtimeConversationTypingPayload?
  let aiProcessingState: DashboardRealtimeAIProcessingState?
  let realtimeConnectionState: DashboardRealtimeConnectionState
  let showDeveloperLogs: Bool
  let onToggleDeveloperLogs: (Bool) -> Void
  let canUseMessageTranslations: Bool
  let showTranslations: Bool
  let onToggleTranslations: (Bool) -> Void
  let translatedMessagesByID: [String: DashboardMessageTranslation]
  let isTranslatingMessages: Bool
  let translationErrorMessage: String?
  let showInspector: Bool
  let onToggleInspector: (Bool) -> Void
  let onSendMessage: @MainActor (String, DashboardTimelineItemVisibility, [DashboardComposerAttachment]) async -> Void
  let canUseOpenAIReplyDrafts: Bool
  let isGeneratingReplyDraft: Bool
  let replyDraftErrorMessage: String?
  let onGenerateReplyDraft: @MainActor (String) async -> String?
  let isCopyingConversationMessages: Bool
  let onCopyConversationMessages: () -> Void
  let onCopyConversationFullLog: () -> Void
  let onMarkConversationSeen: @MainActor () async -> Void
  let onMarkConversationUnread: @MainActor () async -> Void
  let onArchiveConversation: @MainActor () async -> Void
  let onUnarchiveConversation: @MainActor () async -> Void
  let onResolveConversation: @MainActor () async -> Void
  let onReopenConversation: @MainActor () async -> Void
  let onMarkConversationSpam: @MainActor () async -> Void
  let onMarkConversationNotSpam: @MainActor () async -> Void
  let onUpdateConversationTitle: @MainActor (String?) async -> Void
  let onJoinConversationEscalation: @MainActor () async -> Void
  let onPauseConversationAI: @MainActor (Int) async -> Void
  let onResumeConversationAI: @MainActor () async -> Void
  let loadState: ConversationSelectionLoadState
  let canLoadMoreTimeline: Bool
  let isLoadingMoreTimeline: Bool
  let onLoadMoreTimeline: () -> Void

  var body: some View {
    Group {
      if let conversation {
        ConversationWorkspaceView(
          website: website,
          conversation: conversation,
          detail: detail,
          visitor: visitor,
          visitorPresence: visitorPresence,
          seenData: seenData,
          timelineItems: timelineItems,
          typingEvent: typingEvent,
          aiProcessingState: aiProcessingState,
          realtimeConnectionState: realtimeConnectionState,
          showDeveloperLogs: showDeveloperLogs,
          onToggleDeveloperLogs: onToggleDeveloperLogs,
          canUseMessageTranslations: canUseMessageTranslations,
          showTranslations: showTranslations,
          onToggleTranslations: onToggleTranslations,
          translatedMessagesByID: translatedMessagesByID,
          isTranslatingMessages: isTranslatingMessages,
          translationErrorMessage: translationErrorMessage,
          showInspector: showInspector,
          onToggleInspector: onToggleInspector,
          onSendMessage: onSendMessage,
          canUseOpenAIReplyDrafts: canUseOpenAIReplyDrafts,
          isGeneratingReplyDraft: isGeneratingReplyDraft,
          replyDraftErrorMessage: replyDraftErrorMessage,
          onGenerateReplyDraft: onGenerateReplyDraft,
          isCopyingConversationMessages: isCopyingConversationMessages,
          onCopyConversationMessages: onCopyConversationMessages,
          onCopyConversationFullLog: onCopyConversationFullLog,
          onMarkConversationSeen: onMarkConversationSeen,
          onMarkConversationUnread: onMarkConversationUnread,
          onArchiveConversation: onArchiveConversation,
          onUnarchiveConversation: onUnarchiveConversation,
          onResolveConversation: onResolveConversation,
          onReopenConversation: onReopenConversation,
          onMarkConversationSpam: onMarkConversationSpam,
          onMarkConversationNotSpam: onMarkConversationNotSpam,
          onUpdateConversationTitle: onUpdateConversationTitle,
          onJoinConversationEscalation: onJoinConversationEscalation,
          onPauseConversationAI: onPauseConversationAI,
          onResumeConversationAI: onResumeConversationAI,
          loadState: loadState,
          canLoadMoreTimeline: canLoadMoreTimeline,
          isLoadingMoreTimeline: isLoadingMoreTimeline,
          onLoadMoreTimeline: onLoadMoreTimeline
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
