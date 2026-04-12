import Foundation

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

  func generateAnalyticsSummary() async {
    await makeAnalyticsCoordinator().generateSummary()
  }

  func sendAnalyticsFollowUp() async {
    await makeAnalyticsCoordinator().sendFollowUp()
  }
}
