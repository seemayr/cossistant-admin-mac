import SwiftUI
import SFSafeSymbols

struct ContentView: View {
  @Bindable var model: AppModel
  @Environment(\.openWindow) private var openWindow
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.controlActiveState) private var controlActiveState

  @State private var selectedRoute: WorkspaceRoute? = .inbox(.open)
  @State private var selectedContactID: String?
  @State private var selectedKnowledgeID: String?
  @State private var knowledgeEditorDraft: DashboardKnowledgeEditorDraft?
  @State private var autoSeenConversationIDInFlight: String?
  @SceneStorage("showConversationInspector") private var showConversationInspector = false

  private var activeRoute: WorkspaceRoute {
    selectedRoute ?? .inbox(.open)
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
            selection: $selectedRoute,
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
      case .analytics:
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
      guard autoSeenTrigger.shouldAttemptAutoSeen else { return }
      guard let selectedConversation = model.selectedConversation else { return }
      guard autoSeenConversationIDInFlight != selectedConversation.id else { return }

      autoSeenConversationIDInFlight = selectedConversation.id
      defer {
        if autoSeenConversationIDInFlight == selectedConversation.id {
          autoSeenConversationIDInFlight = nil
        }
      }

      await model.markSelectedConversationRead()
    }
    .task(id: selectedContactID) {
      guard let selectedContactID else { return }
      await model.contactsStore.loadContact(id: selectedContactID)
    }
    .task(id: selectedKnowledgeID) {
      guard knowledgeEditorDraft == nil else { return }
      guard let selectedKnowledgeID else { return }
      await model.knowledgeStore.loadKnowledge(id: selectedKnowledgeID)
    }
    .task(id: model.searchText) {
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
        scope: scope,
        selection: $model.selectedConversationID
      )
      .navigationSplitViewColumnWidth(min: 280, ideal: 380, max: 460)
    case .contacts:
      ContactsListView(
        store: model.contactsStore,
        selection: $selectedContactID
      )
      .navigationSplitViewColumnWidth(min: 260, ideal: 340, max: 420)
    case .knowledge:
      KnowledgeListView(
        store: model.knowledgeStore,
        selection: $selectedKnowledgeID,
        onCreate: { type in
          selectedKnowledgeID = nil
          model.knowledgeStore.selectedKnowledge = nil
          knowledgeEditorDraft = .blank(type: type)
        },
        onEdit: { item in
          selectedKnowledgeID = item.id
          knowledgeEditorDraft = DashboardKnowledgeEditorDraft(item: item)
        },
        onDelete: { item in
          await deleteKnowledge(item)
        }
      )
      .navigationSplitViewColumnWidth(min: 260, ideal: 340, max: 420)
    case .analytics:
      AnalyticsNavigationPlaceholderView(model: model)
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
    }
  }

  @ViewBuilder
  private var detailColumn: some View {
    switch activeRoute {
    case .inbox:
      ConversationDetailView(
        website: model.website,
        conversation: model.selectedConversation,
        detail: model.selectedConversationDetail,
        visitor: model.selectedVisitor,
        visitorPresence: model.visitorPresence(for: model.selectedConversation?.visitorId),
        timelineItems: model.selectedTimelineItems,
        seenData: model.selectedSeenData,
        typingEvent: model.selectedTypingEvent,
        aiProcessingState: model.selectedAIProcessingState,
        realtimeConnectionState: model.realtimeConnectionState,
        showDeveloperLogs: model.showDeveloperLogs,
        onToggleDeveloperLogs: { model.showDeveloperLogs = $0 },
        canUseMessageTranslations: model.canUseMessageTranslations,
        showTranslations: model.showMessageTranslations,
        onToggleTranslations: { isEnabled in
          Task {
            await model.setShowMessageTranslations(isEnabled)
          }
        },
        translatedMessagesByID: model.translatedMessagesByID,
        isTranslatingMessages: model.isTranslatingMessages,
        translationErrorMessage: model.translationErrorMessage,
        showInspector: showConversationInspector,
        onToggleInspector: { showConversationInspector = $0 },
        onSendMessage: { text, visibility, attachments in
          await model.sendMessage(text: text, visibility: visibility, attachments: attachments)
        },
        canUseOpenAIReplyDrafts: model.canUseOpenAIReplyDrafts,
        isGeneratingReplyDraft: model.isGeneratingReplyDraft,
        replyDraftErrorMessage: model.replyDraftErrorMessage,
        onGenerateReplyDraft: { draft in
          await model.generateReplyDraft(from: draft)
        },
        isCopyingConversationMessages: model.isCopyingConversationMessages,
        onCopyConversationMessages: {
          Task {
            await model.copySelectedConversationMessages()
          }
        },
        onCopyConversationFullLog: {
          Task {
            await model.copySelectedConversationFullLog()
          }
        },
        onMarkConversationSeen: {
          await model.markSelectedConversationRead()
        },
        onMarkConversationUnread: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.markConversationUnread(selectedConversationID)
        },
        onArchiveConversation: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.archiveConversation(selectedConversationID)
        },
        onUnarchiveConversation: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.unarchiveConversation(selectedConversationID)
        },
        onResolveConversation: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.resolveConversation(selectedConversationID)
        },
        onReopenConversation: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.reopenConversation(selectedConversationID)
        },
        onMarkConversationSpam: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.markConversationSpam(selectedConversationID)
        },
        onMarkConversationNotSpam: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.markConversationNotSpam(selectedConversationID)
        },
        onUpdateConversationTitle: { title in
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.updateConversationTitle(selectedConversationID, title: title)
        },
        onJoinConversationEscalation: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.joinConversationEscalation(selectedConversationID)
        },
        onPauseConversationAI: { durationMinutes in
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.pauseConversationAI(selectedConversationID, durationMinutes: durationMinutes)
        },
        onResumeConversationAI: {
          guard let selectedConversationID = model.selectedConversationID else { return }
          await model.resumeConversationAI(selectedConversationID)
        },
        loadState: model.selectedConversationLoadState,
        canLoadMoreTimeline: model.canLoadMoreTimeline,
        isLoadingMoreTimeline: model.isLoadingMoreTimeline,
        onLoadMoreTimeline: {
          Task {
            await model.loadMoreTimeline()
          }
        }
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
        draft: $knowledgeEditorDraft,
        errorMessage: model.knowledgeStore.errorMessage,
        onSave: { draft in
          await saveKnowledgeDraft(draft)
        },
        onCancelEditing: {
          knowledgeEditorDraft = nil
        },
        onEdit: { item in
          knowledgeEditorDraft = DashboardKnowledgeEditorDraft(item: item)
        },
        onDelete: { item in
          await deleteKnowledge(item)
        }
      )
    case .analytics:
      AnalyticsPrototypeView(model: model)
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
    case .analytics:
      break
    }
  }

  private var autoSeenTrigger: AutoSeenTrigger {
    AutoSeenTrigger(
      route: activeRoute,
      selectedConversationID: model.selectedConversationID,
      selectedConversationDetailID: model.selectedConversationDetail?.id,
      loadState: model.selectedConversationLoadState,
      hasUnreadActivity: model.selectedConversation?.hasUnreadActivity ?? false,
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
          selectedKnowledgeID = updated.id
          knowledgeEditorDraft = nil
        }
      } else if let created = await model.knowledgeStore.createKnowledge(request) {
        selectedKnowledgeID = created.id
        knowledgeEditorDraft = nil
      }
    } catch {
      model.knowledgeStore.errorMessage = error.localizedDescription
    }
  }

  private func deleteKnowledge(_ item: DashboardKnowledge) async {
    await model.knowledgeStore.deleteKnowledge(id: item.id)
    if selectedKnowledgeID == item.id {
      selectedKnowledgeID = nil
    }
    if knowledgeEditorDraft?.id == item.id {
      knowledgeEditorDraft = nil
    }
  }

}

