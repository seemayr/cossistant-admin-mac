import Foundation
import Observation
import CossistantAdmin

@Observable @MainActor
final class ConversationStore {
  var selectedConversationDetail: DashboardConversationDetail?
  var selectedConversationListSnapshot: DashboardConversation?
  var selectedVisitor: DashboardVisitor?
  var selectedSeenData: [DashboardConversationSeen] = []
  var selectedTimelineItems: [DashboardTimelineItem] = [] {
    didSet {
      invalidateTimelinePresentation()
    }
  }
  private var selectedTimelinePresentation: DashboardTimelinePresentationBundle?
  private var selectedTimelinePresentationWithDeveloperLogs: DashboardTimelinePresentationBundle?
  var selectedTimelineNextCursor: String?
  var typingEventsByConversationID: [String: DashboardRealtimeConversationTypingPayload] = [:]
  var aiProcessingByConversationID: [String: DashboardRealtimeAIProcessingState] = [:]
  var composerDraftText = ""
  var composerVisibility: DashboardTimelineItemVisibility = .public
  var showTranslations = false
  var selectedConversationLoadState: ConversationSelectionLoadState = .idle
  var isLoadingMoreTimeline = false
  var isTranslatingMessages = false
  var isGeneratingReplyDraft = false
  var isCopyingConversationMessages = false
  var translatedMessagesByID: [String: DashboardMessageTranslation] = [:]
  var translatedClarification: DashboardMessageTranslation?
  var translationErrorMessage: String?
  var replyDraftErrorMessage: String?

  func reset() {
    clearSelection()
    typingEventsByConversationID = [:]
    aiProcessingByConversationID = [:]
  }

  func clearSelection() {
    resetSelection(
      listSnapshot: nil,
      loadState: .idle
    )
  }

  func prepareSelection(_ listSnapshot: DashboardConversation?) {
    resetSelection(
      listSnapshot: listSnapshot,
      loadState: listSnapshot == nil ? .idle : .loading
    )
  }

  func markSelectionFailed(_ message: String) {
    selectedConversationLoadState = .failed(message)
  }

  private func resetSelection(
    listSnapshot: DashboardConversation?,
    loadState: ConversationSelectionLoadState
  ) {
    selectedConversationDetail = nil
    selectedConversationListSnapshot = listSnapshot
    selectedVisitor = nil
    selectedSeenData = []
    selectedTimelineItems = []
    selectedTimelineNextCursor = nil
    composerDraftText = ""
    composerVisibility = .public
    translatedMessagesByID = [:]
    translatedClarification = nil
    translationErrorMessage = nil
    replyDraftErrorMessage = nil
    selectedConversationLoadState = loadState
  }

  func updateSelectedVisitor(_ visitor: DashboardVisitor?) {
    selectedVisitor = visitor
  }

  func replaceSelectedSeenData(_ seenData: [DashboardConversationSeen]) {
    selectedSeenData = seenData
  }

  func applyLoadedSelection(
    detail: DashboardConversationDetail,
    visitor: DashboardVisitor?,
    seenData: [DashboardConversationSeen],
    timelinePage: DashboardTimelinePage
  ) {
    selectedConversationDetail = detail
    selectedVisitor = visitor
    selectedSeenData = seenData
    selectedTimelineItems = timelinePage.items
    selectedTimelineNextCursor = timelinePage.nextCursor
    selectedConversationLoadState = .loaded
  }

  func appendTimelinePage(_ page: DashboardTimelinePage) {
    let existingIDs = Set(selectedTimelineItems.map(\.id))
    let newItems = page.items.filter { !existingIDs.contains($0.id) }
    selectedTimelineItems.append(contentsOf: newItems)
    selectedTimelineNextCursor = page.nextCursor
  }

  func applyRealtimeTimelineItem(
    _ item: DashboardTimelineItem,
    conversationID: String,
    selectedConversationID: String?
  ) {
    guard conversationID == selectedConversationID else { return }

    if let existingIndex = selectedTimelineItems.firstIndex(where: { $0.id == item.id }) {
      selectedTimelineItems[existingIndex] = item
    } else {
      selectedTimelineItems.insert(item, at: 0)
    }
  }

