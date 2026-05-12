import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
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
    let coordinator = makeAnalyticsCoordinator()

    analyticsSummaryTask = Task { [weak self] in
      await coordinator.generateSummary()
      if !Task.isCancelled {
        self?.analyticsSummaryTask = nil
      }
    }
  }

  func startAnalyticsFollowUp() {
    guard analyticsFollowUpTask == nil else { return }
    let coordinator = makeAnalyticsCoordinator()

    analyticsFollowUpTask = Task { [weak self] in
      await coordinator.sendFollowUp()
      if !Task.isCancelled {
        self?.analyticsFollowUpTask = nil
      }
    }
  }

  func copyAnalyticsSourceDocument() {
    guard let analyticsSourceDocument else { return }

    StringClipboardWriter.copy(analyticsSourceDocument)
  }

  func availableAnalyticsChannelFilters() -> [InboxChannelFilterOption] {
    analyticsFilterSourceConversations()
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

  func availableAnalyticsMetadataFilters() -> [InboxMetadataFilterSection] {
    let conversations = analyticsFilterSourceConversations()
    return InboxMetadataFilterKey.allCases.compactMap { key in
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

  func availableAnalyticsAppVersionFilters() -> [AutoResolveTextFilterOption] {
    analyticsTextFilterOptions(
      from: analyticsFilterSourceConversations().compactMap(\.appVersionIndicatorText)
    )
  }

  func availableAnalyticsGameIDFilters() -> [AutoResolveTextFilterOption] {
    analyticsTextFilterOptions(
      from: analyticsFilterSourceConversations().compactMap(analyticsGameID(for:))
    )
  }

  func generateAnalyticsSummary() async {
    await makeAnalyticsCoordinator().generateSummary()
  }

  func sendAnalyticsFollowUp() async {
    await makeAnalyticsCoordinator().sendFollowUp()
  }

  private func analyticsFilterSourceConversations() -> [DashboardConversation] {
    guard let dateRange = analyticsStore.selectedDateRange else { return inboxStore.conversations }

    return inboxStore.conversations.filter {
      $0.latestActivityDate >= dateRange.start && $0.latestActivityDate <= dateRange.end
    }
  }

  private func analyticsTextFilterOptions(
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

  private func analyticsGameID(
    for conversation: DashboardConversation
  ) -> String? {
    analyticsMetadataText(
      for: conversation,
      keys: ["gameId", "gameID", "game_id"]
    )
  }

  private func analyticsMetadataText(
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
