import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  func conversations(in scope: InboxScope) -> [DashboardConversation] {
    inboxStore.conversations(in: scope)
  }

  var canStartAutoResolve: Bool {
    canUseOpenAIReplyDrafts
      && !autoResolveIsRunning
      && !autoResolveCandidateConversations(in: autoResolveSourceScope.inboxScope).isEmpty
  }

  func conversationCount(for scope: InboxScope) -> Int {
    inboxStore.conversationCount(for: scope)
  }

  func clearConversationFilters() {
    inboxStore.clearFilters()
  }

  func autoResolveEligibleScope(_ scope: InboxScope) -> Bool {
    scope == .open || scope == .unseen
  }

  func autoResolveCandidateConversations(
    in scope: InboxScope
  ) -> [DashboardConversation] {
    guard autoResolveEligibleScope(scope) else { return [] }

    let scopedConversations = inboxStore.conversations
      .filter { inboxStore.conversation($0, isIncludedIn: scope) }
      .filter { !$0.isArchived }
      .filter { $0.status == .open }
      .filter { autoResolveShouldReview($0) }

    return scopedConversations.sorted {
      if $0.latestActivityDate != $1.latestActivityDate {
        return $0.latestActivityDate < $1.latestActivityDate
      }

      return ($0.createdAtDate ?? .distantPast) < ($1.createdAtDate ?? .distantPast)
    }
  }

  func autoResolveShouldReview(_ conversation: DashboardConversation) -> Bool {
    guard
      let lastAutoResolveValue = conversation.metadata?[AutoResolveMetadataKey.lastAutoResolve],
      case .string(let lastAutoResolveString) = lastAutoResolveValue,
      let lastAutoResolveDate = DashboardTimestampParser.date(from: lastAutoResolveString)
    else {
      return true
    }

    return conversation.latestActivityDate > lastAutoResolveDate
  }

  func selectedInboxMetadataValue(for key: InboxMetadataFilterKey) -> JSONValue? {
    inboxStore.selectedMetadataValue(for: key)
  }

  func setInboxMetadataFilter(_ value: JSONValue?, for key: InboxMetadataFilterKey) {
    inboxStore.setMetadataFilter(value, for: key)
  }

  func loadMoreConversations(pageBatchLimit: Int) async {
    await inboxStore.loadMoreConversations(
      pageBatchLimit: pageBatchLimit,
      onError: setGlobalErrorMessage
    )
  }

  func loadMoreConversations() async {
    await inboxStore.loadMoreConversations(
      automaticPageLimit: Self.automaticInboxPageLimit,
      onError: setGlobalErrorMessage
    )
  }

  func performBackgroundRefresh() async {
    guard currentProfileID != nil, !isConnecting else { return }
    await refreshInboxSnapshot()

    if selectedConversationID != nil {
      await loadSelectedConversation(force: true, showsLoadingState: false)
    }
  }

  private func refreshInboxSnapshot() async {
    do {
      let page = try await backendClient.conversations.fetchInbox(
        limit: Self.inboxPageSize,
        cursor: nil
      )
      let previousSelectionID = selectedConversationID

      inboxStore.mergeSnapshot(page)

      if let trackedConversation = inboxStore.conversations.first(where: { DashboardReadDebug.isTargetConversation($0.id) }) {
        DashboardReadDebug.log(
          "WorkspaceModel.refreshInboxSnapshot",
          "after merge \(DashboardReadDebug.conversationSummary(trackedConversation)) selection=\(selectedConversationID ?? "nil")"
        )
      } else {
        DashboardReadDebug.log(
          "WorkspaceModel.refreshInboxSnapshot",
          "target missing after merge selection=\(selectedConversationID ?? "nil") pageCount=\(page.items.count)"
        )
      }

      if inboxStore.containsConversation(id: previousSelectionID) {
        selectedConversationID = previousSelectionID
      } else {
        selectedConversationID = nil
        clearSelectedConversationState()
      }
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func scheduleInboxRefresh() {
    inboxRefreshTask?.cancel()
    inboxRefreshTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .seconds(1))
      } catch {
        return
      }

      await self?.refreshInboxSnapshot()
    }
  }

  func handleConversationSearchChange() {
    inboxStore.handleSearchTextChange()
  }

  func startInboxPrefetch() {
    inboxStore.schedulePrefetch(
      automaticPageLimit: Self.automaticInboxPageLimit,
      onError: setGlobalErrorMessage
    )
  }

  func cacheSearchVisitor(_ visitor: DashboardVisitor?) {
    inboxStore.cacheSearchVisitor(visitor)
  }
}
