import AppKit
import Foundation
import Observation

enum ConversationSelectionLoadState: Hashable {
  case idle
  case loading
  case loaded
  case failed(String)
}

@Observable @MainActor
final class AppModel {
  private static let inboxPageSize = 100
  private static let automaticInboxPageLimit = 10

  private let configurationStore: AppConfigurationStore
  private let initialProfileID: DashboardProfile.ID?
  private let restoreLastUsedSession: Bool
  private var realtimeClient: DashboardRealtimeClient?
  private var pollingTask: Task<Void, Never>?
  private var inboxRefreshTask: Task<Void, Never>?
  private var selectedConversationRefreshTask: Task<Void, Never>?
  private var inboxPrefetchTask: Task<Void, Never>?
  private var metadataHydrationTask: Task<Void, Never>?
  private var analyticsSummaryTask: Task<Void, Never>?
  private var analyticsFollowUpTask: Task<Void, Never>?

  let contactsStore: ContactsStore
  let knowledgeStore: KnowledgeStore
  var configuration = DashboardConfiguration.production
  var globalSettings: GlobalAppSettings
  var profiles: [DashboardProfile]
  var currentProfileID: DashboardProfile.ID?
  var draftProfileID: DashboardProfile.ID?
  var draftProfileName = ""
  var website: DashboardWebsite?
  var organization: DashboardOrganization?
  var searchText = ""
  var inboxSortMode: InboxSortMode = .latestActivity
  var inboxPriorityFilter: InboxPriorityFilter = .all
  var inboxSentimentFilter: InboxSentimentFilter = .all
  var inboxHideEmptyConversations = true
  var inboxHideSeenConversations = false
  var conversations: [DashboardConversation] = []
  var nextCursor: String?
  var loadedInboxPageCount = 0
  var selectedConversationID: DashboardConversation.ID?
  var selectedConversationDetail: DashboardConversationDetail?
  var selectedVisitor: DashboardVisitor?
  var visitorPresenceByID: [String: DashboardVisitorPresence] = [:]
  var selectedSeenData: [DashboardConversationSeen] = []
  var selectedTimelineItems: [DashboardTimelineItem] = []
  var selectedTimelineNextCursor: String?
  var typingEventsByConversationID: [String: DashboardRealtimeConversationTypingPayload] = [:]
  var aiProcessingByConversationID: [String: DashboardRealtimeAIProcessingState] = [:]
  var showDeveloperLogs = false
  var showMessageTranslations = false
  var selectedConversationLoadState: ConversationSelectionLoadState = .idle
  var visitorSearchIndex: [String: String] = [:]
  var realtimeConnectionState: DashboardRealtimeConnectionState = .disconnected
  var lastRealtimeEventDate: Date?
  var isConnecting = false
  var isLoadingMore = false
  var isLoadingMoreTimeline = false
  var isTranslatingMessages = false
  var isGeneratingReplyDraft = false
  var isCopyingConversationMessages = false
  var hasRestoredSession = false
  var isShowingConfigurationSheet = false
  var translatedMessagesByID: [String: DashboardMessageTranslation] = [:]
  var translationErrorMessage: String?
  var replyDraftErrorMessage: String?
  var globalSettingsStatusMessage: String?
  var errorMessage: String?
  var analyticsRangeMode: AnalyticsSummaryRangeMode = .lastDays
  var analyticsLastHours = 24
  var analyticsLastDays = 7
  var analyticsCustomStartDate = Calendar.current.date(
    byAdding: .day,
    value: -7,
    to: Date()
  ) ?? Date()
  var analyticsCustomEndDate = Date()
  var analyticsSummaryMessages: [AnalyticsSummaryChatMessage] = []
  var analyticsFollowUpDraft = ""
  var analyticsSummaryStatusMessage: String?
  var analyticsSummaryErrorMessage: String?
  var analyticsIsGeneratingSummary = false
  var analyticsIsSendingFollowUp = false
  var analyticsConversationCount = 0
  var analyticsSourceMessageCount = 0
  var analyticsSourceDocument: String?
  var analyticsSummaryResponseID: String?
  var analyticsSummaryGeneratedAt: Date?
  var analyticsSummaryRangeLabel: String?
  var analyticsSummaryUsedChunking = false

  init(
    initialProfileID: DashboardProfile.ID? = nil,
    restoreLastUsedSession: Bool = true
  ) {
    self.configurationStore = AppConfigurationStore()
    self.initialProfileID = initialProfileID
    self.restoreLastUsedSession = restoreLastUsedSession
    self.contactsStore = ContactsStore()
    self.knowledgeStore = KnowledgeStore()
    self.globalSettings = (try? configurationStore.loadGlobalSettings()) ?? .empty
    self.profiles = (try? configurationStore.loadProfiles()) ?? []
    beginCreatingProfile()
  }

  var filteredConversations: [DashboardConversation] {
    guard !searchText.isEmpty else { return conversations }

    let query = searchText.localizedLowercase
    return conversations.filter { conversation in
      conversationSearchText(for: conversation).localizedLowercase.contains(query)
    }
  }

  var hasActiveConversationFilters: Bool {
    inboxPriorityFilter != .all
      || inboxSentimentFilter != .all
      || inboxHideSeenConversations
  }

  var selectedConversation: DashboardConversation? {
    guard let selectedConversationID else { return nil }
    return conversations.first(where: { $0.id == selectedConversationID })
  }

  var selectedTypingEvent: DashboardRealtimeConversationTypingPayload? {
    guard let selectedConversationID else { return nil }
    return typingEventsByConversationID[selectedConversationID]
  }

  var selectedAIProcessingState: DashboardRealtimeAIProcessingState? {
    guard let selectedConversationID else { return nil }
    return aiProcessingByConversationID[selectedConversationID]
  }

  func visitorPresence(for visitorID: String?) -> DashboardVisitorPresence? {
    guard let visitorID else { return nil }
    return visitorPresenceByID[visitorID]
  }

  func typingEvent(for conversationID: String) -> DashboardRealtimeConversationTypingPayload? {
    typingEventsByConversationID[conversationID]
  }

  func aiProcessingState(for conversationID: String) -> DashboardRealtimeAIProcessingState? {
    aiProcessingByConversationID[conversationID]
  }

  var needsConfiguration: Bool {
    website == nil
  }

  var canLoadMore: Bool {
    nextCursor != nil && !isLoadingMore
  }

  var canLoadMoreTimeline: Bool {
    selectedTimelineNextCursor != nil && !isLoadingMoreTimeline
  }

  var currentProfile: DashboardProfile? {
    profiles.first { $0.id == currentProfileID }
  }

  var draftTitle: String {
    draftProfileID == nil ? "New Profile" : "Edit Profile"
  }

  var canSaveDraft: Bool {
    !draftProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && configuration.apiBaseURL != nil
      && !configuration.trimmedPrivateAPIKey.isEmpty
  }

  var connectionSummary: String {
    if let profile = currentProfile, let website, let organization {
      return "\(profile.name) • \(organization.name) • \(website.name)"
    }

    return "Not connected"
  }

  var canUseMessageTranslations: Bool {
    globalSettings.hasGoogleCloudTranslateAPIKey
  }

  var canUseOpenAIReplyDrafts: Bool {
    globalSettings.hasOpenAIAPIKey
  }

  var analyticsSelectedDateRange: AnalyticsSummaryDateRange? {
    switch analyticsRangeMode {
    case .lastHours:
      guard analyticsLastHours > 0,
            let start = Calendar.current.date(byAdding: .hour, value: -analyticsLastHours, to: .now) else {
        return nil
      }
      return AnalyticsSummaryDateRange(start: start, end: .now)
    case .lastDays:
      guard analyticsLastDays > 0,
            let start = Calendar.current.date(byAdding: .day, value: -analyticsLastDays, to: .now) else {
        return nil
      }
      return AnalyticsSummaryDateRange(start: start, end: .now)
    case .custom:
      let start = min(analyticsCustomStartDate, analyticsCustomEndDate)
      let end = max(analyticsCustomStartDate, analyticsCustomEndDate)
      guard start < end else { return nil }
      return AnalyticsSummaryDateRange(start: start, end: end)
    }
  }

  var analyticsCanGenerateSummary: Bool {
    canUseOpenAIReplyDrafts
      && analyticsSelectedDateRange != nil
      && !analyticsIsGeneratingSummary
      && !analyticsIsSendingFollowUp
  }

  var analyticsCanSendFollowUp: Bool {
    analyticsSummaryResponseID != nil
      && analyticsFollowUpDraft.nilIfEmpty != nil
      && !analyticsIsGeneratingSummary
      && !analyticsIsSendingFollowUp
  }

  var shouldAutoMarkSeenOnOpen: Bool {
    globalSettings.autoMarkSeenOnOpen
  }

  func restoreSessionIfNeeded() async {
    guard !hasRestoredSession else { return }
    hasRestoredSession = true
    reloadProfiles()

    if let initialProfileID,
       profiles.contains(where: { $0.id == initialProfileID }) {
      await connect(profileID: initialProfileID)
      return
    }

    guard restoreLastUsedSession,
          let profileID = configurationStore.lastUsedProfileID(),
          profiles.contains(where: { $0.id == profileID }) else {
      return
    }

    await connect(profileID: profileID)
  }

  func reloadProfiles() {
    profiles = (try? configurationStore.loadProfiles()) ?? []
  }

  func clearErrorMessage() {
    errorMessage = nil
  }

  private func setGlobalErrorMessage(_ error: any Error) {
    guard !isIgnorableCancellation(error) else { return }
    errorMessage = error.localizedDescription
  }

  private func isIgnorableCancellation(_ error: any Error) -> Bool {
    if error is CancellationError {
      return true
    }

    if let urlError = error as? URLError, urlError.code == .cancelled {
      return true
    }

    let nsError = error as NSError
    return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
  }

