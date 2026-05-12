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

    return autoResolveBaseCandidateConversations(in: scope)
      .filter(autoResolveMatchesCandidateFilters(_:))
      .sorted {
        if $0.latestActivityDate != $1.latestActivityDate {
          return $0.latestActivityDate < $1.latestActivityDate
        }

        return ($0.createdAtDate ?? .distantPast) < ($1.createdAtDate ?? .distantPast)
      }
  }

  func availableAutoResolveChannelFilters(
    in scope: InboxScope
  ) -> [InboxChannelFilterOption] {
    autoResolveBaseCandidateConversations(in: scope)
      .map(\.channel)
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .reduce(into: Set<String>()) { result, channel in
        result.insert(channel)
      }
      .map(InboxChannelFilterOption.init(value:))
      .sorted {
        $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
      }
  }

  func availableAutoResolveMetadataFilters(
    in scope: InboxScope
  ) -> [InboxMetadataFilterSection] {
    let candidates = autoResolveBaseCandidateConversations(in: scope)
    return InboxMetadataFilterKey.allCases.compactMap { key in
      let options = candidates
        .compactMap { $0.metadata?[key.rawValue] }
        .reduce(into: Set<JSONValue>()) { result, value in
          result.insert(value)
        }
        .sorted {
          $0.dashboardDisplayText.localizedCaseInsensitiveCompare($1.dashboardDisplayText) == .orderedAscending
        }
        .map { InboxMetadataFilterOption(key: key, value: $0) }

      guard !options.isEmpty else { return nil }
      return InboxMetadataFilterSection(key: key, options: options)
    }
  }

  func availableAutoResolveAppVersionFilters(
    in scope: InboxScope
  ) -> [AutoResolveTextFilterOption] {
    autoResolveTextFilterOptions(
      from: autoResolveBaseCandidateConversations(in: scope).compactMap(\.appVersionIndicatorText)
    )
  }

  func availableAutoResolveGameIDFilters(
    in scope: InboxScope
  ) -> [AutoResolveTextFilterOption] {
    autoResolveTextFilterOptions(
      from: autoResolveBaseCandidateConversations(in: scope).compactMap(autoResolveGameID(for:))
    )
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

  private func autoResolveBaseCandidateConversations(
    in scope: InboxScope
  ) -> [DashboardConversation] {
    guard autoResolveEligibleScope(scope) else { return [] }

    return inboxStore.conversations
      .filter { inboxStore.conversation($0, isIncludedIn: scope) }
      .filter { !$0.isArchived }
      .filter { $0.status == .open }
      .filter { autoResolveShouldReview($0) }
  }

  private func autoResolveMatchesCandidateFilters(
    _ conversation: DashboardConversation
  ) -> Bool {
    if !autoResolveStore.priorityFilter.includes(conversation.priority) {
      return false
    }
    if !autoResolveStore.dateRange.includes(
      conversation,
      basis: autoResolveStore.dateBasis,
      now: .now
    ) {
      return false
    }
    if !autoResolveStore.attentionFilter.includes(
      conversation,
      isUnread: conversationHasUnreadActivity(conversation)
    ) {
      return false
    }
    if let channelFilter = autoResolveStore.channelFilter,
       conversation.channel != channelFilter {
      return false
    }
    if let appVersionFilter = autoResolveStore.appVersionFilter,
       conversation.appVersionIndicatorText != appVersionFilter {
      return false
    }
    if let gameIDFilter = autoResolveStore.gameIDFilter,
       autoResolveGameID(for: conversation) != gameIDFilter {
      return false
    }
    for (key, expectedValue) in autoResolveStore.metadataFilters {
      guard conversation.metadata?[key.rawValue] == expectedValue else {
        return false
      }
    }

    return true
  }

  private func autoResolveTextFilterOptions(
    from values: [String]
  ) -> [AutoResolveTextFilterOption] {
    values
      .compactMap(\.nilIfEmpty)
      .reduce(into: Set<String>()) { result, value in
        result.insert(value)
      }
      .map(AutoResolveTextFilterOption.init(value:))
      .sorted {
        $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
      }
  }

  private func autoResolveGameID(
    for conversation: DashboardConversation
  ) -> String? {
    autoResolveMetadataText(
      for: conversation,
      keys: ["gameId", "gameID", "game_id"]
    )
  }

  private func autoResolveMetadataText(
    for conversation: DashboardConversation,
    keys: [String]
  ) -> String? {
    keys
      .lazy
      .compactMap { key in
        guard let value = conversation.metadata?[key], value != .null else { return nil }
        return value.dashboardDisplayText.nilIfEmpty
      }
      .first
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
    guard !isRefreshingInboxSnapshot else { return }
    guard !inboxStore.isLoadingMore else { return }

    isRefreshingInboxSnapshot = true
    defer { isRefreshingInboxSnapshot = false }

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

  func startInboxPrefetch() {
    inboxStore.schedulePrefetch(
      automaticPageLimit: Self.automaticInboxPageLimit,
      onError: setGlobalErrorMessage
    )
  }
}
