import Foundation
import CossistantAdmin

@MainActor
final class FAQResolverCoordinator {
  private enum BatchItemOutcome {
    case completed
    case skipped
    case failed
  }

  private struct BatchRunSummary {
    var completedCount = 0
    var skippedCount = 0
    var failedCount = 0

    var processedCount: Int {
      completedCount + skippedCount + failedCount
    }

    mutating func record(_ outcome: BatchItemOutcome) {
      switch outcome {
      case .completed:
        completedCount += 1
      case .skipped:
        skippedCount += 1
      case .failed:
        failedCount += 1
      }
    }
  }

  private enum ConversationResolveOutcome {
    case sent
    case sentAndResolved
    case resolvedWithoutReply
    case markedSeen
    case markedUnread
    case sentAndMarkedUnread
    case skipped
  }

  private let batchConcurrencyLimit = 3
  private let store: FAQResolverStore
  private let backendClient: CossistantAdminClient
  private let canUseOpenAI: Bool
  private let canPreviewDraftTranslations: Bool
  private let openAIAPIKey: String
  private let workspaceName: String?
  private let humanSenderUserID: () -> String?
  private let eligibleConversations: () -> [DashboardConversation]
  private let fetchAIMessageItems: (
    _ conversationID: String,
    _ client: CossistantAdminClient,
    _ maxPages: Int
  ) async throws -> [DashboardTimelineItem]
  private let translateDraftPreview: (_ text: String) async throws -> DashboardMessageTranslation
  private let applyMutatedConversation: (
    _ mutation: DashboardConversationMutation,
    _ preserveExistingLastMessageAt: Bool,
    _ preserveExistingLastSeenAt: Bool
  ) -> Void
  private let setConversationLastSeenAt: (
    _ conversationID: DashboardConversation.ID,
    _ lastSeenAt: String?
  ) -> Void
  private let refreshSelectedConversationIfNeeded: (DashboardConversation.ID) async -> Void
  private let setGlobalErrorMessage: (any Error) -> Void
  private let isIgnorableCancellation: (any Error) -> Bool

  init(
    store: FAQResolverStore,
    backendClient: CossistantAdminClient,
    canUseOpenAI: Bool,
    canPreviewDraftTranslations: Bool,
    openAIAPIKey: String,
    workspaceName: String?,
    humanSenderUserID: @escaping () -> String?,
    eligibleConversations: @escaping () -> [DashboardConversation],
    fetchAIMessageItems: @escaping (
      _ conversationID: String,
      _ client: CossistantAdminClient,
      _ maxPages: Int
    ) async throws -> [DashboardTimelineItem],
    translateDraftPreview: @escaping (_ text: String) async throws -> DashboardMessageTranslation,
    applyMutatedConversation: @escaping (
      _ mutation: DashboardConversationMutation,
      _ preserveExistingLastMessageAt: Bool,
      _ preserveExistingLastSeenAt: Bool
    ) -> Void,
    setConversationLastSeenAt: @escaping (
      _ conversationID: DashboardConversation.ID,
      _ lastSeenAt: String?
    ) -> Void,
    refreshSelectedConversationIfNeeded: @escaping (DashboardConversation.ID) async -> Void,
    setGlobalErrorMessage: @escaping (any Error) -> Void,
    isIgnorableCancellation: @escaping (any Error) -> Bool
  ) {
    self.store = store
    self.backendClient = backendClient
    self.canUseOpenAI = canUseOpenAI
    self.canPreviewDraftTranslations = canPreviewDraftTranslations
    self.openAIAPIKey = openAIAPIKey
    self.workspaceName = workspaceName
    self.humanSenderUserID = humanSenderUserID
    self.eligibleConversations = eligibleConversations
    self.fetchAIMessageItems = fetchAIMessageItems
    self.translateDraftPreview = translateDraftPreview
    self.applyMutatedConversation = applyMutatedConversation
    self.setConversationLastSeenAt = setConversationLastSeenAt
    self.refreshSelectedConversationIfNeeded = refreshSelectedConversationIfNeeded
    self.setGlobalErrorMessage = setGlobalErrorMessage
    self.isIgnorableCancellation = isIgnorableCancellation
  }

