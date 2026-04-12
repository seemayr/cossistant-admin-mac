import Foundation
import Observation

@Observable @MainActor
final class InboxStore {
  private var configuration: DashboardConfiguration?
  private var inboxPrefetchTask: Task<Void, Never>?
  private var metadataHydrationTask: Task<Void, Never>?

  var searchText = ""
  var sortMode: InboxSortMode = .latestActivity
  var priorityFilter: InboxPriorityFilter = .all
  var sentimentFilter: InboxSentimentFilter = .all
  var metadataFilters: [InboxMetadataFilterKey: JSONValue] = [:]
  var hideEmptyConversations = true
  var hideSeenConversations = false
  var conversations: [DashboardConversation] = []
  var nextCursor: String?
  var loadedPageCount = 0
  var isLoadingMore = false
  var visitorSearchIndex: [String: String] = [:]

  func setConfiguration(_ configuration: DashboardConfiguration?) {
    self.configuration = configuration
  }

  func reset() {
    inboxPrefetchTask?.cancel()
    metadataHydrationTask?.cancel()
    searchText = ""
    sortMode = .latestActivity
    priorityFilter = .all
    sentimentFilter = .all
    metadataFilters = [:]
    hideEmptyConversations = true
    hideSeenConversations = false
    conversations = []
    nextCursor = nil
    loadedPageCount = 0
    isLoadingMore = false
    visitorSearchIndex = [:]
  }

  func applyBootstrap(_ page: DashboardConversationPage) {
    conversations = page.items
    nextCursor = page.nextCursor
    loadedPageCount = 1
    searchText = ""
    visitorSearchIndex = [:]
  }

  var filteredConversations: [DashboardConversation] {
    guard !searchText.isEmpty else { return conversations }

    let query = searchText.localizedLowercase
    return conversations.filter { conversation in
      conversationSearchText(for: conversation).localizedLowercase.contains(query)
    }
  }

  var hasActiveConversationFilters: Bool {
    priorityFilter != .all
      || sentimentFilter != .all
      || !metadataFilters.isEmpty
      || hideSeenConversations
  }

