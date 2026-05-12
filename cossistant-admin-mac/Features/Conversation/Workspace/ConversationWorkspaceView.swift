import SwiftUI
import CossistantAdmin
import SFSafeSymbols

enum ConversationWorkspaceLayout {
  static let threadMinWidth: CGFloat = 540
  static let threadMaxWidth: CGFloat = 860
  static let inspectorMinWidth: CGFloat = 240
  static let inspectorIdealWidth: CGFloat = 320
  static let inspectorMaxWidth: CGFloat = 360
  static let panePadding: CGFloat = 24
  static let cardCornerRadius: CGFloat = 12
}

struct ConversationWorkspaceView: View {
  @Binding var composerDraftText: String
  @Binding var composerVisibility: DashboardTimelineItemVisibility
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
  let timelinePresentation: DashboardTimelinePresentationBundle?
  let onViewContact: (String) -> Void

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
      composerDraftText: $composerDraftText,
      composerVisibility: $composerVisibility,
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
      translatedMessagesByID: translatedMessagesByID,
      timelinePresentation: timelinePresentation
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
      onUpdateConversationMetadata: actions.updateConversationMetadata,
      onViewContact: onViewContact
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
  @Binding var composerDraftText: String
  @Binding var composerVisibility: DashboardTimelineItemVisibility
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
  let timelinePresentation: DashboardTimelinePresentationBundle?

  @State private var isShowingResolveFromFAQ = false

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
        showBackendTranslatedSubjects: controls.showBackendTranslatedSubjects,
        onToggleTranslations: actions.setShowTranslations,
        isTranslatingMessages: controls.isTranslatingMessages,
        translationErrorMessage: controls.translationErrorMessage,
        translatedClarification: translatedClarification,
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
        onResolveFromFAQ: {
          isShowingResolveFromFAQ = true
        },
        onReopenConversation: actions.reopenConversation,
        onMarkConversationSpam: actions.markConversationSpam,
        onMarkConversationNotSpam: actions.markConversationNotSpam,
        onUpdateConversationTitle: actions.updateConversationTitle,
        onJoinConversationEscalation: actions.joinConversationEscalation,
        onPauseConversationAI: actions.pauseConversationAI,
        onResumeConversationAI: actions.resumeConversationAI,
        canUseOpenAIReplyDrafts: controls.canUseOpenAIReplyDrafts,
        onDismissClarification: actions.dismissConversationClarification,
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
        timelinePresentation: timelinePresentation,
        canLoadMoreTimeline: controls.canLoadMoreTimeline,
        isLoadingMoreTimeline: controls.isLoadingMoreTimeline,
        onLoadMoreTimeline: actions.loadMoreTimeline
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Divider()

      Group {
        if conversation.needsHumanIntervention {
          ConversationEscalationActionView(
            onJoinConversationEscalation: actions.joinConversationEscalation
          )
        } else {
          ConversationComposerView(
            draftText: $composerDraftText,
            visibility: $composerVisibility,
            canUseOpenAIReplyDrafts: controls.canUseOpenAIReplyDrafts,
            canUseTranslationPreview: controls.canUseConversationDraftTranslation,
            isGeneratingReplyDraft: controls.isGeneratingReplyDraft,
            replyDraftErrorMessage: controls.replyDraftErrorMessage,
            onGenerateReplyDraft: actions.generateReplyDraft,
            onPreviewTranslation: actions.previewDraftTranslation,
            onSendMessage: actions.sendMessage
          )
        }
      }
      .padding(.horizontal, ConversationWorkspaceLayout.panePadding)
      .padding(.vertical, 18)
      .background(.bar)
    }
    .background(Color.clear)
    .sheet(isPresented: $isShowingResolveFromFAQ) {
      ConversationFAQPickerSheet(
        availableAIAgents: website?.availableAIAgents ?? [],
        loadFAQs: actions.loadFAQsForConversation,
        onSelectFAQ: { faq in
          startFAQReplyDraft(from: faq)
        }
      )
    }
  }

  private func startFAQReplyDraft(from faq: DashboardKnowledge) {
    let conversationID = conversation.id
    actions.setComposerVisibility(.public)

    Task {
      guard let generatedDraft = await actions.generateReplyFromFAQ(faq, conversationID) else {
        return
      }

      actions.setComposerDraftText(generatedDraft)
    }
  }
}

private struct ConversationEscalationActionView: View {
  let onJoinConversationEscalation: @MainActor @Sendable () async -> Void

  @State private var isJoining = false

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("Human help requested by AI", systemSymbol: .personFillBadgePlus)
        .font(.headline)

      Text("Join the conversation to add yourself as a participant and unlock the reply composer.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Button {
        Task {
          isJoining = true
          await onJoinConversationEscalation()
          isJoining = false
        }
      } label: {
        Label(isJoining ? "Joining…" : "Join the conversation", systemSymbol: .personCropCircleBadgePlus)
      }
      .buttonStyle(.borderedProminent)
      .disabled(isJoining)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(.orange.opacity(0.25), lineWidth: 1)
    }
  }
}