  func loadFAQs() async {
    guard let aiAgentID = store.selectedAIAgentID?.trimmingCharacters(in: .whitespacesAndNewlines),
          !aiAgentID.isEmpty else {
      store.faqEntries = []
      store.faqErrorMessage = "Select an AI agent before loading FAQs."
      return
    }

    store.isLoadingFAQs = true
    store.faqErrorMessage = nil
    store.statusMessage = "Loading FAQs..."
    defer { store.isLoadingFAQs = false }

    do {
      var page = 1
      var hasMore = true
      var entries: [DashboardKnowledge] = []
      var seenIDs = Set<String>()

      while hasMore {
        try Task.checkCancellation()
        let response = try await backendClient.knowledge.listKnowledge(
          page: page,
          limit: 100,
          type: .faq,
          aiAgentFilter: .specific(aiAgentID),
          isIncluded: .included,
          linkSourceID: nil
        )

        for item in response.items where seenIDs.insert(item.id).inserted {
          guard item.faqPayload != nil else { continue }
          entries.append(item)
        }

        hasMore = response.pagination.hasMore
        page += 1
      }

      store.faqEntries = entries.sorted {
        $0.titleText.localizedCaseInsensitiveCompare($1.titleText) == .orderedAscending
      }
      store.statusMessage = "Loaded \(store.faqEntries.count.formatted(.number)) FAQ entries."
    } catch {
      guard !isIgnorableCancellation(error) else { return }
      store.faqErrorMessage = error.localizedDescription
      store.statusMessage = nil
    }
  }

  func autoAssignFAQs(to conversation: DashboardConversation) async {
    guard canUseOpenAI else {
      store.setStatus(.failed("Add an OpenAI API key in Settings."), for: conversation.id)
      return
    }

    guard !store.faqEntries.isEmpty else {
      store.setStatus(.failed("Load FAQ entries first."), for: conversation.id)
      return
    }

    store.setStatus(.assigning, for: conversation.id)

    do {
      let items = try await fetchAIMessageItems(conversation.id, backendClient, 20)
      guard let transcript = buildConversationDocument(for: conversation, items: items) else {
        store.setAssignedFAQIDs([], for: conversation.id, source: .autoAssigned)
        store.setStatus(.skipped("No visible message content"), for: conversation.id)
        return
      }

      let client = OpenAIFAQAssignmentClient(apiKey: openAIAPIKey)
      let match = try await client.assignFAQs(
        transcript: transcript,
        faqIndex: buildFAQAssignmentIndex(store.faqEntries),
        websiteName: workspaceName,
        conversationID: conversation.id
      )
      store.setAssignedFAQIDs(match.faqIds, for: conversation.id, source: .autoAssigned)
      let hasAssignedFAQs = !store.assignedFAQIDs(for: conversation.id).isEmpty
      let canResolveWithoutReply = match.canResolveWithoutReply && !match.urgentlyNeedsTeam
      let noActionNeeded = match.noActionNeeded && !canResolveWithoutReply && !match.urgentlyNeedsTeam
      let urgentlyNeedsTeam = !hasAssignedFAQs && match.urgentlyNeedsTeam && !canResolveWithoutReply

      store.setCanResolveWithoutReply(canResolveWithoutReply, for: conversation.id)
      store.setNoActionNeeded(noActionNeeded, for: conversation.id)
      store.setUrgentlyNeedsTeam(
        urgentlyNeedsTeam,
        for: conversation.id,
        teamActionNeeded: match.teamActionNeeded
      )

      if !hasAssignedFAQs && !canResolveWithoutReply && !noActionNeeded && !urgentlyNeedsTeam {
        store.setStatus(.skipped("No matching FAQ"), for: conversation.id)
      }
    } catch {
      guard !isIgnorableCancellation(error) else { return }
      store.setStatus(.failed(displayMessage(for: error)), for: conversation.id)
    }
  }