  var availableMetadataFilters: [InboxMetadataFilterSection] {
    InboxMetadataFilterKey.allCases.compactMap { key in
      let options = conversations
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

  var canLoadMore: Bool {
    nextCursor != nil && !isLoadingMore
  }

  func selectedMetadataValue(for key: InboxMetadataFilterKey) -> JSONValue? {
    metadataFilters[key]
  }

  func setMetadataFilter(_ value: JSONValue?, for key: InboxMetadataFilterKey) {
    if let value {
      metadataFilters[key] = value
    } else {
      metadataFilters.removeValue(forKey: key)
    }
  }

  func clearFilters() {
    priorityFilter = .all
    sentimentFilter = .all
    metadataFilters = [:]
    hideEmptyConversations = true
    hideSeenConversations = false
  }

  func conversations(
    in scope: InboxScope,
    isUnread: (DashboardConversation) -> Bool
  ) -> [DashboardConversation] {
    sortConversations(inboxScopedConversations(in: scope, applySearch: true, isUnread: isUnread))
  }

  func conversationCount(
    for scope: InboxScope,
    isUnread: (DashboardConversation) -> Bool
  ) -> Int {
    inboxScopedConversations(in: scope, applySearch: false, isUnread: isUnread).count
  }

  func sortConversations(_ scopedConversations: [DashboardConversation]) -> [DashboardConversation] {
    switch sortMode {
    case .latestActivity:
      return scopedConversations.sorted {
        if $0.latestActivityDate != $1.latestActivityDate {
          return $0.latestActivityDate > $1.latestActivityDate
        }

        return ($0.createdAtDate ?? .distantPast) > ($1.createdAtDate ?? .distantPast)
      }
    case .priority:
      return scopedConversations.sorted {
        if $0.priorityRank != $1.priorityRank {
          return $0.priorityRank > $1.priorityRank
        }

        return $0.latestActivityDate > $1.latestActivityDate
      }
    case .sentiment:
      return scopedConversations.sorted {
        if $0.sentimentSortRank != $1.sentimentSortRank {
          return $0.sentimentSortRank > $1.sentimentSortRank
        }

        return $0.latestActivityDate > $1.latestActivityDate
      }
    case .createdAt:
      return scopedConversations.sorted {
        if $0.createdAtDate != $1.createdAtDate {
          return ($0.createdAtDate ?? .distantPast) > ($1.createdAtDate ?? .distantPast)
        }

        return $0.latestActivityDate > $1.latestActivityDate
      }
    }
  }

  func inboxScopedConversations(
    in scope: InboxScope,
    applySearch: Bool,
    isUnread: (DashboardConversation) -> Bool
  ) -> [DashboardConversation] {
    let searchableConversations = applySearch ? filteredConversations : conversations

    return searchableConversations
      .filter { conversation($0, isIncludedIn: scope, isUnread: isUnread) }
      .filter { priorityFilter.includes($0.priority) }
      .filter { sentimentFilter.includes($0.sentimentCategory) }
      .filter { conversationMatchesMetadataFilters($0) }
      .filter { !hideSeenConversations || isUnread($0) }
      .filter { !hideEmptyConversations || $0.hasContent }
  }

  func conversationMatchesMetadataFilters(_ conversation: DashboardConversation) -> Bool {
    for (key, expectedValue) in metadataFilters {
      guard conversation.metadata?[key.rawValue] == expectedValue else {
        return false
      }
    }

    return true
  }

  func conversation(
    _ conversation: DashboardConversation,
    isIncludedIn scope: InboxScope,
    isUnread: (DashboardConversation) -> Bool
  ) -> Bool {
    switch scope {
    case .all:
      return true
    case .unseen:
      return isUnread(conversation)
    case .open:
      return conversation.status == .open
    case .humanIntervention:
      return conversation.needsHumanIntervention
    case .clarification:
      return conversation.needsClarification
    case .resolved:
      return conversation.status == .resolved
    case .spam:
      return conversation.status == .spam
    }
  }

  func handleSearchTextChange() {
    scheduleMetadataHydrationIfNeeded()
  }

  func loadMoreConversations(
    pageBatchLimit: Int,
    onError: @escaping @MainActor (Error) -> Void
  ) async {
    guard let nextCursor, !isLoadingMore, let configuration else { return }

    print(
      "[Inbox] loadMore start",
      "visible=\(conversations.count)",
      "nextCursor=\(nextCursor)",
      "batchLimit=\(max(1, pageBatchLimit))",
      "loadedPages=\(loadedPageCount)"
    )

    isLoadingMore = true
    defer { isLoadingMore = false }

    let client = CossistantAPIClient(configuration: configuration)
    let result = await loadInboxPages(
      client: client,
      startCursor: nextCursor,
      maxPages: max(1, pageBatchLimit)
    )

    if result.loadedPageCount > 0 {
      self.nextCursor = result.nextCursor
      loadedPageCount += result.loadedPageCount
      scheduleMetadataHydrationIfNeeded()

      print(
        "[Inbox] loadMore success",
        "visible=\(conversations.count)",
        "loadedPages=\(loadedPageCount)",
        "nextCursor=\(self.nextCursor ?? "nil")"
      )
    } else {
      print(
        "[Inbox] loadMore no progress",
        "visible=\(conversations.count)",
        "loadedPages=\(loadedPageCount)",
        "nextCursor=\(self.nextCursor ?? "nil")"
      )
    }

    if let error = result.error {
      print("[Inbox] loadMore error", error.localizedDescription)
      onError(error)
    }
  }

  func loadMoreConversations(
    automaticPageLimit: Int,
    onError: @escaping @MainActor (Error) -> Void
  ) async {
    await loadMoreConversations(
      pageBatchLimit: automaticPageLimit,
      onError: onError
    )
  }

  func schedulePrefetch(
    automaticPageLimit: Int,
    onError: @escaping @MainActor (Error) -> Void
  ) {
    inboxPrefetchTask?.cancel()

    guard nextCursor != nil else { return }

    inboxPrefetchTask = Task { [weak self] in
      guard let self else { return }
      await self.loadMoreConversations(
        pageBatchLimit: max(1, automaticPageLimit - 1),
        onError: onError
      )
    }
  }

  func mergeSnapshot(_ page: DashboardConversationPage) {
    print(
      "[Inbox] refresh snapshot",
      "pageCount=\(page.items.count)",
      "nextCursor=\(page.nextCursor ?? "nil")",
      "loadedPages=\(loadedPageCount)",
      "existing=\(conversations.count)"
    )

    let refreshedIDs = Set(page.items.map(\.id))
    let existingConversationsByID = Dictionary(uniqueKeysWithValues: conversations.map { ($0.id, $0) })
    let mergedPageItems = page.items.map { item in
      guard let existing = existingConversationsByID[item.id] else { return item }

      return DashboardConversation(
        id: item.id,
        status: item.status,
        priority: item.priority,
        organizationId: item.organizationId,
        visitorId: item.visitorId,
        visitor: item.visitor,
        websiteId: item.websiteId,
        metadata: item.metadata,
        channel: item.channel,
        title: item.title,
        sentiment: item.sentiment,
        sentimentConfidence: item.sentimentConfidence,
        visitorRating: item.visitorRating,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        deletedAt: item.deletedAt,
        lastMessageAt: item.lastMessageAt ?? existing.lastMessageAt,
        lastSeenAt: item.lastSeenAt ?? existing.lastSeenAt,
        teamLastSeenAt: item.teamLastSeenAt ?? existing.teamLastSeenAt,
        escalatedAt: item.escalatedAt,
        escalationHandledAt: item.escalationHandledAt,
        aiPausedUntil: item.aiPausedUntil,
        lastMessageTimelineItem: item.lastMessageTimelineItem ?? existing.lastMessageTimelineItem,
        lastTimelineItem: item.lastTimelineItem ?? existing.lastTimelineItem,
        activeClarification: item.activeClarification ?? existing.activeClarification,
        dashboardLocked: item.dashboardLocked,
        dashboardLockReason: item.dashboardLockReason
      )
    }
    let retainedConversations = conversations.filter { !refreshedIDs.contains($0.id) }
    conversations = mergedPageItems + retainedConversations

    if loadedPageCount <= 1 {
      nextCursor = page.nextCursor
    }

    scheduleMetadataHydrationIfNeeded()
  }

  func containsConversation(id: String?) -> Bool {
    guard let id else { return false }
    return conversations.contains(where: { $0.id == id })
  }

  func conversation(withID id: String?) -> DashboardConversation? {
    guard let id else { return nil }
    return conversations.first(where: { $0.id == id })
  }

  func applyRealtimeConversationUpdate(_ payload: DashboardRealtimeConversationUpdatedPayload) {
    guard let index = conversations.firstIndex(where: { $0.id == payload.conversationId }) else {
      return
    }

    let existing = conversations[index]
    conversations[index] = DashboardConversation(
      id: existing.id,
      status: payload.updates.status ?? existing.status,
      priority: payload.updates.priority ?? existing.priority,
      organizationId: existing.organizationId,
      visitorId: existing.visitorId,
      visitor: existing.visitor,
      websiteId: existing.websiteId,
      metadata: existing.metadata,
      channel: existing.channel,
      title: payload.updates.title ?? existing.title,
      sentiment: payload.updates.sentiment ?? existing.sentiment,
      sentimentConfidence: payload.updates.sentimentConfidence ?? existing.sentimentConfidence,
      visitorRating: existing.visitorRating,
      createdAt: existing.createdAt,
      updatedAt: ISO8601DateFormatter.internetDateTime.string(from: .now),
      deletedAt: existing.deletedAt,
      lastMessageAt: existing.lastMessageAt,
      lastSeenAt: existing.lastSeenAt,
      teamLastSeenAt: existing.teamLastSeenAt,
      escalatedAt: payload.updates.escalatedAt ?? existing.escalatedAt,
      escalationHandledAt: payload.updates.escalationHandledAt ?? existing.escalationHandledAt,
      aiPausedUntil: payload.updates.aiPausedUntil ?? existing.aiPausedUntil,
      lastMessageTimelineItem: existing.lastMessageTimelineItem,
      lastTimelineItem: existing.lastTimelineItem,
      activeClarification: payload.updates.activeClarification ?? existing.activeClarification,
      dashboardLocked: existing.dashboardLocked,
      dashboardLockReason: existing.dashboardLockReason
    )
  }

  func applyMutatedConversation(
    _ updatedConversation: DashboardConversationMutation,
    preserveExistingLastMessageAt: Bool = false,
    preserveExistingLastSeenAt: Bool = false
  ) -> Bool {
    guard let index = conversations.firstIndex(where: { $0.id == updatedConversation.id }) else {
      return false
    }

    if updatedConversation.deletedAt != nil {
      conversations.remove(at: index)
      return true
    }

    let existing = conversations[index]
    conversations[index] = DashboardConversation(
      id: updatedConversation.id,
      status: updatedConversation.status,
      priority: updatedConversation.priority,
      organizationId: updatedConversation.organizationId,
      visitorId: updatedConversation.visitorId,
      visitor: existing.visitor,
      websiteId: updatedConversation.websiteId,
      metadata: updatedConversation.metadata,
      channel: updatedConversation.channel,
      title: updatedConversation.title,
      sentiment: updatedConversation.sentiment,
      sentimentConfidence: updatedConversation.sentimentConfidence,
      visitorRating: updatedConversation.visitorRating,
      createdAt: updatedConversation.createdAt,
      updatedAt: updatedConversation.updatedAt,
      deletedAt: updatedConversation.deletedAt,
      lastMessageAt: preserveExistingLastMessageAt
        ? (updatedConversation.lastMessageAt ?? existing.lastMessageAt)
        : updatedConversation.lastMessageAt,
      lastSeenAt: preserveExistingLastSeenAt
        ? (updatedConversation.lastSeenAt ?? existing.lastSeenAt)
        : updatedConversation.lastSeenAt,
      teamLastSeenAt: existing.teamLastSeenAt,
      escalatedAt: updatedConversation.escalatedAt,
      escalationHandledAt: updatedConversation.escalationHandledAt,
      aiPausedUntil: updatedConversation.aiPausedUntil,
      lastMessageTimelineItem: existing.lastMessageTimelineItem,
      lastTimelineItem: existing.lastTimelineItem,
      activeClarification: existing.activeClarification,
      dashboardLocked: existing.dashboardLocked,
      dashboardLockReason: existing.dashboardLockReason
    )
    return false
  }

  func setConversationLastSeenAt(
    conversationID: String,
    lastSeenAt: String?
  ) {
    guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
      return
    }

    conversations[index] = conversations[index].withLastSeenAt(lastSeenAt)
  }

  func setConversationTeamLastSeenAt(
    conversationID: String,
    lastSeenAt: String?
  ) {
    guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
      return
    }

    conversations[index] = conversations[index].withTeamLastSeenAt(lastSeenAt)
  }