private struct AutoSeenTrigger: Hashable {
  let route: WorkspaceRoute
  let selectedConversationID: String?
  let selectedConversationDetailID: String?
  let loadState: ConversationSelectionLoadState
  let hasUnreadActivity: Bool
  let shouldAutoMarkSeenOnOpen: Bool
  let scenePhase: ScenePhase
  let controlActiveState: ControlActiveState

  var shouldAttemptAutoSeen: Bool {
    guard case .inbox = route else { return false }
    guard shouldAutoMarkSeenOnOpen else { return false }
    guard let selectedConversationID, selectedConversationDetailID == selectedConversationID else {
      return false
    }
    guard loadState == .loaded else { return false }
    guard hasUnreadActivity else { return false }
    guard scenePhase == .active else { return false }
    return controlActiveState != .inactive
  }
}

private struct WorkspaceLoadingView: View {
  let profileName: String?
  let isConnecting: Bool
  let errorMessage: String?
  let onOpenLauncher: () -> Void

  var body: some View {
    VStack(spacing: 18) {
      if let errorMessage {
        ContentUnavailableView {
          Label("Workspace Unavailable", systemSymbol: .exclamationmarkTriangle)
        } description: {
          Text(errorMessage)
        } actions: {
          Button("Open Launcher", action: onOpenLauncher)
            .buttonStyle(.borderedProminent)
        }
      } else {
        ProgressView()
          .controlSize(.large)

        Text(isConnecting ? "Opening \(profileName ?? "workspace")…" : "Preparing workspace…")
          .font(.title3)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.regularMaterial)
  }
}

private struct AnalyticsNavigationPlaceholderView: View {
  let model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Analytics")
        .font(.title2.weight(.semibold))

      Text("Generate an AI summary for a recent time window, then keep asking follow-up questions in the detail pane.")
        .foregroundStyle(.secondary)

      if model.canUseOpenAIReplyDrafts {
        Text("OpenAI key detected")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      } else {
        Text("Add an OpenAI key in Settings to enable this view.")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      }

      if model.analyticsConversationCount > 0 {
        VStack(alignment: .leading, spacing: 4) {
          Text("\(model.analyticsConversationCount) conversations analyzed")
          Text("\(model.analyticsSourceMessageCount) messages included")
            .foregroundStyle(.secondary)
        }
        .font(.subheadline)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(24)
  }
}

#Preview {
  ContentView(model: AppModel(restoreLastUsedSession: false))
}