  func startAutoAssignAll() {
    guard store.autoAssignAllTask == nil else { return }
    guard !store.isRunningFullResolve else {
      store.statusMessage = "Stop Full Resolve before running Auto Assign All."
      return
    }
    guard canUseOpenAI else {
      store.statusMessage = "Add an OpenAI API key in Settings to auto assign FAQs."
      return
    }

    guard !store.faqEntries.isEmpty else {
      store.statusMessage = "Load FAQ entries before running Auto Assign All."
      return
    }

    let candidates = autoAssignAllCandidates()
    guard !candidates.isEmpty else {
      store.statusMessage = "No untouched eligible conversations to auto assign."
      return
    }

    store.autoAssignAllTask = Task {
      await self.runAutoAssignAll(candidates)
      if !Task.isCancelled {
        self.store.autoAssignAllTask = nil
      }
    }
  }

  func cancelAutoAssignAll() {
    store.autoAssignAllTask?.cancel()
    store.isRunningAutoAssignAll = false
    store.statusMessage = "Auto Assign All cancelled."
  }

  private func runAutoAssignAll(_ candidates: [DashboardConversation]) async {
    store.isRunningAutoAssignAll = true
    store.statusMessage = "Auto assigning FAQs for \(candidates.count.formatted(.number)) conversations..."
    defer { store.isRunningAutoAssignAll = false }

    do {
      let summary = try await runBoundedBatch(
        candidates,
        progressMessage: { summary in
          "Auto assigned \(summary.processedCount.formatted(.number)) of \(candidates.count.formatted(.number))..."
        },
        operation: { conversation in
          try Task.checkCancellation()
          await self.autoAssignFAQs(to: conversation)
          try Task.checkCancellation()
          return self.batchOutcome(for: conversation.id)
        }
      )

      store.statusMessage = "Auto Assign All finished: assigned \(summary.completedCount.formatted(.number)), skipped \(summary.skippedCount.formatted(.number)), failed \(summary.failedCount.formatted(.number))."
      store.autoAssignAllTask = nil
    } catch {
      if isIgnorableCancellation(error) {
        store.statusMessage = "Auto Assign All cancelled."
      } else {
        store.statusMessage = "Auto Assign All stopped after an error."
        setGlobalErrorMessage(error)
      }
      store.autoAssignAllTask = nil
    }
  }

  func resolveConversation(_ conversation: DashboardConversation) async {
    guard canUseOpenAI else {
      store.setStatus(.failed("Add an OpenAI API key in Settings."), for: conversation.id)
      return
    }

    let client = OpenAIFAQResolveClient(apiKey: openAIAPIKey)

    do {
      try await prepareConfirmation(
        conversation,
        client: client
      )
      store.statusMessage = "Prepared confirmation for \(conversation.visitorDisplayName)."
    } catch {
      guard !isIgnorableCancellation(error) else { return }
      store.setStatus(.failed(displayMessage(for: error)), for: conversation.id)
    }
  }

  func confirmConversation(_ conversation: DashboardConversation) async {
    do {
      _ = try await executePendingConfirmation(for: conversation)
    } catch {
      guard !isIgnorableCancellation(error) else { return }
      store.setStatus(.failed(displayMessage(for: error)), for: conversation.id)
    }
  }

