struct ConversationWorkspaceControls: Sendable {
  let showDeveloperLogs: Bool
  let canUseMessageTranslations: Bool
  let showTranslations: Bool
  let isTranslatingMessages: Bool
  let translationErrorMessage: String?
  let showInspector: Bool
  let canUseOpenAIReplyDrafts: Bool
  let isGeneratingReplyDraft: Bool
  let replyDraftErrorMessage: String?
  let isCopyingConversationMessages: Bool
  let hasUnreadActivity: Bool
  let canLoadMoreTimeline: Bool
  let isLoadingMoreTimeline: Bool
}

struct ConversationWorkspaceActions: Sendable {
  typealias ToggleAction = @MainActor @Sendable (Bool) -> Void
  typealias SendMessageAction = @MainActor @Sendable (
    String,
    DashboardTimelineItemVisibility,
    [DashboardComposerAttachment]
  ) async -> Void
  typealias ReplyDraftAction = @MainActor @Sendable (String) async -> String?
  typealias TitleUpdateAction = @MainActor @Sendable (String?) async -> Void
  typealias PauseAIAction = @MainActor @Sendable (Int) async -> Void
  typealias AsyncAction = @MainActor @Sendable () async -> Void
  typealias SyncAction = @MainActor @Sendable () -> Void

  let setShowDeveloperLogs: ToggleAction
  let setShowTranslations: ToggleAction
  let setShowInspector: ToggleAction
  let sendMessage: SendMessageAction
  let generateReplyDraft: ReplyDraftAction
  let buildFAQFromConversation: SyncAction
  let copyConversationMessages: SyncAction
  let copyConversationFullLog: SyncAction
  let markConversationSeen: AsyncAction
  let markConversationUnread: AsyncAction
  let archiveConversation: AsyncAction
  let unarchiveConversation: AsyncAction
  let resolveConversation: AsyncAction
  let reopenConversation: AsyncAction
  let markConversationSpam: AsyncAction
  let markConversationNotSpam: AsyncAction
  let updateConversationTitle: TitleUpdateAction
  let joinConversationEscalation: AsyncAction
  let pauseConversationAI: PauseAIAction
  let resumeConversationAI: AsyncAction
  let loadMoreTimeline: SyncAction
}