  func updateConversationTeamLastSeenAt(
    conversationID: String,
    candidateLastSeenAt: String
  ) {
    guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
      return
    }

    let existing = conversations[index]
    guard let candidateDate = DashboardTimestampParser.date(from: candidateLastSeenAt) else {
      return
    }

    if let existingDate = existing.teamLastSeenAtDate, existingDate >= candidateDate {
      return
    }

    conversations[index] = existing.withTeamLastSeenAt(candidateLastSeenAt)
  }

  func cacheSearchVisitor(_ visitor: DashboardVisitor?) {
    guard let visitor else { return }

    let searchableText = [
      visitor.contact?.name,
      visitor.contact?.email,
      visitor.contact?.externalId,
      visitor.contact?.metadata?.dashboardSearchText,
      visitor.attribution?.dashboardSearchText,
      visitor.currentPage?.dashboardSearchText,
    ]
      .compactMap(Self.nonEmpty(_:))
      .joined(separator: " ")

    var updatedIndex = visitorSearchIndex
    updatedIndex[visitor.id] = searchableText
    visitorSearchIndex = updatedIndex
  }

  private func loadInboxPages(
    client: CossistantAPIClient,
    startCursor: String?,
    maxPages: Int
  ) async -> (nextCursor: String?, loadedPageCount: Int, error: Error?) {
    var cursor = startCursor
    var loadedPageCount = 0
    var terminalError: Error?

    while loadedPageCount < maxPages, let currentCursor = cursor {
      do {
        print(
          "[Inbox] fetch page",
          "pageIndex=\(loadedPageCount + 1)",
          "cursor=\(currentCursor)"
        )
        let page = try await client.fetchInbox(limit: WorkspaceModel.inboxPageSize, cursor: currentCursor)
        let beforeAppend = conversations.count
        appendConversations(page.items)
        let appendedCount = conversations.count - beforeAppend
        loadedPageCount += 1
        cursor = page.nextCursor
        print(
          "[Inbox] fetched page",
          "items=\(page.items.count)",
          "appended=\(appendedCount)",
          "visible=\(conversations.count)",
          "nextCursor=\(cursor ?? "nil")"
        )
      } catch {
        terminalError = error
        print(
          "[Inbox] fetch page failed",
          "pageIndex=\(loadedPageCount + 1)",
          "cursor=\(currentCursor)",
          "error=\(error.localizedDescription)"
        )
        break
      }
    }

    return (cursor, loadedPageCount, terminalError)
  }

  private func appendConversations(_ newItems: [DashboardConversation]) {
    guard !newItems.isEmpty else { return }

    var updatedConversations = conversations
    var existingIDs = Set(updatedConversations.map(\.id))
    var appendedCount = 0
    for item in newItems where existingIDs.insert(item.id).inserted {
      updatedConversations.append(item)
      appendedCount += 1
    }

    conversations = updatedConversations
    print(
      "[Inbox] append conversations",
      "incoming=\(newItems.count)",
      "appended=\(appendedCount)",
      "total=\(conversations.count)"
    )
  }

  private func conversationSearchText(for conversation: DashboardConversation) -> String {
    [
      conversation.visitorDisplayName,
      conversation.displayTitle,
      conversation.visitorSecondaryLine,
      conversation.previewText,
      conversation.metadata?.dashboardSearchText,
      conversation.id,
      conversation.status.label,
      conversation.priority.label,
      conversation.sentiment?.capitalized,
      visitorSearchIndex[conversation.visitorId],
    ]
      .compactMap(Self.nonEmpty(_:))
      .joined(separator: " ")
  }

  private func scheduleMetadataHydrationIfNeeded() {
    guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let configuration else {
      return
    }

    var seenVisitorIDs: Set<String> = []
    let missingVisitorIDs = conversations
      .map(\.visitorId)
      .filter { seenVisitorIDs.insert($0).inserted }
      .filter { visitorSearchIndex[$0] == nil }

    guard !missingVisitorIDs.isEmpty else { return }

    metadataHydrationTask?.cancel()
    metadataHydrationTask = Task { [weak self] in
      let client = CossistantAPIClient(configuration: configuration)

      for visitorID in missingVisitorIDs {
        guard let self, !Task.isCancelled else { return }

        do {
          let visitor = try await client.fetchVisitor(id: visitorID)
          await MainActor.run {
            self.cacheSearchVisitor(visitor)
          }
        } catch {
          continue
        }
      }
    }
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty else {
      return nil
    }

    return trimmed
  }
}