  func confirmAllPendingConversations() async {
    guard !store.isConfirmingAll else { return }
    let candidates = eligibleConversations().filter { conversation in
      store.pendingConfirmation(for: conversation.id) != nil
    }
    guard !candidates.isEmpty else {
      store.statusMessage = "No pending confirmations."
      return
    }

    store.isConfirmingAll = true
    defer { store.isConfirmingAll = false }

    var confirmedCount = 0
    var failedCount = 0
    for (index, conversation) in candidates.enumerated() {
      store.statusMessage = "Confirming \(index + 1) of \(candidates.count)..."
      do {
        try Task.checkCancellation()
        _ = try await executePendingConfirmation(for: conversation)
        confirmedCount += 1
      } catch {
        if isIgnorableCancellation(error) {
          store.statusMessage = "Confirm All cancelled."
          return
        }
        failedCount += 1
        store.setStatus(.failed(displayMessage(for: error)), for: conversation.id)
      }
    }

    store.statusMessage = "Confirmed \(confirmedCount), failed \(failedCount)."
  }

  func translatePendingDrafts() async {
    guard store.previewsDraftTranslations, canPreviewDraftTranslations else { return }

    let pendingDrafts = eligibleConversations().compactMap { conversation -> (DashboardConversation.ID, String)? in
      guard let pending = store.pendingConfirmation(for: conversation.id),
            pending.translatedMessage == nil,
            pending.translationErrorMessage == nil,
            let message = normalizedMessage(pending.message)
      else {
        return nil
      }

      return (conversation.id, message)
    }

    guard !pendingDrafts.isEmpty else { return }

    store.statusMessage = "Translating \(pendingDrafts.count.formatted(.number)) draft previews..."
    var translatedCount = 0
    var failedCount = 0

    for (conversationID, message) in pendingDrafts {
      guard store.previewsDraftTranslations else { return }
      do {
        let translatedMessage = try await translateDraftPreview(message)
        store.setPendingDraftTranslation(
          translatedMessage,
          errorMessage: nil,
          for: conversationID
        )
        translatedCount += 1
      } catch {
        store.setPendingDraftTranslation(
          nil,
          errorMessage: displayMessage(for: error),
          for: conversationID
        )
        failedCount += 1
      }
    }

    store.statusMessage = "Translated \(translatedCount.formatted(.number)) draft previews" + (failedCount > 0 ? ", failed \(failedCount.formatted(.number))." : ".")
  }

  func startFullResolve() {
    guard store.task == nil else { return }
    guard !store.isRunningAutoAssignAll else {
      store.statusMessage = "Stop Auto Assign All before running Full Resolve."
      return
    }
    guard canUseOpenAI else {
      store.statusMessage = "Add an OpenAI API key in Settings to run Full Resolve."
      return
    }

    let candidates = fullResolveCandidates()
    guard !candidates.isEmpty else {
      store.statusMessage = "No eligible conversations have assigned FAQs."
      return
    }

    store.task = Task {
      await self.runFullResolve(candidates)
      if !Task.isCancelled {
        self.store.task = nil
      }
    }
  }

  func cancelFullResolve() {
    store.task?.cancel()
    store.task = nil
    store.isRunningFullResolve = false
    store.statusMessage = "FAQ Full Resolve cancelled."
  }

  private func runFullResolve(_ candidates: [DashboardConversation]) async {
    store.isRunningFullResolve = true
    store.statusMessage = "Preparing confirmations for \(candidates.count.formatted(.number)) conversations..."
    defer { store.isRunningFullResolve = false }

    let client = OpenAIFAQResolveClient(apiKey: openAIAPIKey)

    do {
      let summary = try await runBoundedBatch(
        candidates,
        progressMessage: { summary in
          "Prepared \(summary.processedCount.formatted(.number)) of \(candidates.count.formatted(.number))..."
        },
        operation: { conversation in
          do {
            try Task.checkCancellation()
            try await self.prepareConfirmation(
              conversation,
              client: client
            )
            try Task.checkCancellation()
            return self.store.pendingConfirmation(for: conversation.id) == nil ? .skipped : .completed
          } catch {
            if self.isIgnorableCancellation(error) {
              throw error
            }
            self.store.setStatus(.failed(self.displayMessage(for: error)), for: conversation.id)
            return .failed
          }
        }
      )

      store.statusMessage = "FAQ Full Resolve prepared \(summary.completedCount.formatted(.number)) confirmations, skipped \(summary.skippedCount.formatted(.number)), failed \(summary.failedCount.formatted(.number))."
      store.task = nil
    } catch {
      if isIgnorableCancellation(error) {
        store.statusMessage = "FAQ Full Resolve cancelled."
      } else {
        store.statusMessage = "FAQ Full Resolve stopped after an error."
        setGlobalErrorMessage(error)
      }
      store.task = nil
    }
  }