  func timelinePresentation(
    includeDeveloperLogs: Bool
  ) -> DashboardTimelinePresentationBundle {
    if includeDeveloperLogs {
      if let selectedTimelinePresentationWithDeveloperLogs {
        return selectedTimelinePresentationWithDeveloperLogs
      }

      let presentation = DashboardTimelinePresentation.buildBundle(
        items: selectedTimelineItems,
        includeDeveloperLogs: true
      )
      selectedTimelinePresentationWithDeveloperLogs = presentation
      return presentation
    }

    if let selectedTimelinePresentation {
      return selectedTimelinePresentation
    }

    let presentation = DashboardTimelinePresentation.buildBundle(
      items: selectedTimelineItems,
      includeDeveloperLogs: false
    )
    selectedTimelinePresentation = presentation
    return presentation
  }

  func updateTypingEvent(_ payload: DashboardRealtimeConversationTypingPayload) {
    if payload.isTyping {
      var updatedEvents = typingEventsByConversationID
      updatedEvents[payload.conversationId] = payload
      typingEventsByConversationID = updatedEvents
      return
    }

    clearTypingEvent(for: payload.conversationId)
  }

  func clearTypingEvent(for conversationID: String) {
    guard typingEventsByConversationID[conversationID] != nil else { return }
    var updatedEvents = typingEventsByConversationID
    updatedEvents.removeValue(forKey: conversationID)
    typingEventsByConversationID = updatedEvents
  }

  func updateAIProcessingState(
    conversationID: String,
    state: DashboardRealtimeAIProcessingState
  ) {
    var updatedStates = aiProcessingByConversationID
    updatedStates[conversationID] = state
    aiProcessingByConversationID = updatedStates
  }

  func clearAIProcessingState(for conversationID: String) {
    guard aiProcessingByConversationID[conversationID] != nil else { return }
    var updatedStates = aiProcessingByConversationID
    updatedStates.removeValue(forKey: conversationID)
    aiProcessingByConversationID = updatedStates
  }

  func upsertSeenItem(
    _ item: DashboardConversationSeen,
    selectedConversationID: String?
  ) -> Bool {
    guard item.conversationId == selectedConversationID else { return false }

    if let existingIndex = selectedSeenData.firstIndex(where: {
      $0.userId == item.userId
        && $0.visitorId == item.visitorId
        && $0.aiAgentId == item.aiAgentId
    }) {
      selectedSeenData[existingIndex] = item
    } else {
      selectedSeenData.insert(item, at: 0)
    }

    return true
  }

  var selectedTypingEvent: DashboardRealtimeConversationTypingPayload? {
    guard let conversationID = selectedConversationDetail?.id else { return nil }
    return typingEventsByConversationID[conversationID]
  }

  func selectedTypingEvent(for conversationID: String?) -> DashboardRealtimeConversationTypingPayload? {
    guard let conversationID else { return nil }
    return typingEventsByConversationID[conversationID]
  }

  var selectedAIProcessingState: DashboardRealtimeAIProcessingState? {
    guard let conversationID = selectedConversationDetail?.id else { return nil }
    return aiProcessingByConversationID[conversationID]
  }

  func selectedAIProcessingState(for conversationID: String?) -> DashboardRealtimeAIProcessingState? {
    guard let conversationID else { return nil }
    return aiProcessingByConversationID[conversationID]
  }

  var canLoadMoreTimeline: Bool {
    selectedTimelineNextCursor != nil && !isLoadingMoreTimeline
  }

  func setShowTranslations(_ isEnabled: Bool) {
    showTranslations = isEnabled
    translationErrorMessage = nil

    if !isEnabled {
      translatedMessagesByID = [:]
      translatedClarification = nil
    }
  }

  private func invalidateTimelinePresentation() {
    selectedTimelinePresentation = nil
    selectedTimelinePresentationWithDeveloperLogs = nil
  }
}