  func reloadGlobalSettings() {
    globalSettings = (try? configurationStore.loadGlobalSettings()) ?? .empty
  }

  func saveGlobalSettings() {
    do {
      try configurationStore.saveGlobalSettings(globalSettings)
      globalSettingsStatusMessage = "Saved global service keys."
      translationErrorMessage = nil
      replyDraftErrorMessage = nil
    } catch {
      globalSettingsStatusMessage = nil
      setGlobalErrorMessage(error)
    }
  }

  func setAutoMarkSeenOnOpen(_ isEnabled: Bool) {
    globalSettings.autoMarkSeenOnOpen = isEnabled
    configurationStore.saveAutoMarkSeenOnOpen(isEnabled)
    globalSettingsStatusMessage = nil
  }

  func conversations(in scope: InboxScope) -> [DashboardConversation] {
    let scopedConversations = inboxScopedConversations(in: scope, applySearch: true)

    switch inboxSortMode {
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

  func conversationCount(for scope: InboxScope) -> Int {
    inboxScopedConversations(in: scope, applySearch: false).count
  }

  func clearConversationFilters() {
    inboxPriorityFilter = .all
    inboxSentimentFilter = .all
    inboxHideEmptyConversations = true
    inboxHideSeenConversations = false
  }

  private func inboxScopedConversations(
    in scope: InboxScope,
    applySearch: Bool
  ) -> [DashboardConversation] {
    let searchableConversations = applySearch ? filteredConversations : conversations

    return searchableConversations
      .filter { scope.includes($0) }
      .filter { inboxPriorityFilter.includes($0.priority) }
      .filter { inboxSentimentFilter.includes($0.sentimentCategory) }
      .filter { !inboxHideSeenConversations || $0.hasUnreadActivity }
      .filter { !inboxHideEmptyConversations || $0.hasContent }
  }

  func beginCreatingProfile() {
    draftProfileID = nil
    draftProfileName = ""
    configuration = .production
  }

  func editProfile(_ profile: DashboardProfile) {
    draftProfileID = profile.id
    draftProfileName = profile.name

    if let savedConfiguration = try? configurationStore.loadConfiguration(profileID: profile.id) {
      configuration = savedConfiguration
    } else {
      configuration = DashboardConfiguration(
        apiBaseURLString: profile.apiBaseURLString,
        privateAPIKey: ""
      )
    }
  }

  func saveDraftProfile() async {
    errorMessage = nil

    let name = draftProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
    let profileID = draftProfileID ?? UUID().uuidString
    let profile = DashboardProfile(
      id: profileID,
      name: name,
      apiBaseURLString: configuration.trimmedAPIBaseURLString
    )

    do {
      try configurationStore.save(profile: profile, privateAPIKey: configuration.trimmedPrivateAPIKey)
      reloadProfiles()
      draftProfileID = profileID

      if currentProfileID == profileID, website != nil {
        await connect(profileID: profileID)
      }
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func deleteProfile(_ profile: DashboardProfile) {
    do {
      try configurationStore.deleteProfile(id: profile.id)
      reloadProfiles()

      if currentProfileID == profile.id {
        clearConnectedState()
      }

      if draftProfileID == profile.id {
        beginCreatingProfile()
      }
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func connect(profileID: DashboardProfile.ID) async {
    errorMessage = nil
    isConnecting = true
    defer { isConnecting = false }

    do {
      guard let profile = profiles.first(where: { $0.id == profileID }),
            let savedConfiguration = try configurationStore.loadConfiguration(profileID: profileID) else {
        throw DashboardAPIError.invalidPrivateAPIKey
      }

      let client = DashboardAPIClient(configuration: savedConfiguration)
      let bootstrap = try await client.fetchBootstrap(limit: Self.inboxPageSize)

      configuration = savedConfiguration
      currentProfileID = profile.id
      website = bootstrap.website
      organization = bootstrap.organization
      conversations = bootstrap.inbox.items
      nextCursor = bootstrap.inbox.nextCursor
      loadedInboxPageCount = 1
      visitorSearchIndex = [:]
      selectedConversationID = nil
      contactsStore.setConfiguration(savedConfiguration)
      knowledgeStore.setConfiguration(savedConfiguration)
      clearSelectedConversationState()
      searchText = ""
      configurationStore.setLastUsedProfileID(profile.id)
      isShowingConfigurationSheet = false
      configureRealtime(
        configuration: savedConfiguration,
        websiteID: bootstrap.website.id,
        organizationID: bootstrap.organization.id
      )
      startPollingLoop()
      startInboxPrefetch()

      await loadSelectedConversation(force: true)
    } catch {
      if website == nil {
        clearConnectedState()
      }
      setGlobalErrorMessage(error)
    }
  }

  func refresh() async {
    guard !isConnecting, let currentProfileID else { return }
    await connect(profileID: currentProfileID)
  }

  func loadMoreConversations(pageBatchLimit: Int) async {
    guard let nextCursor, !isLoadingMore else { return }

    print(
      "[Inbox] loadMore start",
      "visible=\(conversations.count)",
      "nextCursor=\(nextCursor)",
      "batchLimit=\(max(1, pageBatchLimit))",
      "loadedPages=\(loadedInboxPageCount)"
    )

    isLoadingMore = true
    defer { isLoadingMore = false }

    let client = DashboardAPIClient(configuration: configuration)
    let result = await loadInboxPages(
      client: client,
      startCursor: nextCursor,
      maxPages: max(1, pageBatchLimit)
    )

    if result.loadedPageCount > 0 {
      self.nextCursor = result.nextCursor
      loadedInboxPageCount += result.loadedPageCount

      scheduleMetadataHydrationIfNeeded()

      print(
        "[Inbox] loadMore success",
        "visible=\(conversations.count)",
        "loadedPages=\(loadedInboxPageCount)",
        "nextCursor=\(self.nextCursor ?? "nil")"
      )
    } else {
      print(
        "[Inbox] loadMore no progress",
        "visible=\(conversations.count)",
        "loadedPages=\(loadedInboxPageCount)",
        "nextCursor=\(self.nextCursor ?? "nil")"
      )
    }

    if let error = result.error {
      print("[Inbox] loadMore error", error.localizedDescription)
      setGlobalErrorMessage(error)
    }
  }

  func loadMoreConversations() async {
    await loadMoreConversations(pageBatchLimit: Self.automaticInboxPageLimit)
  }

  func loadSelectedConversation(
    force: Bool = false,
    showsLoadingState: Bool = true
  ) async {
    guard let conversationID = selectedConversationID else {
      clearSelectedConversationState()
      return
    }

    if !force,
       selectedConversationDetail?.id == conversationID,
       selectedConversationLoadState == .loaded {
      return
    }

    if showsLoadingState {
      clearSelectedConversationState()
      selectedConversationLoadState = .loading
    }

    do {
      let client = DashboardAPIClient(configuration: configuration)
      async let detail = client.fetchConversation(id: conversationID)
      async let timeline = client.fetchTimeline(conversationID: conversationID)
      async let seenData = client.fetchConversationSeenData(conversationID: conversationID)
      let resolvedVisitor: DashboardVisitor?
      if let visitorID = selectedConversation?.visitorId {
        resolvedVisitor = try await client.fetchVisitor(id: visitorID)
      } else {
        resolvedVisitor = nil
      }
      let (resolvedDetail, resolvedTimeline, resolvedSeenData) = try await (
        detail,
        timeline,
        seenData
      )

      guard selectedConversationID == conversationID else { return }

      selectedConversationDetail = resolvedDetail
      selectedVisitor = resolvedVisitor
      cacheSearchVisitor(resolvedVisitor)
      selectedSeenData = resolvedSeenData
      selectedTimelineItems = resolvedTimeline.items
      selectedTimelineNextCursor = resolvedTimeline.nextCursor
      selectedConversationLoadState = .loaded

      if showMessageTranslations {
        await loadTranslationsForSelectedConversationIfNeeded(force: true)
      }
    } catch {
      guard selectedConversationID == conversationID else { return }
      guard !isIgnorableCancellation(error) else { return }
      if showsLoadingState {
        clearSelectedConversationState()
        selectedConversationLoadState = .failed(error.localizedDescription)
      }
      setGlobalErrorMessage(error)
    }
  }

  func loadMoreTimeline() async {
    guard let conversationID = selectedConversationID,
          let cursor = selectedTimelineNextCursor,
          !isLoadingMoreTimeline else {
      return
    }

    isLoadingMoreTimeline = true
    defer { isLoadingMoreTimeline = false }

    do {
      let client = DashboardAPIClient(configuration: configuration)
      let page = try await client.fetchTimeline(
        conversationID: conversationID,
        cursor: cursor
      )

      guard selectedConversationID == conversationID else { return }

      let existingIDs = Set(selectedTimelineItems.map(\.id))
      let newItems = page.items.filter { !existingIDs.contains($0.id) }
      selectedTimelineItems.append(contentsOf: newItems)
      selectedTimelineNextCursor = page.nextCursor

      if showMessageTranslations {
        await loadTranslationsForSelectedConversationIfNeeded()
      }
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func sendTimelineItem(_ item: DashboardTimelineItemDraft) async {
    guard let conversationID = selectedConversationID else { return }
    errorMessage = nil

    do {
      let client = DashboardAPIClient(configuration: configuration)
      _ = try await client.sendTimelineItem(
        DashboardSendTimelineItemRequest(
          conversationId: conversationID,
          item: item
        )
      )
      await realtimeClient?.send(.conversationTyping(
        conversationId: conversationID,
        isTyping: false,
        visitorPreview: nil
      ))
      await loadSelectedConversation(force: true, showsLoadingState: false)
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func sendMessage(
    text: String,
    visibility: DashboardTimelineItemVisibility,
    attachments: [DashboardComposerAttachment] = []
  ) async {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty || !attachments.isEmpty else { return }

    let senderUserID = website?.availableHumanAgents.first?.id

    do {
      let parts = try await buildMessageParts(
        text: trimmedText,
        attachments: attachments
      )
      await sendTimelineItem(
        .message(
          trimmedText,
          visibility: visibility.rawValue,
          userID: senderUserID,
          parts: parts
        )
      )
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func setShowMessageTranslations(_ isEnabled: Bool) async {
    showMessageTranslations = isEnabled
    translationErrorMessage = nil

    if !isEnabled {
      translatedMessagesByID = [:]
      return
    }

    await loadTranslationsForSelectedConversationIfNeeded(force: true)
  }

  func loadTranslationsForSelectedConversationIfNeeded(
    force: Bool = false
  ) async {
    guard showMessageTranslations else { return }
    guard canUseMessageTranslations else {
      translationErrorMessage = "Add a Google Cloud Translate API key in settings to use translations."
      return
    }

    let messages = selectedTimelineItems
      .filter { $0.type == .message }
      .filter { $0.deletedAt == nil }
      .filter { ($0.renderedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) == false }

    let untranslated = messages.filter { force || translatedMessagesByID[$0.id] == nil }
    guard !untranslated.isEmpty else { return }

    isTranslatingMessages = true
    translationErrorMessage = nil
    defer { isTranslatingMessages = false }

    do {
      let client = GoogleCloudTranslateClient(apiKey: globalSettings.trimmedGoogleCloudTranslateAPIKey)
      let texts = untranslated.compactMap(\.renderedText)
      let translations = try await client.translate(
        texts: texts,
        targetLanguageCode: Self.preferredTranslationLanguageCode
      )

      for (item, translation) in zip(untranslated, translations) {
        translatedMessagesByID[item.id] = translation
      }
    } catch {
      translationErrorMessage = error.localizedDescription
    }
  }

  func copySelectedConversationMessages() async {
    guard !isCopyingConversationMessages else { return }

    isCopyingConversationMessages = true
    defer { isCopyingConversationMessages = false }

    do {
      let export = try await buildSelectedConversationMessagesMarkdown()
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(export, forType: .string)
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func copySelectedConversationFullLog() async {
    guard !isCopyingConversationMessages else { return }

    isCopyingConversationMessages = true
    defer { isCopyingConversationMessages = false }

    do {
      let export = try await buildSelectedConversationMessagesExport()
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(export, forType: .string)
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func generateReplyDraft(from draft: String) async -> String? {
    let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedDraft.isEmpty else { return nil }
    guard canUseOpenAIReplyDrafts else {
      replyDraftErrorMessage = "Add an OpenAI API key in settings to draft translated replies."
      return nil
    }

    isGeneratingReplyDraft = true
    replyDraftErrorMessage = nil
    defer { isGeneratingReplyDraft = false }

    do {
      let transcript = try await buildSelectedConversationMessagesExport()
      let client = OpenAIReplyDraftClient(apiKey: globalSettings.trimmedOpenAIAPIKey)
      return try await client.generateDraft(
        transcript: transcript,
        operatorDraft: trimmedDraft,
        conversationTitle: selectedConversation?.displayTitle,
        websiteName: website?.name
      )
    } catch {
      replyDraftErrorMessage = error.localizedDescription
      return nil
    }
  }

  func resetAnalyticsSummaryConversation() {
    analyticsSummaryTask?.cancel()
    analyticsFollowUpTask?.cancel()
    analyticsSummaryTask = nil
    analyticsFollowUpTask = nil
    analyticsIsGeneratingSummary = false
    analyticsIsSendingFollowUp = false
    analyticsSummaryMessages = []
    analyticsFollowUpDraft = ""
    analyticsSummaryStatusMessage = nil
    analyticsSummaryErrorMessage = nil
    analyticsConversationCount = 0
    analyticsSourceMessageCount = 0
    analyticsSourceDocument = nil
    analyticsSummaryResponseID = nil
    analyticsSummaryGeneratedAt = nil
    analyticsSummaryRangeLabel = nil
    analyticsSummaryUsedChunking = false
  }

  func startAnalyticsSummaryGeneration() {
    guard analyticsSummaryTask == nil else { return }

    analyticsSummaryTask = Task { [weak self] in
      guard let self else { return }
      await self.generateAnalyticsSummary()
      if !Task.isCancelled {
        self.analyticsSummaryTask = nil
      }
    }
  }

  func startAnalyticsFollowUp() {
    guard analyticsFollowUpTask == nil else { return }

    analyticsFollowUpTask = Task { [weak self] in
      guard let self else { return }
      await self.sendAnalyticsFollowUp()
      if !Task.isCancelled {
        self.analyticsFollowUpTask = nil
      }
    }
  }

  func copyAnalyticsSourceDocument() {
    guard let analyticsSourceDocument else { return }

    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(analyticsSourceDocument, forType: .string)
  }

  func generateAnalyticsSummary() async {
    guard !analyticsIsGeneratingSummary else { return }
    guard canUseOpenAIReplyDrafts else {
      analyticsSummaryErrorMessage = "Add an OpenAI API key in settings to summarize recent conversations."
      return
    }
    guard let dateRange = analyticsSelectedDateRange else {
      analyticsSummaryErrorMessage = "Select a valid analytics time range."
      return
    }

    analyticsIsGeneratingSummary = true
    analyticsSummaryErrorMessage = nil
    analyticsSummaryStatusMessage = "Loading conversations…"
    analyticsSummaryMessages = []
    analyticsFollowUpDraft = ""
    analyticsConversationCount = 0
    analyticsSourceMessageCount = 0
    analyticsSourceDocument = nil
    analyticsSummaryResponseID = nil
    analyticsSummaryGeneratedAt = nil
    analyticsSummaryRangeLabel = dateRange.label
    analyticsSummaryUsedChunking = false
    defer { analyticsIsGeneratingSummary = false }

    do {
      let corpus = try await buildAnalyticsConversationCorpus(in: dateRange)
      analyticsConversationCount = corpus.conversationCount
      analyticsSourceMessageCount = corpus.messageCount
      analyticsSourceDocument = corpus.document
      analyticsSummaryRangeLabel = dateRange.label

      let client = OpenAIAnalyticsSummaryClient(apiKey: globalSettings.trimmedOpenAIAPIKey)
      let turn: OpenAIAnalyticsTurn

      if corpus.chunks.count == 1, let chunk = corpus.chunks.first {
        analyticsSummaryStatusMessage = "Generating summary with OpenAI…"
        turn = try await client.startSummaryConversation(
          sourceDocument: chunk,
          workspaceName: website?.name,
          rangeDescription: dateRange.label,
          conversationCount: corpus.conversationCount,
          messageCount: corpus.messageCount
        )
      } else {
        analyticsSummaryUsedChunking = true
        var chunkSummaries: [String] = []

        for (index, chunk) in corpus.chunks.enumerated() {
          analyticsSummaryStatusMessage = "Summarizing batch \(index + 1) of \(corpus.chunks.count)…"
          let summary = try await client.summarizeChunk(
            sourceDocument: chunk,
            workspaceName: website?.name,
            rangeDescription: dateRange.label,
            partIndex: index + 1,
            totalParts: corpus.chunks.count
          )
          chunkSummaries.append("## Batch \(index + 1)\n\(summary)")
        }

        analyticsSummaryStatusMessage = "Combining batch summaries…"
        turn = try await client.synthesizeSummary(
          chunkSummaries: chunkSummaries,
          workspaceName: website?.name,
          rangeDescription: dateRange.label,
          conversationCount: corpus.conversationCount,
          messageCount: corpus.messageCount
        )
      }

      analyticsSummaryMessages = [
        AnalyticsSummaryChatMessage(
          role: .assistant,
          text: turn.text
        ),
      ]
      analyticsSummaryResponseID = turn.responseID
      analyticsSummaryGeneratedAt = .now
      analyticsSummaryStatusMessage = "Analyzed \(corpus.conversationCount) conversations and \(corpus.messageCount) messages."
      analyticsSummaryTask = nil
    } catch {
      if isIgnorableCancellation(error) {
        analyticsSummaryTask = nil
        analyticsSummaryStatusMessage = nil
        analyticsSummaryErrorMessage = nil
        return
      }
      analyticsSummaryStatusMessage = nil
      analyticsSummaryErrorMessage = error.localizedDescription
      analyticsSummaryTask = nil
    }
  }

  func sendAnalyticsFollowUp() async {
    let question = analyticsFollowUpDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !question.isEmpty else { return }
    guard let analyticsSummaryResponseID else {
      analyticsSummaryErrorMessage = "Generate a summary before asking follow-up questions."
      return
    }

    analyticsIsSendingFollowUp = true
    analyticsSummaryErrorMessage = nil
    analyticsSummaryStatusMessage = "Asking follow-up…"
    analyticsFollowUpDraft = ""

    let pendingUserMessage = AnalyticsSummaryChatMessage(
      role: .user,
      text: question
    )
    analyticsSummaryMessages.append(pendingUserMessage)
    defer { analyticsIsSendingFollowUp = false }

    do {
      let client = OpenAIAnalyticsSummaryClient(apiKey: globalSettings.trimmedOpenAIAPIKey)
      let turn = try await client.continueSummaryConversation(
        previousResponseID: analyticsSummaryResponseID,
        userQuestion: question,
        workspaceName: website?.name,
        rangeDescription: analyticsSummaryRangeLabel ?? analyticsSelectedDateRange?.label ?? "Selected range",
        conversationCount: analyticsConversationCount,
        messageCount: analyticsSourceMessageCount
      )
      analyticsSummaryMessages.append(
        AnalyticsSummaryChatMessage(
          role: .assistant,
          text: turn.text
        )
      )
      self.analyticsSummaryResponseID = turn.responseID
      analyticsSummaryStatusMessage = nil
      analyticsFollowUpTask = nil
    } catch {
      if isIgnorableCancellation(error) {
        analyticsFollowUpTask = nil
        analyticsSummaryStatusMessage = nil
        analyticsSummaryErrorMessage = nil
        return
      }
      analyticsSummaryMessages.removeAll { $0.id == pendingUserMessage.id }
      analyticsFollowUpDraft = question
      analyticsSummaryStatusMessage = nil
      analyticsSummaryErrorMessage = error.localizedDescription
      analyticsFollowUpTask = nil
    }
  }

  func markSelectedConversationRead() async {
    guard let conversationID = selectedConversationID else { return }
    await markConversationRead(conversationID)
  }

  func markConversationRead(_ conversationID: DashboardConversation.ID) async {
    errorMessage = nil

    do {
      let client = DashboardAPIClient(configuration: configuration)
      let updatedConversation = try await client.markConversationRead(conversationID: conversationID)
      applyMutatedConversation(updatedConversation)
      if selectedConversationID == conversationID {
        selectedSeenData = try await client.fetchConversationSeenData(conversationID: conversationID)
      }
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func setSelectedConversationTyping(
    isTyping: Bool,
    visitorPreview: String? = nil,
    visitorID: String
  ) async {
    guard let conversationID = selectedConversationID else { return }
    errorMessage = nil

    do {
      await realtimeClient?.send(.conversationTyping(
        conversationId: conversationID,
        isTyping: isTyping,
        visitorPreview: visitorPreview
      ))
      let client = DashboardAPIClient(configuration: configuration)
      _ = try await client.setConversationTyping(
        conversationID: conversationID,
        payload: DashboardConversationTypingRequest(
          isTyping: isTyping,
          visitorPreview: visitorPreview,
          visitorId: visitorID
        )
      )
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func resolveConversation(_ conversationID: DashboardConversation.ID) async {
    await mutateConversation(conversationID) { client in
      try await client.resolveConversation(conversationID: conversationID)
    }
  }

  func reopenConversation(_ conversationID: DashboardConversation.ID) async {
    await mutateConversation(conversationID) { client in
      try await client.reopenConversation(conversationID: conversationID)
    }
  }

  func markConversationSpam(_ conversationID: DashboardConversation.ID) async {
    await mutateConversation(conversationID) { client in
      try await client.markConversationSpam(conversationID: conversationID)
    }
  }

  func markConversationNotSpam(_ conversationID: DashboardConversation.ID) async {
    await mutateConversation(conversationID) { client in
      try await client.markConversationNotSpam(conversationID: conversationID)
    }
  }

  func markConversationUnread(_ conversationID: DashboardConversation.ID) async {
    errorMessage = nil

    do {
      let client = DashboardAPIClient(configuration: configuration)
      let updatedConversation = try await client.markConversationUnread(conversationID: conversationID)
      applyMutatedConversation(updatedConversation)

      if selectedConversationID == conversationID {
        selectedSeenData = try await client.fetchConversationSeenData(conversationID: conversationID)
      }
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func archiveConversation(_ conversationID: DashboardConversation.ID) async {
    await mutateConversation(conversationID) { client in
      try await client.archiveConversation(conversationID: conversationID)
    }
  }

  func unarchiveConversation(_ conversationID: DashboardConversation.ID) async {
    await mutateConversation(conversationID) { client in
      try await client.unarchiveConversation(conversationID: conversationID)
    }
  }

  func updateConversationTitle(
    _ conversationID: DashboardConversation.ID,
    title: String?
  ) async {
    await mutateConversation(conversationID) { client in
      try await client.updateConversationTitle(conversationID: conversationID, title: title)
    }
  }

  func joinConversationEscalation(_ conversationID: DashboardConversation.ID) async {
    await mutateConversation(conversationID) { client in
      try await client.joinConversationEscalation(conversationID: conversationID)
    }
  }

  func pauseConversationAI(
    _ conversationID: DashboardConversation.ID,
    durationMinutes: Int
  ) async {
    await mutateConversation(conversationID) { client in
      try await client.pauseConversationAI(
        conversationID: conversationID,
        durationMinutes: durationMinutes
      )
    }
  }

  func resumeConversationAI(_ conversationID: DashboardConversation.ID) async {
    await mutateConversation(conversationID) { client in
      try await client.resumeConversationAI(conversationID: conversationID)
    }
  }

  func identifySelectedVisitor(
    externalID: String? = nil,
    name: String? = nil,
    email: String? = nil,
    image: URL? = nil,
    metadata: DashboardMetadata? = nil,
    contactOrganizationID: String? = nil
  ) async {
    guard let visitorID = selectedConversation?.visitorId else { return }

    let response = await contactsStore.identifyContact(
      request: DashboardIdentifyContactRequest(
        id: nil,
        visitorId: visitorID,
        externalId: externalID,
        name: name,
        email: email,
        image: image,
        metadata: metadata,
        contactOrganizationId: contactOrganizationID
      )
    )

    if response != nil {
      await loadSelectedConversation(force: true, showsLoadingState: false)
    }
  }

  func prepareConversationUpload(
    contentType: String,
    fileName: String,
    fileExtension: String? = nil,
    path: String? = nil,
    useCdn: Bool = true,
    expiresInSeconds: Int? = nil
  ) async throws -> DashboardSignedUploadResponse {
    guard let organization,
          let website,
          let conversationID = selectedConversationID else {
      throw DashboardStoreError.notConfigured
    }

    let client = DashboardAPIClient(configuration: configuration)
    return try await client.generateUploadURL(
      DashboardSignedUploadRequest(
        contentType: contentType,
        websiteId: website.id,
        scope: .conversation(
          organizationId: organization.id,
          websiteId: website.id,
          conversationId: conversationID
        ),
        path: path,
        fileName: fileName,
        fileExtension: fileExtension,
        useCdn: useCdn,
        expiresInSeconds: expiresInSeconds
      )
    )
  }

  func uploadConversationData(
    _ data: Data,
    contentType: String,
    fileName: String,
    fileExtension: String? = nil,
    path: String? = nil,
    useCdn: Bool = true,
    expiresInSeconds: Int? = nil
  ) async throws -> DashboardSignedUploadResponse {
    let signedUpload = try await prepareConversationUpload(
      contentType: contentType,
      fileName: fileName,
      fileExtension: fileExtension,
      path: path,
      useCdn: useCdn,
      expiresInSeconds: expiresInSeconds
    )

    let client = DashboardAPIClient(configuration: configuration)
    try await client.upload(data: data, using: signedUpload)
    return signedUpload
  }

  private func buildMessageParts(
    text: String,
    attachments: [DashboardComposerAttachment]
  ) async throws -> [JSONValue] {
    var parts: [JSONValue] = [
      .object([
        "type": .string("text"),
        "text": .string(text),
      ])
    ]

    guard !attachments.isEmpty else { return parts }

    var uploadedParts: [JSONValue] = []
    for attachment in attachments {
      let upload = try await uploadConversationData(
        attachment.data,
        contentType: attachment.contentType,
        fileName: attachment.fileName,
        fileExtension: URL(fileURLWithPath: attachment.fileName).pathExtension.nilIfEmpty
      )

      uploadedParts.append(
        .object([
          "type": .string(attachment.isImage ? "image" : "file"),
          "url": .string(upload.publicURL.absoluteString),
          "mediaType": .string(attachment.contentType),
          "filename": .string(attachment.fileName),
          "size": .number(Double(attachment.fileSizeBytes)),
        ])
      )
    }

    parts.append(contentsOf: uploadedParts)
    return parts
  }

  func disconnectCurrentProfile() {
    stopBackgroundWork()
    clearConnectedState()
    configurationStore.setLastUsedProfileID(nil)
  }

  private func clearConnectedState() {
    inboxPrefetchTask?.cancel()
    metadataHydrationTask?.cancel()
    currentProfileID = nil
    website = nil
    organization = nil
    conversations = []
    nextCursor = nil
    loadedInboxPageCount = 0
    selectedConversationID = nil
    visitorSearchIndex = [:]
    contactsStore.setConfiguration(nil)
    knowledgeStore.setConfiguration(nil)
    clearSelectedConversationState()
    searchText = ""
    visitorPresenceByID = [:]
    typingEventsByConversationID = [:]
    aiProcessingByConversationID = [:]
    realtimeConnectionState = .disconnected
    lastRealtimeEventDate = nil
  }

  private func clearSelectedConversationState() {
    selectedConversationDetail = nil
    selectedVisitor = nil
    selectedSeenData = []
    selectedTimelineItems = []
    selectedTimelineNextCursor = nil
    translatedMessagesByID = [:]
    translationErrorMessage = nil
    replyDraftErrorMessage = nil
    selectedConversationLoadState = .idle
  }

  private func configureRealtime(
    configuration: DashboardConfiguration,
    websiteID: String,
    organizationID: String
  ) {
    guard let webSocketURL = makeRealtimeURL(
      configuration: configuration,
      websiteID: websiteID
    ) else {
      realtimeConnectionState = .failed(DashboardAPIError.invalidBaseURL.localizedDescription)
      return
    }

    Task {
      await realtimeClient?.disconnect()
    }

    let client = DashboardRealtimeClient(
      webSocketURL: webSocketURL,
      websiteID: websiteID,
      organizationID: organizationID,
      onConnectionStateChange: { [weak self] state in
        self?.realtimeConnectionState = state
      },
      onEvent: { [weak self] event in
        self?.handleRealtimeEvent(event)
      }
    )

    realtimeClient = client

    Task {
      await client.connect()
    }
  }

  private func startPollingLoop() {
    pollingTask?.cancel()
    pollingTask = Task { [weak self] in
      while let self, !Task.isCancelled {
        let interval: Duration = self.realtimeConnectionState.isConnected ? .seconds(90) : .seconds(30)

        do {
          try await Task.sleep(for: interval)
        } catch {
          return
        }

        await self.performBackgroundRefresh()
      }
    }
  }

  private func stopBackgroundWork() {
    pollingTask?.cancel()
    inboxRefreshTask?.cancel()
    selectedConversationRefreshTask?.cancel()
    pollingTask = nil
    inboxRefreshTask = nil
    selectedConversationRefreshTask = nil

    Task {
      await realtimeClient?.disconnect()
    }
    realtimeClient = nil
  }

  private func makeRealtimeURL(
    configuration: DashboardConfiguration,
    websiteID: String
  ) -> URL? {
    guard configuration.trimmedPrivateAPIKey.hasPrefix("sk_"),
          let baseURL = configuration.apiBaseURL,
          var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      return nil
    }

    switch components.scheme {
    case "https":
      components.scheme = "wss"
    case "http":
      components.scheme = "ws"
    default:
      return nil
    }

    let trimmedPath = components.path.replacingOccurrences(of: "/v1", with: "")
    components.path = "\(trimmedPath)/ws".replacingOccurrences(of: "//", with: "/")
    components.queryItems = [
      URLQueryItem(name: "token", value: configuration.trimmedPrivateAPIKey),
      URLQueryItem(name: "websiteId", value: websiteID),
    ]

    return components.url
  }

  private func performBackgroundRefresh() async {
    guard currentProfileID != nil, !isConnecting else { return }
    await refreshInboxSnapshot()

    if selectedConversationID != nil {
      await loadSelectedConversation(force: true, showsLoadingState: false)
    }
  }

  private func refreshInboxSnapshot() async {
    do {
      let client = DashboardAPIClient(configuration: configuration)
      let page = try await client.fetchInbox(
        limit: Self.inboxPageSize,
        cursor: nil
      )
      print(
        "[Inbox] refresh snapshot",
        "pageCount=\(page.items.count)",
        "nextCursor=\(page.nextCursor ?? "nil")",
        "loadedPages=\(loadedInboxPageCount)",
        "existing=\(conversations.count)"
      )
      let previousSelectionID = selectedConversationID
      let refreshedIDs = Set(page.items.map(\.id))
      let retainedConversations = conversations.filter { !refreshedIDs.contains($0.id) }
      conversations = page.items + retainedConversations

      if loadedInboxPageCount <= 1 {
        nextCursor = page.nextCursor
      }

      if conversations.contains(where: { $0.id == previousSelectionID }) {
        selectedConversationID = previousSelectionID
      } else {
        selectedConversationID = nil
        clearSelectedConversationState()
      }

      scheduleMetadataHydrationIfNeeded()
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  private func scheduleInboxRefresh() {
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
    scheduleMetadataHydrationIfNeeded()
  }

  private func startInboxPrefetch() {
    inboxPrefetchTask?.cancel()

    guard nextCursor != nil else { return }

    inboxPrefetchTask = Task { [weak self] in
      guard let self else { return }
      await self.loadMoreConversations(pageBatchLimit: Self.automaticInboxPageLimit - 1)
    }
  }

  private func loadInboxPages(
    client: DashboardAPIClient,
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
        let page = try await client.fetchInbox(limit: Self.inboxPageSize, cursor: currentCursor)
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
    guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

    var seenVisitorIDs: Set<String> = []
    let missingVisitorIDs = conversations
      .map(\.visitorId)
      .filter { seenVisitorIDs.insert($0).inserted }
      .filter { visitorSearchIndex[$0] == nil }

    guard !missingVisitorIDs.isEmpty else { return }

    metadataHydrationTask?.cancel()
    let configuration = configuration

    metadataHydrationTask = Task { [weak self] in
      let client = DashboardAPIClient(configuration: configuration)

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

  private func cacheSearchVisitor(_ visitor: DashboardVisitor?) {
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

  private static func nonEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty else {
      return nil
    }

    return trimmed
  }

  private func scheduleSelectedConversationRefresh() {
    selectedConversationRefreshTask?.cancel()
    selectedConversationRefreshTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(700))
      } catch {
        return
      }

        await self?.loadSelectedConversation(force: true, showsLoadingState: false)
    }
  }

  private func handleRealtimeEvent(_ event: DashboardRealtimeEvent) {
    lastRealtimeEventDate = .now

    switch event {
    case .connectionEstablished(let payload):
      realtimeConnectionState = .connected(connectionID: payload.connectionId)
    case .conversationSeen(let payload):
      applyRealtimeSeen(payload)
    case .conversationTyping(let payload):
      updateTypingEvent(payload)
    case .aiAgentProcessingStarted(let payload):
      updateAIProcessingState(
        conversationID: payload.conversationId,
        state: DashboardRealtimeAIProcessingState(
          aiAgentId: payload.aiAgentId,
          phase: payload.phase ?? "thinking",
          message: nil,
          toolName: nil,
          toolState: nil
        )
      )
    case .aiAgentProcessingProgress(let payload):
      updateAIProcessingState(
        conversationID: payload.conversationId,
        state: DashboardRealtimeAIProcessingState(
          aiAgentId: payload.aiAgentId,
          phase: payload.phase,
          message: payload.message,
          toolName: payload.tool?.toolName,
          toolState: payload.tool?.state
        )
      )
    case .aiAgentProcessingCompleted(let payload):
      clearAIProcessingState(for: payload.conversationId)
    case .timelineItemCreated(let payload):
      clearTypingEvent(for: payload.conversationId)
      if payload.item.type == .message, payload.item.aiAgentId != nil {
        clearAIProcessingState(for: payload.conversationId)
      }
      applyRealtimeTimelineItem(payload.item, conversationID: payload.conversationId)
      scheduleInboxRefresh()
      if payload.conversationId == selectedConversationID {
        scheduleSelectedConversationRefresh()
      }
    case .timelineItemUpdated(let payload):
      applyRealtimeTimelineItem(payload.item, conversationID: payload.conversationId)
      if payload.conversationId == selectedConversationID {
        scheduleSelectedConversationRefresh()
      }
    case .conversationCreated:
      scheduleInboxRefresh()
    case .conversationUpdated(let payload):
      applyRealtimeConversationUpdate(payload)
      scheduleInboxRefresh()
      if payload.conversationId == selectedConversationID {
        scheduleSelectedConversationRefresh()
      }
    case .visitorIdentified(let payload):
      if payload.visitorId == selectedConversation?.visitorId {
        selectedVisitor = payload.visitor
      }
      scheduleInboxRefresh()
    case .visitorConnected(let payload):
      applyVisitorPresence(
        DashboardVisitorPresence(
          visitorId: payload.visitorId,
          state: .active,
          lastSeenAt: ISO8601DateFormatter.internetDateTime.string(from: .now)
        )
      )
    case .visitorDisconnected(let payload):
      applyVisitorPresence(
        DashboardVisitorPresence(
          visitorId: payload.visitorId,
          state: .inactive,
          lastSeenAt: ISO8601DateFormatter.internetDateTime.string(from: .now)
        )
      )
    case .visitorPresenceUpdate(let payload):
      applyVisitorPresence(
        DashboardVisitorPresence(
          visitorId: payload.visitorId,
          state: .active,
          lastSeenAt: ISO8601DateFormatter.internetDateTime.string(from: .now)
        )
      )
    case .serverError(let message):
      errorMessage = message
    case .unsupported:
      break
    }
  }

  private func applyRealtimeTimelineItem(
    _ item: DashboardTimelineItem,
    conversationID: String
  ) {
    guard conversationID == selectedConversationID else { return }

    if let existingIndex = selectedTimelineItems.firstIndex(where: { $0.id == item.id }) {
      selectedTimelineItems[existingIndex] = item
    } else {
      selectedTimelineItems.insert(item, at: 0)
    }
  }

  private func updateTypingEvent(_ payload: DashboardRealtimeConversationTypingPayload) {
    if payload.isTyping {
      var updatedEvents = typingEventsByConversationID
      updatedEvents[payload.conversationId] = payload
      typingEventsByConversationID = updatedEvents
      return
    }

    clearTypingEvent(for: payload.conversationId)
  }

  private func clearTypingEvent(for conversationID: String) {
    guard typingEventsByConversationID[conversationID] != nil else { return }
    var updatedEvents = typingEventsByConversationID
    updatedEvents.removeValue(forKey: conversationID)
    typingEventsByConversationID = updatedEvents
  }

  private func updateAIProcessingState(
    conversationID: String,
    state: DashboardRealtimeAIProcessingState
  ) {
    var updatedStates = aiProcessingByConversationID
    updatedStates[conversationID] = state
    aiProcessingByConversationID = updatedStates
  }

  private func clearAIProcessingState(for conversationID: String) {
    guard aiProcessingByConversationID[conversationID] != nil else { return }
    var updatedStates = aiProcessingByConversationID
    updatedStates.removeValue(forKey: conversationID)
    aiProcessingByConversationID = updatedStates
  }

  private func applyRealtimeSeen(_ payload: DashboardRealtimeConversationSeenPayload) {
    guard payload.conversationId == selectedConversationID else { return }

    let item = DashboardConversationSeen(
      id: "\(payload.conversationId):\(payload.actorType):\(payload.actorId)",
      conversationId: payload.conversationId,
      userId: payload.userId,
      visitorId: payload.visitorId,
      aiAgentId: payload.aiAgentId,
      lastSeenAt: payload.lastSeenAt,
      createdAt: payload.lastSeenAt,
      updatedAt: payload.lastSeenAt,
      deletedAt: nil
    )

    if let existingIndex = selectedSeenData.firstIndex(where: { $0.id == item.id }) {
      selectedSeenData[existingIndex] = item
    } else {
      selectedSeenData.insert(item, at: 0)
    }
  }

  private func applyRealtimeConversationUpdate(
    _ payload: DashboardRealtimeConversationUpdatedPayload
  ) {
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

  private func applyVisitorPresence(_ presence: DashboardVisitorPresence) {
    visitorPresenceByID[presence.visitorId] = presence
  }

  private func mutateConversation(
    _ conversationID: DashboardConversation.ID,
    using operation: (DashboardAPIClient) async throws -> DashboardConversationMutation
  ) async {
    errorMessage = nil

    do {
      let client = DashboardAPIClient(configuration: configuration)
      let updatedConversation = try await operation(client)
      applyMutatedConversation(updatedConversation)

      if selectedConversationID == conversationID {
        await loadSelectedConversation(force: true, showsLoadingState: false)
      }
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  private func applyMutatedConversation(_ updatedConversation: DashboardConversationMutation) {
    guard let index = conversations.firstIndex(where: { $0.id == updatedConversation.id }) else {
      return
    }

    if updatedConversation.deletedAt != nil {
      conversations.remove(at: index)

      if selectedConversationID == updatedConversation.id {
        selectedConversationID = nil
        clearSelectedConversationState()
      }
      return
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
      lastMessageAt: updatedConversation.lastMessageAt,
      lastSeenAt: updatedConversation.lastSeenAt,
      escalatedAt: updatedConversation.escalatedAt,
      escalationHandledAt: updatedConversation.escalationHandledAt,
      aiPausedUntil: updatedConversation.aiPausedUntil,
      lastMessageTimelineItem: existing.lastMessageTimelineItem,
      lastTimelineItem: existing.lastTimelineItem,
      activeClarification: existing.activeClarification,
      dashboardLocked: existing.dashboardLocked,
      dashboardLockReason: existing.dashboardLockReason
    )
  }

  private func updateConversationLastSeenAt(
    conversationID: String,
    lastSeenAt: String
  ) {
    guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
      return
    }

    conversations[index] = conversations[index].withLastSeenAt(lastSeenAt)
  }

  private func buildAnalyticsConversationCorpus(
    in dateRange: AnalyticsSummaryDateRange
  ) async throws -> AnalyticsConversationCorpus {
    try Task.checkCancellation()

    guard website != nil else {
      throw DashboardStoreError.notConfigured
    }

    let client = DashboardAPIClient(configuration: configuration)
    let candidateConversations = try await fetchAnalyticsConversations(
      in: dateRange,
      client: client
    )

    guard !candidateConversations.isEmpty else {
      throw ConversationAssistantError.noAnalyticsMessages
    }

    var sections: [String] = []
    var messageCount = 0

    for (index, conversation) in candidateConversations.enumerated() {
      try Task.checkCancellation()
      analyticsSummaryStatusMessage = "Collecting message histories (\(index + 1)/\(candidateConversations.count))…"
      let items = try await fetchAnalyticsMessageItems(
        conversationID: conversation.id,
        client: client,
        maxPages: 20
      )

      guard let section = buildAnalyticsConversationSection(
        for: conversation,
        items: items
      ) else {
        continue
      }

      sections.append(section.markdown)
      messageCount += section.messageCount
    }

    guard !sections.isEmpty, messageCount > 0 else {
      throw ConversationAssistantError.noAnalyticsMessages
    }

    let header = analyticsDocumentHeader(
      for: dateRange,
      conversationCount: sections.count,
      messageCount: messageCount
    )
    let document = ([header] + sections)
      .joined(separator: "\n\n---\n\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return AnalyticsConversationCorpus(
      document: document,
      chunks: analyticsSourceChunks(
        from: sections,
        header: header
      ),
      conversationCount: sections.count,
      messageCount: messageCount
    )
  }

  private func fetchAnalyticsConversations(
    in dateRange: AnalyticsSummaryDateRange,
    client: DashboardAPIClient
  ) async throws -> [DashboardConversation] {
    var collected: [DashboardConversation] = []
    var seenIDs = Set<String>()
    var cursor: String?
    var pageIndex = 0

    repeat {
      try Task.checkCancellation()
      analyticsSummaryStatusMessage = "Loading conversations (page \(pageIndex + 1))…"
      let page = try await client.fetchInbox(
        limit: Self.inboxPageSize,
        cursor: cursor
      )
      pageIndex += 1

      let uniqueItems = page.items.filter { seenIDs.insert($0.id).inserted }
      collected.append(
        contentsOf: uniqueItems.filter {
          conversation($0, overlaps: dateRange)
        }
      )

      cursor = page.nextCursor

      if uniqueItems.allSatisfy({ !conversationCouldAppearLaterInRange($0, dateRange: dateRange) }) {
        cursor = nil
      }
    } while cursor != nil

    return collected.sorted {
      $0.latestActivityDate > $1.latestActivityDate
    }
  }

  private func conversation(
    _ conversation: DashboardConversation,
    overlaps dateRange: AnalyticsSummaryDateRange
  ) -> Bool {
    let activityDate = conversation.latestActivityDate
    return activityDate >= dateRange.start && activityDate <= dateRange.end
  }

  private func conversationCouldAppearLaterInRange(
    _ conversation: DashboardConversation,
    dateRange: AnalyticsSummaryDateRange
  ) -> Bool {
    conversation.latestActivityDate >= dateRange.start
  }

  private func fetchAnalyticsMessageItems(
    conversationID: String,
    client: DashboardAPIClient,
    maxPages: Int
  ) async throws -> [DashboardTimelineItem] {
    var collectedItems: [DashboardTimelineItem] = []
    var seenIDs = Set<String>()
    var cursor: String?
    var pageCount = 0

    repeat {
      try Task.checkCancellation()
      let page = try await client.fetchTimeline(
        conversationID: conversationID,
        limit: 100,
        cursor: cursor
      )

      for item in page.items where item.type == .message && item.deletedAt == nil {
        if seenIDs.insert(item.id).inserted {
          collectedItems.append(item)
        }
      }

      cursor = page.nextCursor
      pageCount += 1
    } while cursor != nil && pageCount < maxPages

    return collectedItems.sorted {
      ($0.createdAtDate ?? .distantPast) < ($1.createdAtDate ?? .distantPast)
    }
  }

  private func buildAnalyticsConversationSection(
    for conversation: DashboardConversation,
    items: [DashboardTimelineItem]
  ) -> AnalyticsConversationSection? {
    var lines = [
      "## Conversation",
      "",
      "- Status: \(conversation.status.label)",
      "- Priority: \(conversation.priority.label)",
      "- Visitor ID: \(conversation.visitorId)",
      "",
      "### Messages",
    ]
    var messageCount = 0

    for item in items {
      let text = item.renderedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let attachmentSummary = markdownAttachmentSummary(for: item)
      guard !text.isEmpty || attachmentSummary != nil else {
        continue
      }

      let senderLabel = analyticsSenderLabel(
        for: item
      )
      let visibilitySuffix = item.visibility == .private ? " [private]" : ""

      lines.append("- \(senderLabel)\(visibilitySuffix):")

      if !text.isEmpty {
        lines.append(indentedMarkdownText(text, indentation: "  "))
      }

      if let attachmentSummary {
        lines.append("  _\(attachmentSummary)_")
      }

      messageCount += 1
    }

    guard messageCount > 0 else { return nil }
    return AnalyticsConversationSection(
      markdown: lines.joined(separator: "\n"),
      messageCount: messageCount
    )
  }

  private func analyticsSenderLabel(
    for item: DashboardTimelineItem
  ) -> String {
    let sender = transcriptSender(for: item)

    switch sender.kind {
    case .visitor:
      return "Visitor"
    case .human:
      return "Admin"
    case .ai:
      return "Agent"
    case .system:
      return "System"
    }
  }

  private func analyticsDocumentHeader(
    for dateRange: AnalyticsSummaryDateRange,
    conversationCount: Int,
    messageCount: Int
  ) -> String {
    [
      "# Recent Support Conversation Digest",
      "",
      "- Workspace: \(website?.name ?? "Cossistant")",
      "- Range: \(dateRange.label)",
      "- Conversations: \(conversationCount)",
      "- Messages: \(messageCount)",
      "- Generated at: \(Date.now.formatted(.dateTime.year().month().day().hour().minute()))",
    ].joined(separator: "\n")
  }

  private func analyticsSourceChunks(
    from sections: [String],
    header: String
  ) -> [String] {
    let directDocument = ([header] + sections)
      .joined(separator: "\n\n---\n\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let directLimit = 90_000
    let chunkLimit = 55_000

    if directDocument.count <= directLimit {
      return [directDocument]
    }

    let normalizedSections = sections.flatMap {
      splitAnalyticsSectionIfNeeded(
        $0,
        limit: chunkLimit - header.count - 128
      )
    }

    var groupedSections: [[String]] = []
    var currentGroup: [String] = []
    var currentLength = header.count

    for section in normalizedSections {
      let projectedLength = currentLength + section.count + 12

      if projectedLength > chunkLimit, !currentGroup.isEmpty {
        groupedSections.append(currentGroup)
        currentGroup = [section]
        currentLength = header.count + section.count
      } else {
        currentGroup.append(section)
        currentLength = projectedLength
      }
    }

    if !currentGroup.isEmpty {
      groupedSections.append(currentGroup)
    }

    let totalGroups = groupedSections.count
    return groupedSections.enumerated().map { index, group in
      [
        header,
        "",
        "_Batch \(index + 1) of \(totalGroups)_",
        "",
        group.joined(separator: "\n\n---\n\n"),
      ].joined(separator: "\n")
    }
  }

  private func splitAnalyticsSectionIfNeeded(
    _ section: String,
    limit: Int
  ) -> [String] {
    guard section.count > limit, limit > 1_000 else {
      return [section]
    }

    var chunks: [String] = []
    var currentLines: [String] = []
    var currentLength = 0

    for line in section.split(separator: "\n", omittingEmptySubsequences: false) {
      let stringLine = String(line)
      let projectedLength = currentLength + stringLine.count + 1

      if projectedLength > limit, !currentLines.isEmpty {
        chunks.append(currentLines.joined(separator: "\n"))
        currentLines = [stringLine]
        currentLength = stringLine.count
      } else {
        currentLines.append(stringLine)
        currentLength = projectedLength
      }
    }

    if !currentLines.isEmpty {
      chunks.append(currentLines.joined(separator: "\n"))
    }

    return chunks
  }

  private func indentedMarkdownText(
    _ text: String,
    indentation: String
  ) -> String {
    text
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { "\(indentation)\($0)" }
      .joined(separator: "\n")
  }

  private func buildSelectedConversationMessagesMarkdown() async throws -> String {
    guard let conversation = selectedConversation else {
      throw ConversationAssistantError.noConversationSelected
    }

    let items = try await fetchSelectedConversationMessageItems(maxPages: 20)
    let headerLines = [
      "# \(conversation.displayTitle)",
      "",
      "- Visitor: \(conversation.visitorDisplayName)",
      "- Status: \(conversation.status.label)",
      "- Priority: \(conversation.priority.label)",
      "",
    ]

    let messageBlocks = items.compactMap { item -> String? in
      let text = item.renderedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let attachmentSummary = markdownAttachmentSummary(for: item)

      guard !text.isEmpty || attachmentSummary != nil else {
        return nil
      }

      let sender = DashboardTimelinePresentation.senderDisplay(
        for: transcriptSender(for: item),
        website: website,
        conversation: conversation,
        visitor: selectedVisitor
      )

      var lines = ["## \(sender.name) · \(item.createdAt)"]

      if !text.isEmpty {
        lines.append(text)
      }

      if let attachmentSummary {
        lines.append("_\(attachmentSummary)_")
      }

      return lines.joined(separator: "\n")
    }

    return (headerLines + messageBlocks)
      .joined(separator: "\n\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func buildSelectedConversationMessagesExport() async throws -> String {
    let transcript = try await fetchSelectedConversationTranscript()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(transcript)
    guard let string = String(data: data, encoding: .utf8) else {
      throw ConversationAssistantError.invalidTranscriptEncoding
    }

    return string
  }

  private func fetchSelectedConversationTranscript(
    maxPages: Int = 20
  ) async throws -> ConversationMachineTranscript {
    guard let conversation = selectedConversation else {
      throw ConversationAssistantError.noConversationSelected
    }

    let items = try await fetchSelectedConversationMessageItems(maxPages: maxPages)
    let messages = items.map { item in
      let sender = DashboardTimelinePresentation.senderDisplay(
        for: transcriptSender(for: item),
        website: website,
        conversation: conversation,
        visitor: selectedVisitor
      )

      return ConversationMachineTranscript.Message(
        id: item.id,
        createdAt: item.createdAt,
        role: sender.kind.rawValue,
        sender: sender.name,
        visibility: item.visibility.rawValue,
        text: item.renderedText ?? "",
        attachments: attachmentLabels(for: item)
      )
    }

    return ConversationMachineTranscript(
      conversationId: conversation.id,
      title: conversation.displayTitle,
      website: website?.name,
      exportedAt: ISO8601DateFormatter.internetDateTime.string(from: .now),
      messages: messages
    )
  }

  private func fetchSelectedConversationMessageItems(
    maxPages: Int
  ) async throws -> [DashboardTimelineItem] {
    guard let conversationID = selectedConversationID else {
      return []
    }

    let client = DashboardAPIClient(configuration: configuration)
    var collectedItems: [DashboardTimelineItem] = []
    var seenIDs = Set<String>()
    var cursor: String?
    var pageCount = 0

    repeat {
      let page = try await client.fetchTimeline(
        conversationID: conversationID,
        limit: 100,
        cursor: cursor
      )

      for item in page.items where item.type == .message && item.deletedAt == nil {
        if seenIDs.insert(item.id).inserted {
          collectedItems.append(item)
        }
      }

      cursor = page.nextCursor
      pageCount += 1
    } while cursor != nil && pageCount < maxPages

    return collectedItems.sorted {
      ($0.createdAtDate ?? .distantPast) < ($1.createdAtDate ?? .distantPast)
    }
  }

  private func transcriptSender(
    for item: DashboardTimelineItem
  ) -> DashboardTimelineSender {
    if let userId = item.userId {
      return DashboardTimelineSender(id: userId, kind: .human)
    }

    if let aiAgentId = item.aiAgentId {
      return DashboardTimelineSender(id: aiAgentId, kind: .ai)
    }

    if let visitorId = item.visitorId {
      return DashboardTimelineSender(id: visitorId, kind: .visitor)
    }

    return DashboardTimelineSender(id: item.id, kind: .system)
  }

  private func attachmentLabels(for item: DashboardTimelineItem) -> [String] {
    var labels: [String] = []
    labels.append(contentsOf: item.imageParts.compactMap {
      $0.filename?.nilIfEmpty ?? $0.url.nilIfEmpty ?? "image"
    })
    labels.append(contentsOf: item.fileParts.compactMap {
      $0.filename?.nilIfEmpty ?? $0.url.nilIfEmpty ?? "file"
    })
    return labels
  }

  private func markdownAttachmentSummary(for item: DashboardTimelineItem) -> String? {
    let imageCount = item.imageParts.count
    let fileCount = item.fileParts.count
    let parts = [
      imageCount > 0 ? "\(imageCount) image attachment\(imageCount == 1 ? "" : "s") added" : nil,
      fileCount > 0 ? "\(fileCount) file attachment\(fileCount == 1 ? "" : "s") added" : nil,
    ].compactMap { $0 }

    guard !parts.isEmpty else { return nil }
    return parts.joined(separator: " • ")
  }

  private static var preferredTranslationLanguageCode: String {
    if let preferred = Locale.preferredLanguages.first {
      let locale = Locale(identifier: preferred)
      if #available(macOS 13.0, *) {
        if let code = locale.language.languageCode?.identifier {
          return code
        }
      }

      if let code = preferred.split(separator: "-").first {
        return String(code)
      }
    }

    return "en"
  }
}

struct DashboardMessageTranslation: Equatable, Sendable {
  let text: String
  let detectedSourceLanguage: String?
}

private struct ConversationMachineTranscript: Encodable, Sendable {
  struct Message: Encodable, Sendable {
    let id: String
    let createdAt: String
    let role: String
    let sender: String
    let visibility: String
    let text: String
    let attachments: [String]
  }

  let conversationId: String
  let title: String
  let website: String?
  let exportedAt: String
  let messages: [Message]
}

private enum ConversationAssistantError: LocalizedError {
  case noConversationSelected
  case noAnalyticsMessages
  case invalidTranscriptEncoding
  case invalidResponse
  case server(message: String)

  var errorDescription: String? {
    switch self {
    case .noConversationSelected:
      "Select a conversation first."
    case .noAnalyticsMessages:
      "No non-empty conversations were found in the selected time range."
    case .invalidTranscriptEncoding:
      "The conversation transcript could not be encoded."
    case .invalidResponse:
      "The assistant response could not be decoded."
    case .server(let message):
      message
    }
  }
}

enum AnalyticsSummaryRangeMode: String, CaseIterable, Identifiable, Sendable {
  case lastHours
  case lastDays
  case custom

  var id: String {
    rawValue
  }

  var label: String {
    switch self {
    case .lastHours:
      "Last Hours"
    case .lastDays:
      "Last Days"
    case .custom:
      "Custom Range"
    }
  }
}

struct AnalyticsSummaryDateRange: Sendable {
  let start: Date
  let end: Date

  var label: String {
    "\(start.formatted(.dateTime.year().month().day().hour().minute())) → \(end.formatted(.dateTime.year().month().day().hour().minute()))"
  }
}

enum AnalyticsSummaryChatRole: String, Sendable {
  case assistant
  case user
}

struct AnalyticsSummaryChatMessage: Identifiable, Hashable, Sendable {
  let id: UUID
  let role: AnalyticsSummaryChatRole
  let text: String
  let createdAt: Date

  init(
    id: UUID = UUID(),
    role: AnalyticsSummaryChatRole,
    text: String,
    createdAt: Date = .now
  ) {
    self.id = id
    self.role = role
    self.text = text
    self.createdAt = createdAt
  }
}

private struct AnalyticsConversationSection: Sendable {
  let markdown: String
  let messageCount: Int
}

private struct AnalyticsConversationCorpus: Sendable {
  let document: String
  let chunks: [String]
  let conversationCount: Int
  let messageCount: Int
}

private struct OpenAIAnalyticsTurn: Sendable {
  let responseID: String
  let text: String
}

private struct GoogleCloudTranslateClient {
  private struct RequestBody: Encodable {
    let q: [String]
    let target: String
    let format: String = "text"
  }

  private struct ResponseBody: Decodable {
    struct ResponseData: Decodable {
      struct Translation: Decodable {
        let translatedText: String
        let detectedSourceLanguage: String?
      }

      let translations: [Translation]
    }

    let data: ResponseData
  }

  let apiKey: String
  let session: URLSession

  init(
    apiKey: String,
    session: URLSession = .shared
  ) {
    self.apiKey = apiKey
    self.session = session
  }

  func translate(
    texts: [String],
    targetLanguageCode: String
  ) async throws -> [DashboardMessageTranslation] {
    guard !texts.isEmpty else { return [] }

    var components = URLComponents(string: "https://translation.googleapis.com/language/translate/v2")
    components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]

    guard let url = components?.url else {
      throw ConversationAssistantError.invalidResponse
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = try JSONEncoder().encode(
      RequestBody(q: texts, target: targetLanguageCode)
    )

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ConversationAssistantError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw ConversationAssistantError.server(
        message: "Google Translate request failed (\(httpResponse.statusCode))."
      )
    }

    let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
    return decoded.data.translations.map {
      DashboardMessageTranslation(
        text: $0.translatedText.decodingHTMLEntities,
        detectedSourceLanguage: $0.detectedSourceLanguage
      )
    }
  }
}

private struct OpenAIReplyDraftClient {
  private struct RequestBody: Encodable {
    struct InputMessage: Encodable {
      struct Content: Encodable {
        let type: String
        let text: String
      }

      let role: String
      let content: [Content]
    }

    let model: String
    let input: [InputMessage]
  }

  private struct ResponseBody: Decodable {
    struct OutputItem: Decodable {
      struct ContentItem: Decodable {
        let type: String
        let text: String?
      }

      let content: [ContentItem]?
    }

    let outputText: String?
    let output: [OutputItem]?

    enum CodingKeys: String, CodingKey {
      case outputText = "output_text"
      case output
    }
  }

  private static let model = "gpt-5-mini"

  let apiKey: String
  let session: URLSession

  init(
    apiKey: String,
    session: URLSession = .shared
  ) {
    self.apiKey = apiKey
    self.session = session
  }

  func generateDraft(
    transcript: String,
    operatorDraft: String,
    conversationTitle: String?,
    websiteName: String?
  ) async throws -> String {
    guard let url = URL(string: "https://api.openai.com/v1/responses") else {
      throw ConversationAssistantError.invalidResponse
    }

    let developerPrompt = """
    You are helping a customer support agent write a reply draft.
    Use the provided conversation transcript as the only source of truth.
    Infer the customer's language from the transcript and rewrite the operator draft into a natural, professional support reply in that same language.
    Preserve the intent of the operator draft, avoid inventing facts, and return only the final reply text with no framing.
    """

    let userPrompt = """
    Workspace: \(websiteName ?? "Cossistant")
    Conversation title: \(conversationTitle ?? "Untitled conversation")

    Conversation transcript (JSON):
    \(transcript)

    Operator draft in their own language:
    \(operatorDraft)
    """

    let body = RequestBody(
      model: Self.model,
      input: [
        .init(
          role: "developer",
          content: [.init(type: "input_text", text: developerPrompt)]
        ),
        .init(
          role: "user",
          content: [.init(type: "input_text", text: userPrompt)]
        ),
      ]
    )

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ConversationAssistantError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw ConversationAssistantError.server(
        message: "OpenAI draft request failed (\(httpResponse.statusCode))."
      )
    }

    let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
    if let outputText = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines),
       !outputText.isEmpty {
      return outputText
    }

    let nestedContentItems = decoded.output?.flatMap { $0.content ?? [] } ?? []
    if let nestedText = nestedContentItems
      .first(where: { $0.type == "output_text" || $0.type == "text" })?
      .text?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !nestedText.isEmpty {
        return nestedText
    }

    throw ConversationAssistantError.invalidResponse
  }
}

private struct OpenAIAnalyticsSummaryClient {
  private struct RequestBody: Encodable {
    struct InputMessage: Encodable {
      struct Content: Encodable {
        let type: String
        let text: String
      }

      let role: String
      let content: [Content]
    }

    let model: String
    let input: [InputMessage]
    let previousResponseID: String?
    let maxOutputTokens: Int?

    enum CodingKeys: String, CodingKey {
      case model
      case input
      case previousResponseID = "previous_response_id"
      case maxOutputTokens = "max_output_tokens"
    }
  }

  private struct ResponseBody: Decodable {
    struct OutputItem: Decodable {
      struct ContentItem: Decodable {
        let type: String
        let text: String?
      }

      let content: [ContentItem]?
    }

    let id: String
    let outputText: String?
    let output: [OutputItem]?

    enum CodingKeys: String, CodingKey {
      case id
      case outputText = "output_text"
      case output
    }
  }

  private static let model = "gpt-5-mini"

  let apiKey: String
  let session: URLSession

  init(
    apiKey: String,
    session: URLSession = .shared
  ) {
    self.apiKey = apiKey
    self.session = session
  }

  func startSummaryConversation(
    sourceDocument: String,
    workspaceName: String?,
    rangeDescription: String,
    conversationCount: Int,
    messageCount: Int
  ) async throws -> OpenAIAnalyticsTurn {
    let developerPrompt = """
    You analyze recent support conversations for an internal support team.
    Respond only in English.
    Use only the supplied conversation digest as evidence.
    Summarize what customers are complaining about, reporting, or struggling with lately.
    Prioritize recurring issues, affected product areas, severity, notable changes in volume, and representative examples.
    If evidence is weak or mixed, say so plainly.
    Return readable markdown with short section headers and bullets.
    Put each heading and each bullet on its own line.
    Leave a blank line between sections.
    Do not return one dense paragraph.
    """

    let userPrompt = """
    Workspace: \(workspaceName ?? "Cossistant")
    Time range: \(rangeDescription)
    Conversations analyzed: \(conversationCount)
    Messages analyzed: \(messageCount)

    Conversation digest:
    \(sourceDocument)
    """

    return try await send(
      developerPrompt: developerPrompt,
      userPrompt: userPrompt,
      previousResponseID: nil,
      maxOutputTokens: 1_600,
      failureLabel: "OpenAI analytics request failed"
    )
  }

  func summarizeChunk(
    sourceDocument: String,
    workspaceName: String?,
    rangeDescription: String,
    partIndex: Int,
    totalParts: Int
  ) async throws -> String {
    let developerPrompt = """
    You are preparing an intermediate summary of support conversations.
    Respond only in English.
    Use only the supplied batch as evidence.
    Extract the main complaints, reported bugs, confusing behavior, and support requests from this batch.
    Highlight repeated themes and a few representative examples.
    Keep the summary compact but information-dense.
    Return readable markdown bullets.
    Put each bullet on its own line.
    """

    let userPrompt = """
    Workspace: \(workspaceName ?? "Cossistant")
    Time range: \(rangeDescription)
    Batch: \(partIndex) of \(totalParts)

    Batch digest:
    \(sourceDocument)
    """

    let turn = try await send(
      developerPrompt: developerPrompt,
      userPrompt: userPrompt,
      previousResponseID: nil,
      maxOutputTokens: 1_000,
      failureLabel: "OpenAI batch summary request failed"
    )
    return turn.text
  }

  func synthesizeSummary(
    chunkSummaries: [String],
    workspaceName: String?,
    rangeDescription: String,
    conversationCount: Int,
    messageCount: Int
  ) async throws -> OpenAIAnalyticsTurn {
    let developerPrompt = """
    You are combining multiple batch summaries of support conversations into one internal report.
    Respond only in English.
    Use only the supplied batch summaries as evidence.
    Focus on the most common reported problems, what customers are trying to do, what seems broken, and what deserves investigation.
    Return readable markdown with section headers and bullets.
    Put each heading and each bullet on its own line.
    Leave a blank line between sections.
    Do not return one dense paragraph.
    """

    let userPrompt = """
    Workspace: \(workspaceName ?? "Cossistant")
    Time range: \(rangeDescription)
    Conversations analyzed: \(conversationCount)
    Messages analyzed: \(messageCount)

    Batch summaries:
    \(chunkSummaries.joined(separator: "\n\n"))
    """

    return try await send(
      developerPrompt: developerPrompt,
      userPrompt: userPrompt,
      previousResponseID: nil,
      maxOutputTokens: 1_600,
      failureLabel: "OpenAI synthesis request failed"
    )
  }

  func continueSummaryConversation(
    previousResponseID: String,
    userQuestion: String,
    workspaceName: String?,
    rangeDescription: String,
    conversationCount: Int,
    messageCount: Int
  ) async throws -> OpenAIAnalyticsTurn {
    let developerPrompt = """
    You are continuing an internal support analytics conversation.
    Respond only in English.
    Base your answer only on the support analysis context already established in this conversation plus the user's follow-up question.
    If the question requires evidence you do not have, say that explicitly.
    Prefer concise readable markdown.
    Put each heading and each bullet on its own line.
    Leave a blank line between sections when useful.
    """

    let userPrompt = """
    Workspace: \(workspaceName ?? "Cossistant")
    Time range: \(rangeDescription)
    Conversations analyzed: \(conversationCount)
    Messages analyzed: \(messageCount)

    Follow-up question:
    \(userQuestion)
    """

    return try await send(
      developerPrompt: developerPrompt,
      userPrompt: userPrompt,
      previousResponseID: previousResponseID,
      maxOutputTokens: 1_200,
      failureLabel: "OpenAI follow-up request failed"
    )
  }

  private func send(
    developerPrompt: String,
    userPrompt: String,
    previousResponseID: String?,
    maxOutputTokens: Int,
    failureLabel: String
  ) async throws -> OpenAIAnalyticsTurn {
    guard let url = URL(string: "https://api.openai.com/v1/responses") else {
      throw ConversationAssistantError.invalidResponse
    }

    let body = RequestBody(
      model: Self.model,
      input: [
        .init(
          role: "developer",
          content: [.init(type: "input_text", text: developerPrompt)]
        ),
        .init(
          role: "user",
          content: [.init(type: "input_text", text: userPrompt)]
        ),
      ],
      previousResponseID: previousResponseID,
      maxOutputTokens: maxOutputTokens
    )

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ConversationAssistantError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw ConversationAssistantError.server(
        message: "\(failureLabel) (\(httpResponse.statusCode))."
      )
    }

    let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
    if let outputText = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines),
       !outputText.isEmpty {
      return OpenAIAnalyticsTurn(
        responseID: decoded.id,
        text: outputText
      )
    }

    let nestedContentItems = decoded.output?.flatMap { $0.content ?? [] } ?? []
    if let nestedText = nestedContentItems
      .first(where: { $0.type == "output_text" || $0.type == "text" })?
      .text?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !nestedText.isEmpty {
      return OpenAIAnalyticsTurn(
        responseID: decoded.id,
        text: nestedText
      )
    }

    throw ConversationAssistantError.invalidResponse
  }
}

private extension String {
  var nilIfEmpty: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  var decodingHTMLEntities: String {
    guard let data = data(using: .utf8) else { return self }

    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
      .documentType: NSAttributedString.DocumentType.html,
      .characterEncoding: String.Encoding.utf8.rawValue,
    ]

    return (try? NSAttributedString(data: data, options: options, documentAttributes: nil).string) ?? self
  }
}