  private func runBoundedBatch(
    _ candidates: [DashboardConversation],
    progressMessage: @escaping (BatchRunSummary) -> String,
    operation: @escaping (DashboardConversation) async throws -> BatchItemOutcome
  ) async throws -> BatchRunSummary {
    var summary = BatchRunSummary()
    var nextIndex = candidates.startIndex

    while nextIndex < candidates.endIndex {
      try Task.checkCancellation()

      let upperBound = min(nextIndex + batchConcurrencyLimit, candidates.endIndex)
      let batch = Array(candidates[nextIndex..<upperBound])

      try await withThrowingTaskGroup(of: BatchItemOutcome.self) { group in
        for conversation in batch {
          group.addTask {
            try await operation(conversation)
          }
        }

        while let outcome = try await group.next() {
          summary.record(outcome)
          store.statusMessage = progressMessage(summary)
        }
      }

      nextIndex = upperBound
    }

    return summary
  }

  private func batchOutcome(for conversationID: DashboardConversation.ID) -> BatchItemOutcome {
    switch store.state(for: conversationID).status {
    case .failed:
      .failed
    case .skipped:
      .skipped
    default:
      .completed
    }
  }

  private func fullResolveCandidates() -> [DashboardConversation] {
    eligibleConversations().filter { conversation in
      conversation.status == .open
        && !conversation.isArchived
        && store.state(for: conversation.id).hasPendingResolveWork
    }
  }

  private func autoAssignAllCandidates() -> [DashboardConversation] {
    eligibleConversations().filter { conversation in
      let state = store.state(for: conversation.id)
      return conversation.status == .open
        && !conversation.isArchived
        && state.assignedFAQIDs.isEmpty
        && !state.canResolveWithoutReply
        && !state.noActionNeeded
        && !state.urgentlyNeedsTeam
        && state.assignmentSource == nil
        && state.status == .idle
    }
  }