private struct ConversationFAQPickerSheet: View {
  @Environment(\.dismiss) private var dismiss

  let availableAIAgents: [DashboardWebsite.AIAgent]
  let loadFAQs: @MainActor @Sendable (String?, Bool) async throws -> [DashboardKnowledge]
  let onSelectFAQ: @MainActor @Sendable (DashboardKnowledge) -> Void

  @State private var selectedAIAgentID: String?
  @State private var searchText = ""
  @State private var items: [DashboardKnowledge] = []
  @State private var loadingAIAgentID: String?
  @State private var loadedAIAgentID: String?
  @State private var errorMessage: String?

  private var filteredItems: [DashboardKnowledge] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return items }

    return items.filter {
      $0.titleText.localizedCaseInsensitiveContains(query)
    }
  }

  private var isLoading: Bool {
    loadingAIAgentID != nil
  }

  private var isInitialLoad: Bool {
    isLoading && loadedAIAgentID != selectedAIAgentID
  }

  private var isWaitingForInitialAgentSelection: Bool {
    selectedAIAgentID == nil && !availableAIAgents.isEmpty
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        if availableAIAgents.isEmpty {
          ContentUnavailableView(
            "No AI Agent",
            systemImage: "sparkles",
            description: Text("Add an AI agent first to browse FAQ entries for this workspace.")
          )
        } else {
          if availableAIAgents.count > 1 {
            Picker("AI Agent", selection: $selectedAIAgentID) {
              ForEach(availableAIAgents) { agent in
                Text(agent.displayName).tag(Optional(agent.id))
              }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
          }

          if let errorMessage {
            Text(errorMessage)
              .font(.caption)
              .foregroundStyle(.orange)
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          if isWaitingForInitialAgentSelection || isInitialLoad {
            ProgressView("Loading FAQs…")
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else if filteredItems.isEmpty {
            ContentUnavailableView(
              "No FAQ Entries",
              systemImage: "questionmark.bubble",
              description: Text("No FAQ entries were returned for the selected AI agent.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            List(filteredItems) { item in
              Button {
                dismiss()
                onSelectFAQ(item)
              } label: {
                FAQSelectionRow(item: item)
              }
              .buttonStyle(.plain)
              .disabled(isLoading)
            }
            .listStyle(.inset)
          }
        }
      }
      .padding(20)
      .navigationTitle("Resolve from FAQ")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            dismiss()
          }
        }

        ToolbarItem(placement: .automatic) {
          if isLoading {
            ProgressView()
          }
        }

        ToolbarItem(placement: .primaryAction) {
          Button {
            Task {
              await loadItems(forceRefresh: true)
            }
          } label: {
            Label("Refresh", systemSymbol: .arrowClockwise)
          }
          .disabled(isLoading || selectedAIAgentID == nil)
        }
      }
    }
    .searchable(text: $searchText, prompt: "Search FAQ titles")
    .frame(minWidth: 560, minHeight: 520)
    .onAppear {
      if selectedAIAgentID == nil {
        selectedAIAgentID = availableAIAgents.first?.id
      }
    }
    .task(id: selectedAIAgentID) {
      await loadItems()
    }
  }

  @MainActor
  private func loadItems(forceRefresh: Bool = false) async {
    guard let selectedAIAgentID else {
      items = []
      loadedAIAgentID = nil
      return
    }

    loadingAIAgentID = selectedAIAgentID
    errorMessage = nil
    if loadedAIAgentID != selectedAIAgentID {
      items = []
    }
    defer {
      if loadingAIAgentID == selectedAIAgentID {
        loadingAIAgentID = nil
      }
    }

    do {
      let loadedItems = try await loadFAQs(selectedAIAgentID, forceRefresh)
      guard !Task.isCancelled else { return }
      items = loadedItems
      loadedAIAgentID = selectedAIAgentID
    } catch {
      guard !Self.isCancellation(error) else { return }
      if loadedAIAgentID != selectedAIAgentID {
        items = []
      }
      errorMessage = error.localizedDescription
    }
  }

  private static func isCancellation(_ error: any Error) -> Bool {
    if error is CancellationError {
      return true
    }

    if let urlError = error as? URLError, urlError.code == .cancelled {
      return true
    }

    let nsError = error as NSError
    return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
  }
}

private struct FAQSelectionRow: View {
  let item: DashboardKnowledge

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(item.faqPayload?.question ?? item.titleText)
        .font(.headline)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)

      if let answer = item.faqPayload?.answer, !answer.isEmpty {
        Text(answer)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(3)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      if let categories = item.faqPayload?.categories, !categories.isEmpty {
        Text(categories.joined(separator: " • "))
          .font(.caption)
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(.vertical, 4)
  }
}
