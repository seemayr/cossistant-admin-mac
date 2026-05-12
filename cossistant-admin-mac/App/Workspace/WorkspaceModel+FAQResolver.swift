import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  var canRunFAQResolverFullResolve: Bool {
    canUseOpenAIReplyDrafts
      && !faqResolverStore.isRunningFullResolve
      && !faqResolverStore.isRunningAutoAssignAll
      && !faqResolverStore.isConfirmingAll
      && faqResolverStore.autoAssignAllTask == nil
      && faqResolverEligibleConversations().contains { conversation in
        (faqResolverStore.ignoresHandledTimestamps || !conversation.hasCurrentFAQResolverHandling)
          && faqResolverStore.state(for: conversation.id).hasPendingResolveWork
      }
  }

  var canRunFAQResolverAutoAssignAll: Bool {
    canUseOpenAIReplyDrafts
      && !faqResolverStore.isRunningAutoAssignAll
      && faqResolverStore.autoAssignAllTask == nil
      && !faqResolverStore.isRunningFullResolve
      && !faqResolverStore.isConfirmingAll
      && !faqResolverStore.faqEntries.isEmpty
      && faqResolverAutoAssignAllCandidateConversations().isEmpty == false
  }

  func ensureFAQResolverAIAgentSelection() {
    if faqResolverStore.selectedAIAgentID == nil {
      faqResolverStore.selectedAIAgentID = website?.availableAIAgents.first?.id
    }
  }

  func reloadFAQResolverFAQs() async {
    await makeFAQResolverCoordinator().loadFAQs()
  }

  func inspectFAQResolverConversation(_ conversationID: DashboardConversation.ID) async {
    faqResolverStore.inspectedConversationID = conversationID
    selectConversation(conversationID)
  }

  func autoAssignFAQResolverFAQs(to conversationID: DashboardConversation.ID) async {
    guard let conversation = inboxStore.conversation(withID: conversationID) else { return }
    await makeFAQResolverCoordinator().autoAssignFAQs(to: conversation)
  }

  func startAutoAssignAllFAQResolverFAQs() {
    makeFAQResolverCoordinator().startAutoAssignAll()
  }

  func cancelAutoAssignAllFAQResolverFAQs() {
    makeFAQResolverCoordinator().cancelAutoAssignAll()
  }

  func resolveFAQResolverConversation(_ conversationID: DashboardConversation.ID) async {
    guard let conversation = inboxStore.conversation(withID: conversationID) else { return }
    await makeFAQResolverCoordinator().resolveConversation(conversation)
  }

  func confirmFAQResolverConversation(_ conversationID: DashboardConversation.ID) async {
    guard let conversation = inboxStore.conversation(withID: conversationID) else { return }
    await makeFAQResolverCoordinator().confirmConversation(conversation)
  }

  func resetFAQResolverResolveResult(_ conversationID: DashboardConversation.ID) {
    faqResolverStore.resetPendingResolveResult(for: conversationID)
  }

  func translateFAQResolverPendingDrafts() async {
    await makeFAQResolverCoordinator().translatePendingDrafts()
  }

  func confirmAllFAQResolverConversations() async {
    await makeFAQResolverCoordinator().confirmAllPendingConversations()
  }

  func startFAQResolverFullResolve() {
    makeFAQResolverCoordinator().startFullResolve()
  }

  func cancelFAQResolverFullResolve() {
    makeFAQResolverCoordinator().cancelFullResolve()
  }

  func faqResolverEligibleConversations() -> [DashboardConversation] {
    faqResolverBaseCandidateConversations()
      .filter(faqResolverMatchesCandidateFilters(_:))
      .sorted {
        if $0.latestActivityDate != $1.latestActivityDate {
          return $0.latestActivityDate > $1.latestActivityDate
        }

        return ($0.createdAtDate ?? .distantPast) > ($1.createdAtDate ?? .distantPast)
      }
  }

  func faqResolverAutoAssignAllCandidateConversations() -> [DashboardConversation] {
    faqResolverEligibleConversations().filter { conversation in
      let state = faqResolverStore.state(for: conversation.id)
      return (faqResolverStore.ignoresHandledTimestamps || !conversation.hasCurrentFAQResolverHandling)
        && state.assignedFAQIDs.isEmpty
        && !state.canResolveWithoutReply
        && !state.noActionNeeded
        && !state.urgentlyNeedsTeam
        && state.assignmentSource == nil
        && state.status == .idle
    }
  }

  func availableFAQResolverChannelFilters() -> [InboxChannelFilterOption] {
    faqResolverBaseCandidateConversations()
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

  func availableFAQResolverMetadataFilters() -> [InboxMetadataFilterSection] {
    let candidates = faqResolverBaseCandidateConversations()
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

  func availableFAQResolverAppVersionFilters() -> [FAQResolverTextFilterOption] {
    faqResolverTextFilterOptions(
      from: faqResolverBaseCandidateConversations().compactMap(\.appVersionIndicatorText)
    )
  }

  func availableFAQResolverGameIDFilters() -> [FAQResolverTextFilterOption] {
    faqResolverTextFilterOptions(
      from: faqResolverBaseCandidateConversations().compactMap(faqResolverGameID(for:))
    )
  }

  private func faqResolverBaseCandidateConversations() -> [DashboardConversation] {
    let scope = faqResolverStore.sourceScope.inboxScope

    return inboxStore.conversations
      .filter {
        inboxStore.conversation($0, isIncludedIn: scope)
          || faqResolverStore.state(for: $0.id).status == .resolved
      }
      .filter { !$0.isArchived }
      .filter {
        $0.status == .open
          || faqResolverStore.state(for: $0.id).status == .resolved
      }
      .filter(\.hasContent)
  }

  private func faqResolverMatchesCandidateFilters(
    _ conversation: DashboardConversation
  ) -> Bool {
    if !faqResolverStore.priorityFilter.includes(conversation.priority) {
      return false
    }
    if !faqResolverStore.dateRange.includes(
      conversation,
      basis: faqResolverStore.dateBasis,
      now: .now
    ) {
      return false
    }
    if !faqResolverStore.summaryFilter.includes(conversation) {
      return false
    }
    if !faqResolverStore.visitorWaitingFilter.includes(conversation) {
      return false
    }
    if !faqResolverStore.teamActionFilter.includes(conversation) {
      return false
    }
    if !faqResolverStore.ignoresHandledTimestamps && conversation.hasCurrentFAQResolverHandling {
      return false
    }
    if let channelFilter = faqResolverStore.channelFilter,
       conversation.channel != channelFilter {
      return false
    }
    if let appVersionFilter = faqResolverStore.appVersionFilter,
       conversation.appVersionIndicatorText != appVersionFilter {
      return false
    }
    if let gameIDFilter = faqResolverStore.gameIDFilter,
       faqResolverGameID(for: conversation) != gameIDFilter {
      return false
    }
    for (key, expectedValue) in faqResolverStore.metadataFilters {
      guard conversation.metadata?[key.rawValue] == expectedValue else {
        return false
      }
    }

    return true
  }

  private func faqResolverTextFilterOptions(
    from values: [String]
  ) -> [FAQResolverTextFilterOption] {
    values
      .compactMap(\.nilIfEmpty)
      .reduce(into: Set<String>()) { result, value in
        result.insert(value)
      }
      .map(FAQResolverTextFilterOption.init(value:))
      .sorted {
        $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
      }
  }

  private func faqResolverGameID(
    for conversation: DashboardConversation
  ) -> String? {
    faqResolverMetadataText(
      for: conversation,
      keys: ["gameId", "gameID", "game_id"]
    )
  }

  private func faqResolverMetadataText(
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
}