  private func prepareConfirmation(
    _ conversation: DashboardConversation,
    client: OpenAIFAQResolveClient
  ) async throws {
    store.setStatus(.resolving, for: conversation.id)

    guard conversation.status == .open, !conversation.isArchived else {
      store.setStatus(.skipped("Conversation is already closed"), for: conversation.id)
      return
    }

    let assignedFAQs = store.assignedFAQs(for: conversation.id)
    if !assignedFAQs.isEmpty {
      let items = try await fetchAIMessageItems(conversation.id, backendClient, 20)
      guard let transcript = buildConversationDocument(for: conversation, items: items) else {
        store.setStatus(.skipped("No visible message content"), for: conversation.id)
        return
      }

      let response = try await client.resolveConversation(
        transcript: transcript,
        faqDocument: buildFAQResolveDocument(assignedFAQs),
        websiteName: workspaceName,
        conversationID: conversation.id
      )
      let message = normalizedMessage(response.message)
      let hasMessage = message != nil
      let urgentlyNeedsTeam = response.urgentlyNeedsTeam && !hasMessage
      let canAutoResolve = response.autoResolve && !response.urgentlyNeedsTeam

      if response.noActionNeeded && message == nil && !canAutoResolve && !urgentlyNeedsTeam {
        await setPendingConfirmation(
          message: nil,
          actions: [.markRead],
          teamActionNeeded: nil,
          for: conversation
        )
        return
      }

      if urgentlyNeedsTeam && message == nil {
        let teamActionNeeded = normalizedTeamActionNeeded(response.teamActionNeeded)
        store.setUrgentlyNeedsTeam(
          true,
          for: conversation.id,
          teamActionNeeded: teamActionNeeded
        )
        await setPendingConfirmation(
          message: nil,
          actions: [.markUnread],
          teamActionNeeded: teamActionNeeded,
          for: conversation
        )
        return
      }

      guard let message else {
        await setPendingConfirmation(
          message: nil,
          actions: [.doNothing],
          teamActionNeeded: nil,
          for: conversation
        )
        return
      }

      await setPendingConfirmation(
        message: message,
        actions: canAutoResolve ? [.pauseAI, .sendAnswer, .resolveAfterAnswer] : [.pauseAI, .sendAnswer],
        teamActionNeeded: nil,
        for: conversation
      )
      return
    }

    let state = store.state(for: conversation.id)
    if state.canResolveWithoutReply {
      await setPendingConfirmation(
        message: nil,
        actions: [.resolveNow],
        teamActionNeeded: nil,
        for: conversation
      )
      return
    }

    if state.urgentlyNeedsTeam {
      await setPendingConfirmation(
        message: nil,
        actions: [.markUnread],
        teamActionNeeded: state.teamActionNeeded,
        for: conversation
      )
      return
    }

    if state.noActionNeeded {
      await setPendingConfirmation(
        message: nil,
        actions: [.markRead],
        teamActionNeeded: nil,
        for: conversation
      )
      return
    }

    store.setStatus(.skipped("No assigned FAQ"), for: conversation.id)
  }

  private func setPendingConfirmation(
    message: String?,
    actions: [FAQResolverPendingAction],
    teamActionNeeded: String?,
    for conversation: DashboardConversation
  ) async {
    var translatedMessage: DashboardMessageTranslation?
    var translationErrorMessage: String?

    if let message,
       store.previewsDraftTranslations,
       canPreviewDraftTranslations {
      do {
        translatedMessage = try await translateDraftPreview(message)
      } catch {
        translationErrorMessage = displayMessage(for: error)
      }
    }

    store.setPendingConfirmation(
      FAQResolverPendingConfirmation(
        message: message,
        translatedMessage: translatedMessage,
        translationErrorMessage: translationErrorMessage,
        actions: actions,
        teamActionNeeded: normalizedTeamActionNeeded(teamActionNeeded)
      ),
      for: conversation.id
    )
  }

