import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct WorkspaceRootView: View {
  @Bindable var model: WorkspaceModel
  @Bindable var workspaceStore: WorkspaceStore
  @Binding var showConversationInspector: Bool
  @State private var splitViewVisibility: NavigationSplitViewVisibility = .all
  @Environment(\.openWindow) private var openWindow
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.controlActiveState) private var controlActiveState

  private var activeRoute: WorkspaceRoute {
    workspaceStore.activeRoute
  }

  private var usesDetailOnlySplitLayout: Bool {
    switch activeRoute {
    case .statistics, .aiSummarize, .aiAutoResolve, .faq:
      true
    case .inbox, .contacts, .knowledge, .aiAgents:
      false
    }
  }

  var body: some View {
    Group {
      if model.website == nil {
        WorkspaceLoadingView(
          profileName: model.currentProfile?.name,
          isConnecting: model.isConnecting,
          errorMessage: model.errorMessage
        ) {
          openWindow(id: "launcher")
        }
      } else {
        NavigationSplitView(columnVisibility: $splitViewVisibility) {
          sidebarColumn
        } content: {
          contentColumn
        } detail: {
          detailColumn
        }
        .navigationSplitViewStyle(.prominentDetail)
      }
    }
    .task {
      await model.restoreSessionIfNeeded()
      syncSplitViewVisibility()
    }
    .onChange(of: activeRoute) { _, _ in
      syncSplitViewVisibility()
    }
    .task(id: autoSeenTrigger) {
      if DashboardReadDebug.isTargetConversation(autoSeenTrigger.selectedConversationID) {
        DashboardReadDebug.log(
          "WorkspaceRootView.autoReadTrigger",
          "route=\(String(describing: autoSeenTrigger.route)) selectedConversationID=\(autoSeenTrigger.selectedConversationID ?? "nil") selectedConversationDetailID=\(autoSeenTrigger.selectedConversationDetailID ?? "nil") loadState=\(String(describing: autoSeenTrigger.loadState)) hasUnread=\(autoSeenTrigger.hasUnreadActivity) shouldAutoMark=\(autoSeenTrigger.shouldAutoMarkSeenOnOpen) scenePhase=\(String(describing: autoSeenTrigger.scenePhase)) controlState=\(String(describing: autoSeenTrigger.controlActiveState)) shouldAttempt=\(autoSeenTrigger.shouldAttemptAutoSeen)"
        )
      }

      guard autoSeenTrigger.shouldAttemptAutoSeen else { return }
      guard let selectedConversation = model.selectedConversation else { return }
      guard workspaceStore.autoSeenConversationIDInFlight != selectedConversation.id else { return }

      workspaceStore.autoSeenConversationIDInFlight = selectedConversation.id
      defer {
        if workspaceStore.autoSeenConversationIDInFlight == selectedConversation.id {
          workspaceStore.autoSeenConversationIDInFlight = nil
        }
      }

      await model.markSelectedConversationRead()
    }
    .task(id: model.inboxStore.searchText) {
      model.handleConversationSearchChange()
    }
    .toolbar {
      if model.website != nil {
        ToolbarItem(placement: .navigation) {
          Button {
            Task {
              await refreshCurrentSection()
            }
          } label: {
            Label("Refresh", systemSymbol: .arrowClockwise)
          }
          .disabled(model.isConnecting)
        }

        if case .inbox = activeRoute, model.selectedConversation != nil {
          ToolbarItem(placement: .primaryAction) {
            Button {
              showConversationInspector.toggle()
            } label: {
              Label(
                showConversationInspector ? "Hide Inspector" : "Show Inspector",
                systemSymbol: .sidebarRight
              )
            }
          }
        }
      }
    }
  }

  private var sidebarColumn: some View {
    WorkspaceSidebarView(
      model: model,
      inboxStore: model.inboxStore,
      selection: routeSelectionBinding,
      onRefresh: {
        Task {
          await refreshCurrentSection()
        }
      }
    )
    .navigationSplitViewColumnWidth(min: 190, ideal: 250, max: 280)
  }

  @ViewBuilder
  private var contentColumn: some View {
    switch activeRoute {
    case .inbox(let scope):
      InboxQueueView(
        model: model,
        store: model.inboxStore,
        scope: scope,
        selection: conversationSelectionBinding
      )
      .navigationSplitViewColumnWidth(min: 280, ideal: 380, max: 460)
    case .contacts:
      ContactsListView(
        store: model.contactsStore,
        selection: contactSelectionBinding
      )
      .navigationSplitViewColumnWidth(min: 260, ideal: 340, max: 420)
    case .knowledge:
      KnowledgeListView(
        store: model.knowledgeStore,
        availableAIAgents: model.website?.availableAIAgents ?? [],
        selection: knowledgeSelectionBinding,
        onCreate: { type in
          model.startCreatingKnowledge(type, in: workspaceStore)
        },
        onEdit: { item in
          model.startEditingKnowledge(item, in: workspaceStore)
        },
        onDelete: { item in
          await deleteKnowledge(item)
        }
      )
      .navigationSplitViewColumnWidth(min: 260, ideal: 340, max: 420)
    case .aiAgents:
      AIAgentListView(
        agents: model.website?.availableAIAgents ?? [],
        selection: aiAgentSelectionBinding
      )
      .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 380)
    case .statistics, .aiSummarize, .aiAutoResolve, .faq:
      EmptyView()
    }
  }

  @ViewBuilder
  private var detailColumn: some View {
    switch activeRoute {
    case .inbox:
      let conversationControls = ConversationWorkspaceControls(
        showDeveloperLogs: model.showDeveloperLogs,
        canUseMessageTranslations: model.canUseMessageTranslations,
        canUseConversationDraftTranslation: model.canUseConversationDraftTranslation,
        showTranslations: model.showMessageTranslations,
        isTranslatingMessages: model.isTranslatingMessages,
        translationErrorMessage: model.translationErrorMessage,
        showInspector: showConversationInspector,
        canUseOpenAIReplyDrafts: model.canUseOpenAIReplyDrafts,
        isGeneratingReplyDraft: model.isGeneratingReplyDraft,
        replyDraftErrorMessage: model.replyDraftErrorMessage,
        isCopyingConversationMessages: model.isCopyingConversationMessages,
        hasUnreadActivity: model.selectedConversation.map { model.conversationHasUnreadActivity($0) } ?? false,
        canLoadMoreTimeline: model.canLoadMoreTimeline,
        isLoadingMoreTimeline: model.isLoadingMoreTimeline
      )
      let conversationActions = ConversationWorkspaceActions(
        setShowDeveloperLogs: { model.showDeveloperLogs = $0 },
        setShowTranslations: { isEnabled in
          Task {
            await model.setShowMessageTranslations(isEnabled)
          }
        },
        setShowInspector: { showConversationInspector = $0 },
        setComposerDraftText: { model.conversationComposerDraftText = $0 },
        setComposerVisibility: { model.conversationComposerVisibility = $0 },
        sendMessage: { text, visibility, attachments in
          await model.sendMessage(text: text, visibility: visibility, attachments: attachments)
        },
        generateReplyDraft: { draft in
          await model.generateReplyDraft(from: draft)
        },
        generateReplyFromFAQ: { faq in
          await model.generateReplyFromFAQ(using: faq)
        },
        loadFAQsForConversation: { aiAgentID in
          try await model.loadFAQEntriesForConversation(aiAgentID: aiAgentID)
        },
        previewDraftTranslation: { text in
          try await model.translateConversationDraftPreview(text)
        },
        buildFAQFromConversation: {
          setSelectedRoute(.faq)
          model.startFAQBuildFromSelectedConversation()
        },
        copyConversationMessages: {
          Task {
            await model.copySelectedConversationMessages()
          }
        },
        copyConversationFullLog: {
          Task {
            await model.copySelectedConversationFullLog()
          }
        },
        markConversationSeen: {
          await model.markSelectedConversationRead()
        },
        markConversationUnread: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.markConversationUnread(selectedConversationID)
        },
        archiveConversation: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.archiveConversation(selectedConversationID)
        },
        unarchiveConversation: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.unarchiveConversation(selectedConversationID)
        },
        resolveConversation: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.resolveConversation(selectedConversationID)
        },
        reopenConversation: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.reopenConversation(selectedConversationID)
        },
        markConversationSpam: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.markConversationSpam(selectedConversationID)
        },
        markConversationNotSpam: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.markConversationNotSpam(selectedConversationID)
        },
        updateConversationTitle: { title in
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.updateConversationTitle(selectedConversationID, title: title)
        },
        updateConversationMetadata: { metadata in
          guard let selectedConversationID = model.selectedConversationID else { return }
          try await model.updateConversationMetadata(selectedConversationID, metadata: metadata)
        },
        joinConversationEscalation: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.joinConversationEscalation(selectedConversationID)
        },
        pauseConversationAI: { durationMinutes in
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.pauseConversationAI(selectedConversationID, durationMinutes: durationMinutes)
        },
        resumeConversationAI: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.resumeConversationAI(selectedConversationID)
        },
        loadMoreTimeline: {
          Task {
            await model.loadMoreTimeline()
          }
        }
      )
      let seenDebugState = ConversationSeenDebugState(
        currentActorUserID: model.currentActorUserID,
        isManuallyMarkedUnread: model.isConversationManuallyMarkedUnread(model.selectedConversationID),
        effectiveHasUnreadActivity: model.selectedConversation.map { model.conversationHasUnreadActivity($0) } ?? false,
        rawHasUnreadActivity: model.selectedConversation?.hasUnreadActivity ?? false,
        shouldAutoMarkSeenOnOpen: model.shouldAutoMarkSeenOnOpen,
        autoSeenShouldAttempt: autoSeenTrigger.shouldAttemptAutoSeen,
        routeTitle: activeRoute.title,
        selectedConversationID: model.selectedConversationID,
        selectedConversationDetailID: model.selectedConversationDetail?.id,
        loadStateDescription: describe(model.selectedConversationLoadState),
        scenePhaseDescription: describe(scenePhase),
        controlActiveStateDescription: describe(controlActiveState),
        realtimeConnectionDescription: describe(model.realtimeConnectionState),
        lastRealtimeEventAt: model.lastRealtimeEventDate.map {
          ISO8601DateFormatter.internetDateTime.string(from: $0)
        }
      )

      ConversationDetailView(
        composerDraftText: Binding(
          get: { model.conversationComposerDraftText },
          set: { model.conversationComposerDraftText = $0 }
        ),
        composerVisibility: Binding(
          get: { model.conversationComposerVisibility },
          set: { model.conversationComposerVisibility = $0 }
        ),
        website: model.website,
        conversation: model.selectedConversation,
        listSnapshotConversation: model.selectedConversationListSnapshot,
        detail: model.selectedConversationDetail,
        visitor: model.selectedVisitor,
        visitorPresence: model.visitorPresence(for: model.selectedConversation?.visitorId),
        timelineItems: model.selectedTimelineItems,
        seenData: model.selectedSeenData,
        typingEvent: model.selectedTypingEvent,
        aiProcessingState: model.selectedAIProcessingState,
        realtimeConnectionState: model.realtimeConnectionState,
        controls: conversationControls,
        actions: conversationActions,
        showDeveloperLogs: model.showDeveloperLogs,
        seenDebugState: seenDebugState,
        translatedMessagesByID: model.translatedMessagesByID,
        translatedClarification: model.translatedClarification,
        loadState: model.selectedConversationLoadState,
        timelinePresentation: model.selectedTimelinePresentation(includeDeveloperLogs: model.showDeveloperLogs)
      )
      .frame(minWidth: 680, maxWidth: .infinity, maxHeight: .infinity)
    case .statistics:
      ConversationStatisticsWorkspaceView(store: model.inboxStore)
    case .contacts:
      ContactDetailPrototypeView(
        store: model.contactsStore,
        contact: model.contactsStore.selectedContact,
        listItem: model.contactsStore.selectedListItem
      )
    case .knowledge:
      KnowledgeDetailView(
        item: model.knowledgeStore.selectedKnowledge,
        draft: $workspaceStore.knowledgeEditorDraft,
        availableAIAgents: model.website?.availableAIAgents ?? [],
        isLoading: model.knowledgeStore.isLoadingDetail,
        errorMessage: model.knowledgeStore.errorMessage,
        onSave: { draft in
          await saveKnowledgeDraft(draft)
        },
        onCancelEditing: {
          workspaceStore.knowledgeEditorDraft = nil
        },
        onEdit: { item in
          model.startEditingKnowledge(item, in: workspaceStore)
        },
        onOpenAIAgent: { aiAgentID in
          setSelectedRoute(.aiAgents)
          model.selectAIAgent(aiAgentID, in: workspaceStore)
        },
        onDelete: { item in
          await deleteKnowledge(item)
        }
      )
    case .aiAgents:
      AIAgentDetailView(
        store: model.aiAgentStore,
        summary: model.website?.availableAIAgents.first(where: { $0.id == workspaceStore.selectedAIAgentID }),
        onRefresh: {
          guard let selectedAIAgentID = workspaceStore.selectedAIAgentID else { return }
          model.selectAIAgent(selectedAIAgentID, in: workspaceStore, force: true)
        },
        onStartTraining: {
          guard let selectedAIAgentID = workspaceStore.selectedAIAgentID else { return }
          Task {
            await model.aiAgentStore.startTraining(id: selectedAIAgentID)
          }
        },
      )
    case .aiSummarize:
      AISummaryWorkspaceView(
        store: model.analyticsStore,
        onGenerateSummary: {
          model.startAnalyticsSummaryGeneration()
        },
        onReset: {
          model.resetAnalyticsSummaryConversation()
        },
        onCopySourceDocument: {
          model.copyAnalyticsSourceDocument()
        },
        onSendFollowUp: {
          model.startAnalyticsFollowUp()
        }
      )
    case .aiAutoResolve:
      AIAutoResolveWorkspaceView(
        store: model.autoResolveStore,
        inspectedConversation: model.autoResolveStore.inspectedConversationID == model.selectedConversationID
          ? model.selectedConversation
          : nil,
        inspectedVisitor: model.autoResolveStore.inspectedConversationID == model.selectedConversationID
          ? model.selectedVisitor
          : nil,
        inspectedTimelineItems: model.autoResolveStore.inspectedConversationID == model.selectedConversationID
          ? model.selectedTimelineItems
          : [],
        inspectedSeenData: model.autoResolveStore.inspectedConversationID == model.selectedConversationID
          ? model.selectedSeenData
          : [],
        translatedMessagesByID: model.translatedMessagesByID,
        canUseMessageTranslations: model.canUseMessageTranslations,
        showTranslations: model.showMessageTranslations,
        isTranslatingMessages: model.isTranslatingMessages,
        translationErrorMessage: model.translationErrorMessage,
        loadState: model.selectedConversationLoadState,
        canLoadMoreTimeline: model.canLoadMoreTimeline,
        isLoadingMoreTimeline: model.isLoadingMoreTimeline,
        canStart: model.canStartAutoResolve,
        onStart: {
          model.startAutoResolve()
        },
        onCancel: {
          model.cancelAutoResolve()
        },
        onClearResults: {
          model.clearAutoResolveResults()
        },
        onInspectConversation: { conversationID in
          await model.inspectAutoResolveConversation(conversationID)
        },
        onOpenConversation: { conversationID in
          openConversation(conversationID, in: .inbox(.all))
        },
        onResolveAnyway: { conversationID in
          await model.resolveAutoResolveResult(conversationID)
        },
        onMarkAsSeen: { conversationID in
          await model.markAutoResolveResultSeen(conversationID)
        },
        onSetShowTranslations: { isEnabled in
          await model.setShowMessageTranslations(isEnabled)
        },
        onLoadMoreTimeline: {
          Task {
            await model.loadMoreTimeline()
          }
        }
      )
    case .faq:
      FAQDraftingWorkspaceView(
        store: model.faqStore,
        availableAIAgents: model.website?.availableAIAgents ?? [],
        selectedConversation: model.selectedConversation,
        canBuildFromConversation: model.faqCanBuildFromConversation,
        onOptimizeDraft: {
          model.startFAQOptimization()
        },
        onBuildFromSelectedConversation: {
          model.startFAQBuildFromSelectedConversation()
        },
        onResetDraft: {
          model.resetFAQDraft()
        },
        onClearSuggestion: {
          model.clearFAQSuggestion()
        },
        onApplySuggestionToDraft: {
          model.applyFAQSuggestionToDraft()
        },
        onSaveDraftToKnowledge: {
          _ = await model.saveFAQToKnowledge(
            usingSuggestion: false,
            startTraining: false
          )
        },
        onSaveSuggestionToKnowledge: {
          _ = await model.saveFAQToKnowledge(
            usingSuggestion: true,
            startTraining: false
          )
        },
        onSaveAndTrainSuggestion: {
          _ = await model.saveFAQToKnowledge(
            usingSuggestion: model.faqStore.suggestion != nil,
            startTraining: true
          )
        },
        onOpenSavedKnowledge: {
          guard let savedKnowledgeID = model.faqStore.lastSavedKnowledgeID else { return }
          setSelectedRoute(.knowledge)
          model.selectKnowledge(savedKnowledgeID, in: workspaceStore)
        }
      )
    }
  }

  private func refreshCurrentSection() async {
    await model.refreshRoute(activeRoute, in: workspaceStore)
  }

  private var routeSelectionBinding: Binding<WorkspaceRoute?> {
    Binding(
      get: { workspaceStore.selectedRoute },
      set: { newValue in
        setSelectedRoute(newValue)
      }
    )
  }

  private var conversationSelectionBinding: Binding<DashboardConversation.ID?> {
    Binding(
      get: { model.selectedConversationID },
      set: { newValue in
        model.selectConversation(newValue)
      }
    )
  }

  private var contactSelectionBinding: Binding<String?> {
    Binding(
      get: { workspaceStore.selectedContactID },
      set: { newValue in
        model.selectContact(newValue, in: workspaceStore)
      }
    )
  }

  private var knowledgeSelectionBinding: Binding<String?> {
    Binding(
      get: { workspaceStore.selectedKnowledgeID },
      set: { newValue in
        model.selectKnowledge(newValue, in: workspaceStore)
      }
    )
  }

  private var aiAgentSelectionBinding: Binding<String?> {
    Binding(
      get: { workspaceStore.selectedAIAgentID },
      set: { newValue in
        model.selectAIAgent(newValue, in: workspaceStore)
      }
    )
  }

  private func setSelectedRoute(_ route: WorkspaceRoute?) {
    workspaceStore.selectedRoute = route

    guard let route else { return }
    Task {
      await model.activateRoute(route, in: workspaceStore)
    }
  }

  private func openConversation(
    _ conversationID: DashboardConversation.ID,
    in route: WorkspaceRoute? = nil
  ) {
    if let route {
      setSelectedRoute(route)
    }
    model.selectConversation(conversationID)
  }

  private func syncSplitViewVisibility() {
    splitViewVisibility = usesDetailOnlySplitLayout ? .doubleColumn : .all
  }

  private var autoSeenTrigger: AutoSeenTrigger {
    AutoSeenTrigger(
      route: activeRoute,
      selectedConversationID: model.selectedConversationID,
      selectedConversationDetailID: model.selectedConversationDetail?.id,
      loadState: model.selectedConversationLoadState,
      hasUnreadActivity: model.selectedConversation.map { model.conversationHasUnreadActivity($0) } ?? false,
      isManuallyMarkedUnread: model.isConversationManuallyMarkedUnread(model.selectedConversationID),
      shouldAutoMarkSeenOnOpen: model.shouldAutoMarkSeenOnOpen,
      scenePhase: scenePhase,
      controlActiveState: controlActiveState
    )
  }

  private func saveKnowledgeDraft(_ draft: DashboardKnowledgeEditorDraft) async {
    do {
      let request = try draft.makeRequest()

      if let id = draft.id {
        if let updated = await model.knowledgeStore.updateKnowledge(id: id, draft: request) {
          model.presentKnowledge(updated, in: workspaceStore)
        }
      } else if let created = await model.knowledgeStore.createKnowledge(request) {
        model.presentKnowledge(created, in: workspaceStore)
      }
    } catch {
      model.knowledgeStore.errorMessage = error.localizedDescription
    }
  }

  private func describe(_ loadState: ConversationSelectionLoadState) -> String {
    switch loadState {
    case .idle:
      "idle"
    case .loading:
      "loading"
    case .loaded:
      "loaded"
    case .failed(let message):
      "failed: \(message)"
    }
  }

  private func describe(_ state: DashboardRealtimeConnectionState) -> String {
    switch state {
    case .connected(let connectionID):
      "connected (\(connectionID ?? "no connection id"))"
    case .connecting:
      "connecting"
    case .disconnected:
      "disconnected"
    case .failed(let message):
      "failed: \(message)"
    }
  }

  private func describe(_ phase: ScenePhase) -> String {
    switch phase {
    case .active:
      "active"
    case .inactive:
      "inactive"
    case .background:
      "background"
    @unknown default:
      "unknown"
    }
  }

  private func describe(_ state: ControlActiveState) -> String {
    switch state {
    case .active:
      "active"
    case .inactive:
      "inactive"
    case .key:
      "key"
    @unknown default:
      "unknown"
    }
  }

  private func deleteKnowledge(_ item: DashboardKnowledge) async {
    await model.removeKnowledge(item, in: workspaceStore)
  }

}

#Preview {
  WorkspaceRootView(
    model: WorkspaceModel(restoreLastUsedSession: false),
    workspaceStore: WorkspaceStore(),
    showConversationInspector: .constant(false)
  )
}
