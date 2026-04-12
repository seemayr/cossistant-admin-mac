import SwiftUI

enum ConversationWorkspaceLayout {
  static let threadMinWidth: CGFloat = 540
  static let threadMaxWidth: CGFloat = 860
  static let inspectorMinWidth: CGFloat = 240
  static let inspectorIdealWidth: CGFloat = 320
  static let inspectorMaxWidth: CGFloat = 360
  static let panePadding: CGFloat = 24
  static let cardCornerRadius: CGFloat = 20
}

struct ConversationWorkspaceView: View {
  let website: DashboardWebsite?
  let conversation: DashboardConversation
  let listSnapshotConversation: DashboardConversation?
  let detail: DashboardConversationDetail?
  let visitor: DashboardVisitor?
  let visitorPresence: DashboardVisitorPresence?
  let seenData: [DashboardConversationSeen]
  let timelineItems: [DashboardTimelineItem]
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
      if controls.showInspector {
        HSplitView {
          threadColumn
          inspectorColumn
        }
      } else {
        threadColumn
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.clear)
  }

  private var threadColumn: some View {
    ConversationThreadWorkspaceColumn(
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
      controls: controls,
      actions: actions,
      translatedClarification: translatedClarification,
      loadState: loadState,
      translatedMessagesByID: translatedMessagesByID
    )
    .frame(
      minWidth: ConversationWorkspaceLayout.threadMinWidth,
      maxWidth: .infinity,
      maxHeight: .infinity
    )
  }

  private var inspectorColumn: some View {
    ConversationInspectorView(
      conversation: conversation,
      listSnapshotConversation: listSnapshotConversation,
      detail: detail,
      visitor: visitor,
      visitorPresence: visitorPresence,
      seenData: seenData,
      realtimeConnectionState: realtimeConnectionState,
      showDeveloperLogs: showDeveloperLogs,
      seenDebugState: seenDebugState,
      onUpdateConversationMetadata: actions.updateConversationMetadata
    )
    .frame(
      minWidth: ConversationWorkspaceLayout.inspectorMinWidth,
      idealWidth: ConversationWorkspaceLayout.inspectorIdealWidth,
      maxWidth: ConversationWorkspaceLayout.inspectorMaxWidth,
      maxHeight: .infinity
    )
  }
}

private struct ConversationThreadWorkspaceColumn: View {
  let website: DashboardWebsite?
  let conversation: DashboardConversation
  let detail: DashboardConversationDetail?
  let visitor: DashboardVisitor?
  let visitorPresence: DashboardVisitorPresence?
  let seenData: [DashboardConversationSeen]
  let timelineItems: [DashboardTimelineItem]
  let typingEvent: DashboardRealtimeConversationTypingPayload?
  let aiProcessingState: DashboardRealtimeAIProcessingState?
  let realtimeConnectionState: DashboardRealtimeConnectionState
  let controls: ConversationWorkspaceControls
  let actions: ConversationWorkspaceActions
  let translatedClarification: DashboardMessageTranslation?
  let loadState: ConversationSelectionLoadState
  let translatedMessagesByID: [String: DashboardMessageTranslation]

  var body: some View {
    VStack(spacing: 0) {
      ConversationThreadHeaderView(
        conversation: conversation,
        detail: detail,
        visitor: visitor,
        visitorPresence: visitorPresence,
        realtimeConnectionState: realtimeConnectionState,
        showDeveloperLogs: controls.showDeveloperLogs,
        onToggleDeveloperLogs: actions.setShowDeveloperLogs,
        canUseMessageTranslations: controls.canUseMessageTranslations,
        showTranslations: controls.showTranslations,
        onToggleTranslations: actions.setShowTranslations,
        isTranslatingMessages: controls.isTranslatingMessages,
        translationErrorMessage: controls.translationErrorMessage,
        showInspector: controls.showInspector,
        onToggleInspector: actions.setShowInspector,
        isCopyingConversationMessages: controls.isCopyingConversationMessages,
        onCopyConversationMessages: actions.copyConversationMessages,
        onCopyConversationFullLog: actions.copyConversationFullLog,
        hasUnreadActivity: controls.hasUnreadActivity,
        onMarkConversationSeen: actions.markConversationSeen,
        onMarkConversationUnread: actions.markConversationUnread,
        onArchiveConversation: actions.archiveConversation,
        onUnarchiveConversation: actions.unarchiveConversation,
        onResolveConversation: actions.resolveConversation,
        onReopenConversation: actions.reopenConversation,
        onMarkConversationSpam: actions.markConversationSpam,
        onMarkConversationNotSpam: actions.markConversationNotSpam,
        onUpdateConversationTitle: actions.updateConversationTitle,
        onJoinConversationEscalation: actions.joinConversationEscalation,
        onPauseConversationAI: actions.pauseConversationAI,
        onResumeConversationAI: actions.resumeConversationAI,
        canUseOpenAIReplyDrafts: controls.canUseOpenAIReplyDrafts,
        onBuildFAQFromConversation: actions.buildFAQFromConversation
      )

      Divider()

      ConversationThreadCanvasView(
        website: website,
        conversation: conversation,
        visitor: visitor,
        visitorPresence: visitorPresence,
        timelineItems: timelineItems,
        seenData: seenData,
        typingEvent: typingEvent,
        aiProcessingState: aiProcessingState,
        realtimeConnectionState: realtimeConnectionState,
        loadState: loadState,
        showDeveloperLogs: controls.showDeveloperLogs,
        translatedMessagesByID: translatedMessagesByID,
        translatedClarification: translatedClarification,
        canLoadMoreTimeline: controls.canLoadMoreTimeline,
        isLoadingMoreTimeline: controls.isLoadingMoreTimeline,
        onLoadMoreTimeline: actions.loadMoreTimeline
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Divider()

      ConversationComposerView(
        canUseOpenAIReplyDrafts: controls.canUseOpenAIReplyDrafts,
        isGeneratingReplyDraft: controls.isGeneratingReplyDraft,
        replyDraftErrorMessage: controls.replyDraftErrorMessage,
        onGenerateReplyDraft: actions.generateReplyDraft,
        onSendMessage: actions.sendMessage
      )
      .padding(.horizontal, ConversationWorkspaceLayout.panePadding)
      .padding(.vertical, 18)
      .background(.bar)
    }
    .background(Color.clear)
  }
}