  private func executePendingConfirmation(
    for conversation: DashboardConversation
  ) async throws -> ConversationResolveOutcome {
    guard let pending = store.pendingConfirmation(for: conversation.id) else {
      store.setStatus(.skipped("No pending confirmation"), for: conversation.id)
      return .skipped
    }

    store.setStatus(.confirming, for: conversation.id)

    if pending.actions.contains(.pauseAI),
       pending.message != nil {
      let updatedConversation = try await backendClient.conversations.pauseConversationAI(
        conversationID: conversation.id,
        durationMinutes: 60
      )
      applyMutatedConversation(updatedConversation, false, false)
      await refreshSelectedConversationIfNeeded(conversation.id)
    }

    var didSendMessage = false
    if pending.actions.contains(.sendAnswer),
       let message = pending.message {
      _ = try await backendClient.conversations.sendTimelineItem(
        DashboardSendTimelineItemRequest(
          conversationId: conversation.id,
          item: .message(
            message,
            visibility: DashboardTimelineItemVisibility.public.rawValue,
            userID: humanSenderUserID()
          )
        )
      )
      didSendMessage = true
      await refreshSelectedConversationIfNeeded(conversation.id)
    }

    if pending.actions.contains(.markUnread) && !didSendMessage {
      let updatedConversation = try await backendClient.conversations.markConversationUnread(
        conversationID: conversation.id
      )
      applyMutatedConversation(updatedConversation, false, false)
      await refreshSelectedConversationIfNeeded(conversation.id)
      _ = await persistFAQResolverMetadata(
        teamActionNeeded: pending.teamActionNeeded,
        markHandled: true,
        for: updatedConversation
      )
      store.completeConfirmation(for: conversation.id, status: .needsTeam, keepsTeamNeed: true)
      return didSendMessage ? .sentAndMarkedUnread : .markedUnread
    }

    if pending.actions.contains(.markRead) {
      let seenConversation = try await markConversationSeen(conversation.id)
      _ = await persistFAQResolverMetadata(
        teamActionNeeded: nil,
        markHandled: true,
        for: seenConversation
      )
      store.completeConfirmation(for: conversation.id, status: .markedSeen)
      return .markedSeen
    }

    if pending.actions.contains(.resolveAfterAnswer) || pending.actions.contains(.resolveNow) {
      let updatedConversation = try await backendClient.conversations.resolveConversation(
        conversationID: conversation.id
      )
      applyMutatedConversation(updatedConversation, false, false)
      await refreshSelectedConversationIfNeeded(conversation.id)
      let seenConversation = try await markConversationSeen(conversation.id)
      _ = await persistFAQResolverMetadata(
        teamActionNeeded: nil,
        markHandled: true,
        for: seenConversation
      )
      store.completeConfirmation(for: conversation.id, status: .resolved)
      return didSendMessage ? .sentAndResolved : .resolvedWithoutReply
    }

    if didSendMessage {
      let seenConversation = try await markConversationSeen(conversation.id)
      _ = await persistFAQResolverMetadata(
        teamActionNeeded: nil,
        markHandled: true,
        for: seenConversation
      )
      store.completeConfirmation(for: conversation.id, status: .sent)
      return .sent
    }

    let seenConversation = try await markConversationSeen(conversation.id)
    _ = await persistFAQResolverMetadata(
      teamActionNeeded: nil,
      markHandled: true,
      for: seenConversation
    )
    store.completeConfirmation(for: conversation.id, status: .skipped("Confirmed no action"))
    return .skipped
  }

  private func markConversationSeen(
    _ conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let optimisticSeenAt = ISO8601DateFormatter.internetDateTime.string(from: .now)
    setConversationLastSeenAt(conversationID, optimisticSeenAt)

    let updatedConversation = try await backendClient.conversations.markConversationRead(
      conversationID: conversationID
    )
    applyMutatedConversation(updatedConversation, true, true)
    await refreshSelectedConversationIfNeeded(conversationID)
    return updatedConversation
  }

  private func buildConversationDocument(
    for conversation: DashboardConversation,
    items: [DashboardTimelineItem]
  ) -> String? {
    var lines = [
      "# Conversation",
      "",
      "- Status: \(conversation.status.label)",
      "- Priority: \(conversation.priority.label)",
      "- Visitor language: \(conversation.visitorLanguage ?? "unknown")",
      "- Needs human intervention: \(conversation.needsHumanIntervention ? "Yes" : "No")",
      "",
      "## Messages",
    ]
    let teamActionNeeded = store.state(for: conversation.id).teamActionNeeded
      ?? conversation.teamActionNeededPreviewText
    if let teamActionNeeded {
      lines.insert("- Team action needed: \(teamActionNeeded)", at: 6)
    }
    var messageCount = 0

    for item in items {
      let text = item.renderedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let attachmentSummary = AIWorkflowFormatting.markdownAttachmentSummary(for: item)
      guard !text.isEmpty || attachmentSummary != nil else {
        continue
      }

      let visibilitySuffix = item.visibility == .private ? " [private]" : ""
      lines.append("- \(AIWorkflowFormatting.senderLabel(for: item))\(visibilitySuffix):")

      if !text.isEmpty {
        lines.append(AIWorkflowFormatting.indentedMarkdownText(text, indentation: "  "))
      }

      if let attachmentSummary {
        lines.append("  _\(attachmentSummary)_")
      }

      messageCount += 1
    }

    guard messageCount > 0 else { return nil }
    return lines.joined(separator: "\n")
  }

