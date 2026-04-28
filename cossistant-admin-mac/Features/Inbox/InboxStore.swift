import Foundation
import Observation
import OSLog
import CossistantAdmin

@Observable @MainActor
final class InboxStore {
  private enum DefaultsKey {
    static let locallyDismissedClarificationRequestIDs = "dashboard.locally-dismissed-clarification-request-ids"
  }

  private struct ConversationMetrics {
    let createdAtDate: Date
    let latestActivityDate: Date
    let hasUnreadActivity: Bool
    let priorityRank: Int
    let sentimentCategory: DashboardConversationSentiment
    let sentimentSortRank: Int
  }

  private var configuration: DashboardConfiguration?
  private let defaults: UserDefaults
  private var inboxPrefetchTask: Task<Void, Never>?
  private var metadataHydrationTask: Task<Void, Never>?
  private var locallyDismissedClarificationRequestIDs: Set<String>

  var searchText = "" {
    didSet {
      rebuildDerivedState()
    }
  }
  var sortMode: InboxSortMode = .latestActivity {
    didSet {
      rebuildDerivedState()
    }
  }
  var priorityFilter: InboxPriorityFilter = .all {
    didSet {
      rebuildDerivedState()
    }
  }
  var sentimentFilter: InboxSentimentFilter = .all {
    didSet {
      rebuildDerivedState()
    }
  }
  var channelFilter: String? {
    didSet {
      rebuildDerivedState()
    }
  }
  var metadataFilters: [InboxMetadataFilterKey: JSONValue] = [:] {
    didSet {
      rebuildDerivedState()
    }
  }
  var hideEmptyConversations = true {
    didSet {
      rebuildDerivedState()
    }
  }
  var hideSeenConversations = false {
    didSet {
      rebuildDerivedState()
    }
  }
  var onlyPreviouslyOpenedConversations = false {
    didSet {
      rebuildDerivedState()
    }
  }
  var conversations: [DashboardConversation] = [] {
    didSet {
      rebuildDerivedState()
    }
  }
  var nextCursor: String?
  var loadedPageCount = 0
  var isLoadingMore = false
  var visitorSearchIndex: [String: String] = [:] {
    didSet {
      rebuildDerivedState()
    }
  }
  private var manuallyUnreadConversationIDs: Set<String> = []
  private(set) var filteredConversations: [DashboardConversation] = []
  private(set) var availableChannelFilters: [InboxChannelFilterOption] = []
  private(set) var availableMetadataFilters: [InboxMetadataFilterSection] = []
  private var shownConversationsByScope: [InboxScope: [DashboardConversation]] = [:]
  private var shownConversationCountsByScope: [InboxScope: Int] = [:]
  private var totalConversationCountsByScope: [InboxScope: Int] = [:]

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.locallyDismissedClarificationRequestIDs = Set(
      defaults.stringArray(forKey: DefaultsKey.locallyDismissedClarificationRequestIDs) ?? []
    )
  }

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
    channelFilter = nil
    metadataFilters = [:]
    hideEmptyConversations = true
    hideSeenConversations = false
    onlyPreviouslyOpenedConversations = false
    conversations = []
    nextCursor = nil
    loadedPageCount = 0
    isLoadingMore = false
    visitorSearchIndex = [:]
  }

  func applyBootstrap(_ page: DashboardConversationPage) {
    conversations = page.items.map { applyingLocalClarificationDismissal(to: $0) }
    nextCursor = page.nextCursor
    loadedPageCount = 1
    searchText = ""
    visitorSearchIndex = [:]
  }

  var hasActiveConversationFilters: Bool {
    priorityFilter != .all
      || sentimentFilter != .all
      || channelFilter != nil
      || !metadataFilters.isEmpty
      || hideSeenConversations
      || onlyPreviouslyOpenedConversations
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
    channelFilter = nil
    metadataFilters = [:]
    hideEmptyConversations = true
    hideSeenConversations = false
    onlyPreviouslyOpenedConversations = false
  }

  func setManuallyUnreadConversationIDs(_ conversationIDs: Set<String>) {
    guard manuallyUnreadConversationIDs != conversationIDs else { return }
    manuallyUnreadConversationIDs = conversationIDs
    rebuildDerivedState()
  }

  func conversations(in scope: InboxScope) -> [DashboardConversation] {
    shownConversationsByScope[scope] ?? []
  }

  func shownConversationCount(for scope: InboxScope) -> Int {
    shownConversationCountsByScope[scope] ?? 0
  }

  func conversationCount(for scope: InboxScope) -> Int {
    totalConversationCountsByScope[scope] ?? 0
  }

  func conversationMatchesMetadataFilters(_ conversation: DashboardConversation) -> Bool {
    for (key, expectedValue) in metadataFilters {
      guard conversation.metadata?[key.rawValue] == expectedValue else {
        return false
      }
    }

    return true
  }

  func conversationMatchesChannelFilter(_ conversation: DashboardConversation) -> Bool {
    guard let channelFilter else { return true }
    return conversation.channel == channelFilter
  }

  func conversation(
    _ conversation: DashboardConversation,
    isIncludedIn scope: InboxScope
  ) -> Bool {
    switch scope {
    case .all:
      return !conversation.isArchived
    case .unseen:
      return !conversation.isArchived && hasUnreadActivity(conversation)
    case .updated:
      return !conversation.isArchived && conversation.hasUpdatesSinceLastSeen
    case .open:
      return !conversation.isArchived && conversation.status == .open
    case .humanIntervention:
      return !conversation.isArchived && conversation.needsHumanIntervention
    case .clarification:
      return !conversation.isArchived && conversation.needsClarification
    case .resolved:
      return !conversation.isArchived && conversation.status == .resolved
    case .spam:
      return !conversation.isArchived && conversation.status == .spam
    case .archived:
      return conversation.isArchived
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

    InboxDiagnostics.log(
      "[Inbox] loadMore start visible=\(conversations.count) nextCursor=\(nextCursor) batchLimit=\(max(1, pageBatchLimit)) loadedPages=\(loadedPageCount)"
    )

    isLoadingMore = true
    defer { isLoadingMore = false }

    let backendClient = CossistantAdminClient(configuration: configuration)
    let result = await loadInboxPages(
      backendClient: backendClient,
      startCursor: nextCursor,
      maxPages: max(1, pageBatchLimit)
    )

    if result.loadedPageCount > 0 {
      self.nextCursor = result.nextCursor
      loadedPageCount += result.loadedPageCount
      scheduleMetadataHydrationIfNeeded()

      InboxDiagnostics.log(
        "[Inbox] loadMore success visible=\(conversations.count) loadedPages=\(loadedPageCount) nextCursor=\(self.nextCursor ?? "nil")"
      )
    } else {
      InboxDiagnostics.log(
        "[Inbox] loadMore no progress visible=\(conversations.count) loadedPages=\(loadedPageCount) nextCursor=\(self.nextCursor ?? "nil")"
      )
    }

    if let error = result.error {
      InboxDiagnostics.error("[Inbox] loadMore error \(error.localizedDescription)")
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
    InboxDiagnostics.log(
      "[Inbox] refresh snapshot pageCount=\(page.items.count) nextCursor=\(page.nextCursor ?? "nil") loadedPages=\(loadedPageCount) existing=\(conversations.count)"
    )

    let refreshedIDs = Set(page.items.map(\.id))
    let existingConversationsByID = Dictionary(uniqueKeysWithValues: conversations.map { ($0.id, $0) })
    let mergedPageItems = page.items.map { item in
      guard let existing = existingConversationsByID[item.id] else {
        return applyingLocalClarificationDismissal(to: item)
      }

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
        visitorTitle: item.visitorTitle,
        visitorTitleLanguage: item.visitorTitleLanguage,
        visitorLanguage: item.visitorLanguage,
        titleSource: item.titleSource,
        translationActivatedAt: item.translationActivatedAt,
        translationChargedAt: item.translationChargedAt,
        sentiment: item.sentiment,
        sentimentConfidence: item.sentimentConfidence,
        visitorRating: item.visitorRating,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        deletedAt: item.deletedAt,
        lastMessageAt: item.lastMessageAt ?? existing.lastMessageAt,
        lastSeenAt: item.lastSeenAt ?? existing.lastSeenAt,
        escalatedAt: item.escalatedAt,
        escalationHandledAt: item.escalationHandledAt,
        aiPausedUntil: item.aiPausedUntil,
        lastMessageTimelineItem: item.lastMessageTimelineItem ?? existing.lastMessageTimelineItem,
        lastTimelineItem: item.lastTimelineItem ?? existing.lastTimelineItem,
        activeClarification: locallyVisibleClarification(item.activeClarification),
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

  @discardableResult
  func dismissActiveClarificationLocally(for conversationID: String) -> String? {
    guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
      return nil
    }
    guard let requestID = conversations[index].activeClarification?.requestId else {
      return nil
    }

    locallyDismissedClarificationRequestIDs.insert(requestID)
    persistLocallyDismissedClarificationRequestIDs()

    let existing = conversations[index]
    conversations[index] = DashboardConversation(
      id: existing.id,
      status: existing.status,
      priority: existing.priority,
      organizationId: existing.organizationId,
      visitorId: existing.visitorId,
      visitor: existing.visitor,
      websiteId: existing.websiteId,
      metadata: existing.metadata,
      channel: existing.channel,
      title: existing.title,
      visitorTitle: existing.visitorTitle,
      visitorTitleLanguage: existing.visitorTitleLanguage,
      visitorLanguage: existing.visitorLanguage,
      titleSource: existing.titleSource,
      translationActivatedAt: existing.translationActivatedAt,
      translationChargedAt: existing.translationChargedAt,
      sentiment: existing.sentiment,
      sentimentConfidence: existing.sentimentConfidence,
      visitorRating: existing.visitorRating,
      createdAt: existing.createdAt,
      updatedAt: DashboardTimestampParser.internetDateTimeString(from: .now),
      deletedAt: existing.deletedAt,
      lastMessageAt: existing.lastMessageAt,
      lastSeenAt: existing.lastSeenAt,
      escalatedAt: existing.escalatedAt,
      escalationHandledAt: existing.escalationHandledAt,
      aiPausedUntil: existing.aiPausedUntil,
      lastMessageTimelineItem: existing.lastMessageTimelineItem,
      lastTimelineItem: existing.lastTimelineItem,
      activeClarification: nil,
      dashboardLocked: existing.dashboardLocked,
      dashboardLockReason: existing.dashboardLockReason
    )
    return requestID
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
      visitorTitle: payload.updates.visitorTitle ?? existing.visitorTitle,
      visitorTitleLanguage: payload.updates.visitorTitleLanguage ?? existing.visitorTitleLanguage,
      visitorLanguage: payload.updates.visitorLanguage ?? existing.visitorLanguage,
      titleSource: existing.titleSource,
      translationActivatedAt: payload.updates.translationActivatedAt ?? existing.translationActivatedAt,
      translationChargedAt: payload.updates.translationChargedAt ?? existing.translationChargedAt,
      sentiment: payload.updates.sentiment ?? existing.sentiment,
      sentimentConfidence: payload.updates.sentimentConfidence ?? existing.sentimentConfidence,
      visitorRating: existing.visitorRating,
      createdAt: existing.createdAt,
      updatedAt: DashboardTimestampParser.internetDateTimeString(from: .now),
      deletedAt: existing.deletedAt,
      lastMessageAt: existing.lastMessageAt,
      lastSeenAt: existing.lastSeenAt,
      escalatedAt: payload.updates.escalatedAt ?? existing.escalatedAt,
      escalationHandledAt: payload.updates.escalationHandledAt ?? existing.escalationHandledAt,
      aiPausedUntil: payload.updates.aiPausedUntil ?? existing.aiPausedUntil,
      lastMessageTimelineItem: existing.lastMessageTimelineItem,
      lastTimelineItem: existing.lastTimelineItem,
      activeClarification: locallyVisibleClarification(payload.updates.activeClarification ?? existing.activeClarification),
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
      visitorTitle: updatedConversation.visitorTitle,
      visitorTitleLanguage: updatedConversation.visitorTitleLanguage,
      visitorLanguage: updatedConversation.visitorLanguage,
      titleSource: updatedConversation.titleSource,
      translationActivatedAt: updatedConversation.translationActivatedAt,
      translationChargedAt: updatedConversation.translationChargedAt,
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
      escalatedAt: updatedConversation.escalatedAt,
      escalationHandledAt: updatedConversation.escalationHandledAt,
      aiPausedUntil: updatedConversation.aiPausedUntil,
      lastMessageTimelineItem: existing.lastMessageTimelineItem,
      lastTimelineItem: existing.lastTimelineItem,
      activeClarification: locallyVisibleClarification(existing.activeClarification),
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

  private func rebuildDerivedState() {
    let metricsByID = buildConversationMetrics()

    filteredConversations = buildFilteredConversations()
    availableChannelFilters = buildAvailableChannelFilters()
    availableMetadataFilters = buildAvailableMetadataFilters()

    var shownConversationsByScope: [InboxScope: [DashboardConversation]] = [:]
    var shownConversationCountsByScope: [InboxScope: Int] = [:]
    var totalConversationCountsByScope: [InboxScope: Int] = [:]

    for scope in InboxScope.allCases {
      let visibleConversations = sortConversations(
        inboxScopedConversations(
          in: scope,
          applySearch: true,
          metricsByID: metricsByID
        ),
        metricsByID: metricsByID
      )
      shownConversationsByScope[scope] = visibleConversations
      shownConversationCountsByScope[scope] = visibleConversations.count
      totalConversationCountsByScope[scope] = inboxScopedConversations(
        in: scope,
        applySearch: false,
        metricsByID: metricsByID
      ).count
    }

    self.shownConversationsByScope = shownConversationsByScope
    self.shownConversationCountsByScope = shownConversationCountsByScope
    self.totalConversationCountsByScope = totalConversationCountsByScope
  }

  private func buildFilteredConversations() -> [DashboardConversation] {
    guard !searchText.isEmpty else { return conversations }

    let query = searchText.localizedLowercase
    return conversations.filter { conversation in
      conversationSearchText(for: conversation).localizedLowercase.contains(query)
    }
  }

  private func buildAvailableMetadataFilters() -> [InboxMetadataFilterSection] {
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

  private func buildAvailableChannelFilters() -> [InboxChannelFilterOption] {
    conversations
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

  private func hasUnreadActivity(_ conversation: DashboardConversation) -> Bool {
    manuallyUnreadConversationIDs.contains(conversation.id) || conversation.hasUnreadActivity
  }

  private func loadInboxPages(
    backendClient: CossistantAdminClient,
    startCursor: String?,
    maxPages: Int
  ) async -> (nextCursor: String?, loadedPageCount: Int, error: Error?) {
    var cursor = startCursor
    var loadedPageCount = 0
    var terminalError: Error?

    while loadedPageCount < maxPages, let currentCursor = cursor {
      do {
        InboxDiagnostics.log(
          "[Inbox] fetch page pageIndex=\(loadedPageCount + 1) cursor=\(currentCursor)"
        )
        let page = try await backendClient.conversations.fetchInbox(
          limit: WorkspaceModel.inboxPageSize,
          cursor: currentCursor
        )
        let beforeAppend = conversations.count
        appendConversations(page.items)
        let appendedCount = conversations.count - beforeAppend
        loadedPageCount += 1
        cursor = page.nextCursor
        InboxDiagnostics.log(
          "[Inbox] fetched page items=\(page.items.count) appended=\(appendedCount) visible=\(conversations.count) nextCursor=\(cursor ?? "nil")"
        )
      } catch {
        terminalError = error
        InboxDiagnostics.error(
          "[Inbox] fetch page failed pageIndex=\(loadedPageCount + 1) cursor=\(currentCursor) error=\(error.localizedDescription)"
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
      updatedConversations.append(applyingLocalClarificationDismissal(to: item))
      appendedCount += 1
    }

    conversations = updatedConversations
    InboxDiagnostics.log(
      "[Inbox] append conversations incoming=\(newItems.count) appended=\(appendedCount) total=\(conversations.count)"
    )
  }

  private func buildConversationMetrics() -> [String: ConversationMetrics] {
    Dictionary(
      uniqueKeysWithValues: conversations.map { conversation in
        (conversation.id, conversationMetrics(for: conversation))
      }
    )
  }

  private func conversationMetrics(for conversation: DashboardConversation) -> ConversationMetrics {
    let createdAtDate = conversation.createdAtDate ?? .distantPast
    let updatedAtDate = conversation.updatedAtDate
    let lastMessageAtDate = conversation.lastMessageAtDate
    let latestActivityDate = lastMessageAtDate ?? updatedAtDate ?? createdAtDate
    let hasUnreadActivity =
      manuallyUnreadConversationIDs.contains(conversation.id)
      || (
        conversation.hasContent
          && !conversation.latestMessageWasSentByHumanTeammate
          && {
            guard let effectiveSeenDate = conversation.lastSeenAtDate else {
              return true
            }

            return latestActivityDate > effectiveSeenDate
          }()
      )
    let sentimentCategory = conversation.sentimentCategory

    return ConversationMetrics(
      createdAtDate: createdAtDate,
      latestActivityDate: latestActivityDate,
      hasUnreadActivity: hasUnreadActivity,
      priorityRank: conversation.priorityRank,
      sentimentCategory: sentimentCategory,
      sentimentSortRank: {
        switch sentimentCategory {
        case .negative:
          3
        case .neutral:
          2
        case .positive:
          1
        case .unknown:
          0
        }
      }()
    )
  }

  private func metrics(
    for conversation: DashboardConversation,
    in metricsByID: [String: ConversationMetrics]
  ) -> ConversationMetrics {
    metricsByID[conversation.id] ?? conversationMetrics(for: conversation)
  }

  private func locallyVisibleClarification(
    _ clarification: DashboardConversation.Clarification?
  ) -> DashboardConversation.Clarification? {
    guard let clarification else { return nil }
    return locallyDismissedClarificationRequestIDs.contains(clarification.requestId)
      ? nil
      : clarification
  }

  private func applyingLocalClarificationDismissal(
    to conversation: DashboardConversation
  ) -> DashboardConversation {
    guard conversation.activeClarification != locallyVisibleClarification(conversation.activeClarification) else {
      return conversation
    }

    return DashboardConversation(
      id: conversation.id,
      status: conversation.status,
      priority: conversation.priority,
      organizationId: conversation.organizationId,
      visitorId: conversation.visitorId,
      visitor: conversation.visitor,
      websiteId: conversation.websiteId,
      metadata: conversation.metadata,
      channel: conversation.channel,
      title: conversation.title,
      visitorTitle: conversation.visitorTitle,
      visitorTitleLanguage: conversation.visitorTitleLanguage,
      visitorLanguage: conversation.visitorLanguage,
      titleSource: conversation.titleSource,
      translationActivatedAt: conversation.translationActivatedAt,
      translationChargedAt: conversation.translationChargedAt,
      sentiment: conversation.sentiment,
      sentimentConfidence: conversation.sentimentConfidence,
      visitorRating: conversation.visitorRating,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
      deletedAt: conversation.deletedAt,
      lastMessageAt: conversation.lastMessageAt,
      lastSeenAt: conversation.lastSeenAt,
      escalatedAt: conversation.escalatedAt,
      escalationHandledAt: conversation.escalationHandledAt,
      aiPausedUntil: conversation.aiPausedUntil,
      lastMessageTimelineItem: conversation.lastMessageTimelineItem,
      lastTimelineItem: conversation.lastTimelineItem,
      activeClarification: nil,
      dashboardLocked: conversation.dashboardLocked,
      dashboardLockReason: conversation.dashboardLockReason
    )
  }

  private func persistLocallyDismissedClarificationRequestIDs() {
    defaults.set(
      locallyDismissedClarificationRequestIDs.sorted(),
      forKey: DefaultsKey.locallyDismissedClarificationRequestIDs
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
      let backendClient = CossistantAdminClient(configuration: configuration)

      for visitorID in missingVisitorIDs {
        guard let self, !Task.isCancelled else { return }

        do {
          let visitor = try await backendClient.visitors.fetchVisitor(id: visitorID)
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

private extension InboxStore {
  private func sortConversations(
    _ scopedConversations: [DashboardConversation],
    metricsByID: [String: ConversationMetrics]
  ) -> [DashboardConversation] {
    scopedConversations.sorted { lhs, rhs in
      let lhsMetrics = metrics(for: lhs, in: metricsByID)
      let rhsMetrics = metrics(for: rhs, in: metricsByID)

      switch sortMode {
      case .latestActivity:
        if lhsMetrics.latestActivityDate != rhsMetrics.latestActivityDate {
          return lhsMetrics.latestActivityDate > rhsMetrics.latestActivityDate
        }

        return lhsMetrics.createdAtDate > rhsMetrics.createdAtDate
      case .priority:
        if lhsMetrics.priorityRank != rhsMetrics.priorityRank {
          return lhsMetrics.priorityRank > rhsMetrics.priorityRank
        }

        return lhsMetrics.latestActivityDate > rhsMetrics.latestActivityDate
      case .sentiment:
        if lhsMetrics.sentimentSortRank != rhsMetrics.sentimentSortRank {
          return lhsMetrics.sentimentSortRank > rhsMetrics.sentimentSortRank
        }

        return lhsMetrics.latestActivityDate > rhsMetrics.latestActivityDate
      case .createdAt:
        if lhsMetrics.createdAtDate != rhsMetrics.createdAtDate {
          return lhsMetrics.createdAtDate > rhsMetrics.createdAtDate
        }

        return lhsMetrics.latestActivityDate > rhsMetrics.latestActivityDate
      }
    }
  }

  private func inboxScopedConversations(
    in scope: InboxScope,
    applySearch: Bool,
    metricsByID: [String: ConversationMetrics]
  ) -> [DashboardConversation] {
    let searchableConversations = applySearch ? filteredConversations : conversations

    return searchableConversations.filter { conversation in
      let metrics = metrics(for: conversation, in: metricsByID)
      return conversationMatchesScope(conversation, scope: scope, metrics: metrics)
        && priorityFilter.includes(conversation.priority)
        && sentimentFilter.includes(metrics.sentimentCategory)
        && conversationMatchesChannelFilter(conversation)
        && conversationMatchesMetadataFilters(conversation)
        && (!hideSeenConversations || metrics.hasUnreadActivity)
        && (!onlyPreviouslyOpenedConversations || conversation.lastSeenAtDate != nil)
        && (!hideEmptyConversations || conversation.hasContent)
    }
  }

  private func conversationMatchesScope(
    _ conversation: DashboardConversation,
    scope: InboxScope,
    metrics: ConversationMetrics
  ) -> Bool {
    switch scope {
    case .all:
      return !conversation.isArchived
    case .unseen:
      return !conversation.isArchived && metrics.hasUnreadActivity
    case .updated:
      return !conversation.isArchived && conversation.hasUpdatesSinceLastSeen
    case .open:
      return !conversation.isArchived && conversation.status == .open
    case .humanIntervention:
      return !conversation.isArchived && conversation.needsHumanIntervention
    case .clarification:
      return !conversation.isArchived && conversation.needsClarification
    case .resolved:
      return !conversation.isArchived && conversation.status == .resolved
    case .spam:
      return !conversation.isArchived && conversation.status == .spam
    case .archived:
      return conversation.isArchived
    }
  }
}

private enum InboxDiagnostics {
  private static let logger = Logger(
    subsystem: "com.cossistant.admin",
    category: "Inbox"
  )

  static func log(_ message: @autoclosure () -> String) {
    let line = message()
    logger.debug("\(line, privacy: .public)")
  }

  static func error(_ message: @autoclosure () -> String) {
    let line = message()
    logger.error("\(line, privacy: .public)")
  }
}
