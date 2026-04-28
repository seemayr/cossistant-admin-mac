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
  static let cardCornerRadius: CGFloat = 20
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
        timelinePresentation: timelinePresentation,
        canLoadMoreTimeline: controls.canLoadMoreTimeline,
        isLoadingMoreTimeline: controls.isLoadingMoreTimeline,
        onLoadMoreTimeline: actions.loadMoreTimeline,
        onDismissClarification: {
          await actions.dismissConversationClarification()
        }
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
        onResolveFAQ: actions.generateReplyFromFAQ,
        onApplyDraft: { generatedDraft in
          actions.setComposerVisibility(.public)
          actions.setComposerDraftText(generatedDraft)
        }
      )
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
  let loadFAQs: @MainActor @Sendable (String?) async throws -> [DashboardKnowledge]
  let onResolveFAQ: @MainActor @Sendable (DashboardKnowledge) async -> String?
  let onApplyDraft: @MainActor @Sendable (String) -> Void

  @State private var selectedAIAgentID: String?
  @State private var searchText = ""
  @State private var items: [DashboardKnowledge] = []
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var resolvingFAQID: String?

  private var filteredItems: [DashboardKnowledge] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return items }

    return items.filter { item in
      let payload = item.faqPayload
      let haystacks = [
        item.titleText,
        payload?.question ?? "",
        payload?.answer ?? "",
        payload?.categories.joined(separator: ", ") ?? "",
        payload?.relatedQuestions.joined(separator: " ") ?? "",
      ]

      return haystacks.contains { $0.localizedCaseInsensitiveContains(query) }
    }
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

          if isLoading, items.isEmpty {
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
                Task {
                  await resolve(with: item)
                }
              } label: {
                FAQSelectionRow(item: item)
              }
              .buttonStyle(.plain)
              .disabled(resolvingFAQID != nil)
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
          if isLoading || resolvingFAQID != nil {
            ProgressView()
          }
        }
      }
    }
    .searchable(text: $searchText, prompt: "Search FAQ entries")
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
  private func loadItems() async {
    guard let selectedAIAgentID else {
      items = []
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      items = try await loadFAQs(selectedAIAgentID)
    } catch {
      items = []
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func resolve(with item: DashboardKnowledge) async {
    resolvingFAQID = item.id
    defer { resolvingFAQID = nil }

    guard let generatedDraft = await onResolveFAQ(item) else { return }

    onApplyDraft(generatedDraft)
    dismiss()
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