  private func buildFAQAssignmentIndex(_ entries: [DashboardKnowledge]) -> String {
    entries.compactMap { entry in
      guard let payload = entry.faqPayload else { return nil }
      var lines = [
        "- ID: \(entry.id)",
        "  Title: \(entry.titleText)",
        "  Question: \(payload.question)",
      ]

      if !payload.relatedQuestions.isEmpty {
        lines.append("  Alternative questions: \(payload.relatedQuestions.joined(separator: " | "))")
      }

      return lines.joined(separator: "\n")
    }
    .joined(separator: "\n\n")
  }

  private func buildFAQResolveDocument(_ entries: [DashboardKnowledge]) -> String {
    entries.compactMap { entry in
      guard let payload = entry.faqPayload else { return nil }
      return """
      ## \(entry.titleText)
      ID: \(entry.id)
      Question: \(payload.question)
      Answer:
      \(payload.answer)
      """
    }
    .joined(separator: "\n\n")
  }

  private func displayMessage(for error: any Error) -> String {
    let message = (error as NSError).localizedDescription
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return message.isEmpty ? "An unknown error occurred." : message
  }

  private func persistTeamActionNeededMetadata(
    _ teamActionNeeded: String?,
    for conversation: DashboardConversation
  ) async -> Bool {
    await persistFAQResolverMetadata(
      teamActionNeeded: teamActionNeeded,
      markHandled: false,
      for: conversation
    )
  }

  private func persistFAQResolverMetadata(
    teamActionNeeded: String?,
    markHandled: Bool,
    for conversation: DashboardConversationMutation
  ) async -> Bool {
    await persistFAQResolverMetadata(
      teamActionNeeded: teamActionNeeded,
      markHandled: markHandled,
      conversationID: conversation.id,
      metadata: conversation.metadata
    )
  }

  private func persistFAQResolverMetadata(
    teamActionNeeded: String?,
    markHandled: Bool,
    for conversation: DashboardConversation
  ) async -> Bool {
    await persistFAQResolverMetadata(
      teamActionNeeded: teamActionNeeded,
      markHandled: markHandled,
      conversationID: conversation.id,
      metadata: conversation.metadata
    )
  }

  private func persistFAQResolverMetadata(
    teamActionNeeded: String?,
    markHandled: Bool,
    conversationID: DashboardConversation.ID,
    metadata currentMetadata: DashboardMetadata?
  ) async -> Bool {
    let normalized = normalizedTeamActionNeeded(teamActionNeeded)
    var metadata = currentMetadata ?? [:]

    if let normalized {
      metadata[FAQResolverMetadataKey.teamActionNeeded] = .string(normalized)
    } else {
      metadata.removeValue(forKey: FAQResolverMetadataKey.teamActionNeeded)
    }

    if markHandled {
      metadata[FAQResolverMetadataKey.handledAt] = .string(ISO8601DateFormatter.internetDateTime.string(from: .now))
    }

    do {
      let updatedConversation = try await backendClient.conversations.updateConversationMetadata(
        conversationID: conversationID,
        metadata: metadata
      )
      applyMutatedConversation(updatedConversation, true, true)
      await refreshSelectedConversationIfNeeded(conversationID)
      return true
    } catch {
      print("[FAQResolver] Failed to persist metadata for conversation \(conversationID): \(displayMessage(for: error))")
      return false
    }
  }

  private func normalizedTeamActionNeeded(_ value: String?) -> String? {
    value?
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
      .nilIfEmpty
  }

  private func normalizedMessage(_ value: String?) -> String? {
    value?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .nilIfEmpty
  }
}
