import CossistantAdmin

struct ConversationWorkspaceControls: Sendable {
  let showDeveloperLogs: Bool
  let canUseMessageTranslations: Bool
  let canUseConversationDraftTranslation: Bool
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
  typealias FAQReplyDraftAction = @MainActor @Sendable (DashboardKnowledge) async -> String?
  typealias FAQLoadAction = @MainActor @Sendable (String?) async throws -> [DashboardKnowledge]
  typealias DraftTranslationAction = @MainActor @Sendable (String) async throws -> DashboardMessageTranslation
  typealias TitleUpdateAction = @MainActor @Sendable (String?) async -> Void
  typealias MetadataUpdateAction = @MainActor @Sendable (DashboardMetadata) async throws -> Void
  typealias PauseAIAction = @MainActor @Sendable (Int) async -> Void
  typealias AsyncAction = @MainActor @Sendable () async -> Void
  typealias SyncAction = @MainActor @Sendable () -> Void
  typealias DraftTextAction = @MainActor @Sendable (String) -> Void
  typealias VisibilityAction = @MainActor @Sendable (DashboardTimelineItemVisibility) -> Void

  let setShowDeveloperLogs: ToggleAction
  let setShowTranslations: ToggleAction
  let setShowInspector: ToggleAction
  let setComposerDraftText: DraftTextAction
  let setComposerVisibility: VisibilityAction
  let sendMessage: SendMessageAction
  let generateReplyDraft: ReplyDraftAction
  let generateReplyFromFAQ: FAQReplyDraftAction
  let loadFAQsForConversation: FAQLoadAction
  let previewDraftTranslation: DraftTranslationAction
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
  let updateConversationMetadata: MetadataUpdateAction
  let joinConversationEscalation: AsyncAction
  let dismissConversationClarification: AsyncAction
  let pauseConversationAI: PauseAIAction
  let resumeConversationAI: AsyncAction
  let loadMoreTimeline: SyncAction
}

struct ConversationSeenDebugState: Sendable {
  let currentActorUserID: String?
  let isManuallyMarkedUnread: Bool
  let effectiveHasUnreadActivity: Bool
  let rawHasUnreadActivity: Bool
  let shouldAutoMarkSeenOnOpen: Bool
  let autoSeenShouldAttempt: Bool
  let routeTitle: String
  let selectedConversationID: String?
  let selectedConversationDetailID: String?
  let loadStateDescription: String
  let scenePhaseDescription: String
  let controlActiveStateDescription: String
  let realtimeConnectionDescription: String
  let lastRealtimeEventAt: String?
}
