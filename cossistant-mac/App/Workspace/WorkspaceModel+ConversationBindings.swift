import Foundation

@MainActor
extension WorkspaceModel {
  var selectedConversation: DashboardConversation? {
    inboxStore.conversation(withID: selectedConversationID)
  }

  var selectedConversationDetail: DashboardConversationDetail? {
    get { conversationStore.selectedConversationDetail }
    set { conversationStore.selectedConversationDetail = newValue }
  }

  var selectedConversationListSnapshot: DashboardConversation? {
    get { conversationStore.selectedConversationListSnapshot }
    set { conversationStore.selectedConversationListSnapshot = newValue }
  }

  var selectedVisitor: DashboardVisitor? {
    get { conversationStore.selectedVisitor }
    set { conversationStore.selectedVisitor = newValue }
  }

  var selectedSeenData: [DashboardConversationSeen] {
    get { conversationStore.selectedSeenData }
    set { conversationStore.selectedSeenData = newValue }
  }

  var selectedTimelineItems: [DashboardTimelineItem] {
    get { conversationStore.selectedTimelineItems }
    set { conversationStore.selectedTimelineItems = newValue }
  }

  var selectedTimelineNextCursor: String? {
    get { conversationStore.selectedTimelineNextCursor }
    set { conversationStore.selectedTimelineNextCursor = newValue }
  }

  var showMessageTranslations: Bool {
    get { conversationStore.showTranslations }
    set { conversationStore.showTranslations = newValue }
  }

  var selectedConversationLoadState: ConversationSelectionLoadState {
    get { conversationStore.selectedConversationLoadState }
    set { conversationStore.selectedConversationLoadState = newValue }
  }

  var isLoadingMoreTimeline: Bool {
    get { conversationStore.isLoadingMoreTimeline }
    set { conversationStore.isLoadingMoreTimeline = newValue }
  }

  var isTranslatingMessages: Bool {
    get { conversationStore.isTranslatingMessages }
    set { conversationStore.isTranslatingMessages = newValue }
  }

  var isGeneratingReplyDraft: Bool {
    get { conversationStore.isGeneratingReplyDraft }
    set { conversationStore.isGeneratingReplyDraft = newValue }
  }

  var isCopyingConversationMessages: Bool {
    get { conversationStore.isCopyingConversationMessages }
    set { conversationStore.isCopyingConversationMessages = newValue }
  }

  var translatedMessagesByID: [String: DashboardMessageTranslation] {
    get { conversationStore.translatedMessagesByID }
    set { conversationStore.translatedMessagesByID = newValue }
  }

  var translatedClarification: DashboardMessageTranslation? {
    get { conversationStore.translatedClarification }
    set { conversationStore.translatedClarification = newValue }
  }

  var translationErrorMessage: String? {
    get { conversationStore.translationErrorMessage }
    set { conversationStore.translationErrorMessage = newValue }
  }

  var replyDraftErrorMessage: String? {
    get { conversationStore.replyDraftErrorMessage }
    set { conversationStore.replyDraftErrorMessage = newValue }
  }

  var selectedTypingEvent: DashboardRealtimeConversationTypingPayload? {
    conversationStore.selectedTypingEvent(for: selectedConversationID)
  }

  var selectedAIProcessingState: DashboardRealtimeAIProcessingState? {
    conversationStore.selectedAIProcessingState(for: selectedConversationID)
  }

  func visitorPresence(for visitorID: String?) -> DashboardVisitorPresence? {
    guard let visitorID else { return nil }
    return visitorPresenceByID[visitorID]
  }

  func typingEvent(for conversationID: String) -> DashboardRealtimeConversationTypingPayload? {
    conversationStore.selectedTypingEvent(for: conversationID)
  }

  func aiProcessingState(for conversationID: String) -> DashboardRealtimeAIProcessingState? {
    conversationStore.selectedAIProcessingState(for: conversationID)
  }

  var canLoadMoreTimeline: Bool {
    conversationStore.canLoadMoreTimeline
  }
}
