import SwiftUI
import SFSafeSymbols

struct WorkspaceRootView: View {
  @Bindable var model: WorkspaceModel
  @Bindable var workspaceStore: WorkspaceStore
  @Binding var showConversationInspector: Bool
  @Environment(\.openWindow) private var openWindow
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.controlActiveState) private var controlActiveState

  private var activeRoute: WorkspaceRoute {
    workspaceStore.activeRoute
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
        NavigationSplitView {
          WorkspaceSidebarView(
            model: model,
            inboxStore: model.inboxStore,
            selection: $workspaceStore.selectedRoute,
            onRefresh: {
              Task {
                await refreshCurrentSection()
              }
            }
          )
            .navigationSplitViewColumnWidth(min: 190, ideal: 250, max: 280)
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
    }
    .task(id: activeRoute) {
      switch activeRoute {
      case .inbox:
        break
      case .contacts:
        guard model.contactsStore.items.isEmpty, !model.contactsStore.isLoadingList else {
          return
        }
        await model.contactsStore.refresh()
      case .knowledge:
        guard model.knowledgeStore.items.isEmpty, !model.knowledgeStore.isLoadingList else {
          return
        }
        await model.knowledgeStore.refresh()
      case .faq:
        break
      case .aiSummarize:
        break
      case .aiAutoResolve:
        break
      }
    }
    .task(id: model.selectedConversationID) {
      guard case .inbox = activeRoute else { return }
      guard model.website != nil else { return }
      guard model.selectedConversationDetail?.id != model.selectedConversationID
              || model.selectedConversationLoadState == .idle else {
        return
      }

      await model.loadSelectedConversation()
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
    .task(id: workspaceStore.selectedContactID) {
      guard let selectedContactID = workspaceStore.selectedContactID else { return }
      await model.contactsStore.loadContact(id: selectedContactID)
    }
    .task(id: workspaceStore.selectedKnowledgeID) {
      guard workspaceStore.knowledgeEditorDraft == nil else { return }
      guard let selectedKnowledgeID = workspaceStore.selectedKnowledgeID else { return }
      await model.knowledgeStore.loadKnowledge(id: selectedKnowledgeID)
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

  @ViewBuilder
  private var contentColumn: some View {
    switch activeRoute {
    case .inbox(let scope):
      InboxQueueView(
        model: model,
        store: model.inboxStore,
        scope: scope,
        selection: $model.selectedConversationID
      )
      .navigationSplitViewColumnWidth(min: 280, ideal: 380, max: 460)
    case .contacts:
      ContactsListView(
        store: model.contactsStore,
        selection: $workspaceStore.selectedContactID
      )
      .navigationSplitViewColumnWidth(min: 260, ideal: 340, max: 420)
    case .knowledge:
      KnowledgeListView(
        store: model.knowledgeStore,
        selection: $workspaceStore.selectedKnowledgeID,
        onCreate: { type in
          workspaceStore.selectedKnowledgeID = nil
          model.knowledgeStore.selectedKnowledge = nil
          workspaceStore.knowledgeEditorDraft = .blank(type: type)
        },
        onEdit: { item in
          workspaceStore.selectedKnowledgeID = item.id
          workspaceStore.knowledgeEditorDraft = DashboardKnowledgeEditorDraft(item: item)
        },
        onDelete: { item in
          await deleteKnowledge(item)
        }
      )
      .navigationSplitViewColumnWidth(min: 260, ideal: 340, max: 420)
    case .aiSummarize:
      AISummarizeNavigationPlaceholderView(store: model.analyticsStore)
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
    case .aiAutoResolve:
      AIAutoResolveNavigationPlaceholderView(store: model.autoResolveStore)
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
    case .faq:
      FAQNavigationPlaceholderView(store: model.faqStore)
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
    }
  }

  @ViewBuilder
  private var detailColumn: some View {
    switch activeRoute {
    case .inbox:
      let conversationControls = ConversationWorkspaceControls(
        showDeveloperLogs: model.showDeveloperLogs,
        canUseMessageTranslations: model.canUseMessageTranslations,
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
        sendMessage: { text, visibility, attachments in
          await model.sendMessage(text: text, visibility: visibility, attachments: attachments)
        },
        generateReplyDraft: { draft in
          await model.generateReplyDraft(from: draft)
        },
        buildFAQFromConversation: {
          workspaceStore.selectedRoute = .faq
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
        loadState: model.selectedConversationLoadState
      )
      .frame(minWidth: 680, maxWidth: .infinity, maxHeight: .infinity)
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
        errorMessage: model.knowledgeStore.errorMessage,
        onSave: { draft in
          await saveKnowledgeDraft(draft)
        },
        onCancelEditing: {
          workspaceStore.knowledgeEditorDraft = nil
        },
        onEdit: { item in
          workspaceStore.knowledgeEditorDraft = DashboardKnowledgeEditorDraft(item: item)
        },
        onDelete: { item in
          await deleteKnowledge(item)
        }
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
          workspaceStore.selectedRoute = .inbox(.all)
          model.selectedConversationID = conversationID
        },
        onResolveAnyway: { conversationID in
          await model.resolveAutoResolveResult(conversationID)
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
        }
      )
    }
  }

  private func refreshCurrentSection() async {
    switch activeRoute {
    case .inbox:
      await model.refresh()
    case .contacts:
      await model.contactsStore.refresh()
    case .knowledge:
      await model.knowledgeStore.refresh()
    case .faq:
      break
    case .aiSummarize:
      break
    case .aiAutoResolve:
      break
    }
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
          workspaceStore.selectedKnowledgeID = updated.id
          workspaceStore.knowledgeEditorDraft = nil
        }
      } else if let created = await model.knowledgeStore.createKnowledge(request) {
        workspaceStore.selectedKnowledgeID = created.id
        workspaceStore.knowledgeEditorDraft = nil
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
    await model.knowledgeStore.deleteKnowledge(id: item.id)
    if workspaceStore.selectedKnowledgeID == item.id {
      workspaceStore.selectedKnowledgeID = nil
    }
    if workspaceStore.knowledgeEditorDraft?.id == item.id {
      workspaceStore.knowledgeEditorDraft = nil
    }
  }

}

#Preview {
  WorkspaceRootView(
    model: WorkspaceModel(restoreLastUsedSession: false),
    workspaceStore: WorkspaceStore(),
    showConversationInspector: .constant(false)
  )
}
