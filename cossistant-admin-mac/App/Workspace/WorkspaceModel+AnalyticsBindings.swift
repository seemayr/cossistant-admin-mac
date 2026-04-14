import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  var analyticsSummaryTask: Task<Void, Never>? {
    get { analyticsStore.summaryTask }
    set { analyticsStore.summaryTask = newValue }
  }

  var analyticsFollowUpTask: Task<Void, Never>? {
    get { analyticsStore.followUpTask }
    set { analyticsStore.followUpTask = newValue }
  }

  var analyticsRangeMode: AnalyticsSummaryRangeMode {
    get { analyticsStore.rangeMode }
    set { analyticsStore.rangeMode = newValue }
  }

  var analyticsLastHours: Int {
    get { analyticsStore.lastHours }
    set { analyticsStore.lastHours = newValue }
  }

  var analyticsLastDays: Int {
    get { analyticsStore.lastDays }
    set { analyticsStore.lastDays = newValue }
  }

  var analyticsCustomStartDate: Date {
    get { analyticsStore.customStartDate }
    set { analyticsStore.customStartDate = newValue }
  }

  var analyticsCustomEndDate: Date {
    get { analyticsStore.customEndDate }
    set { analyticsStore.customEndDate = newValue }
  }

  var analyticsSummaryMessages: [AnalyticsSummaryChatMessage] {
    get { analyticsStore.summaryMessages }
    set { analyticsStore.summaryMessages = newValue }
  }

  var analyticsFollowUpDraft: String {
    get { analyticsStore.followUpDraft }
    set { analyticsStore.followUpDraft = newValue }
  }

  var analyticsSummaryStatusMessage: String? {
    get { analyticsStore.summaryStatusMessage }
    set { analyticsStore.summaryStatusMessage = newValue }
  }

  var analyticsSummaryErrorMessage: String? {
    get { analyticsStore.summaryErrorMessage }
    set { analyticsStore.summaryErrorMessage = newValue }
  }

  var analyticsIsGeneratingSummary: Bool {
    get { analyticsStore.isGeneratingSummary }
    set { analyticsStore.isGeneratingSummary = newValue }
  }

  var analyticsIsSendingFollowUp: Bool {
    get { analyticsStore.isSendingFollowUp }
    set { analyticsStore.isSendingFollowUp = newValue }
  }

  var analyticsConversationCount: Int {
    get { analyticsStore.conversationCount }
    set { analyticsStore.conversationCount = newValue }
  }

  var analyticsSourceMessageCount: Int {
    get { analyticsStore.sourceMessageCount }
    set { analyticsStore.sourceMessageCount = newValue }
  }

  var analyticsSourceDocument: String? {
    get { analyticsStore.sourceDocument }
    set { analyticsStore.sourceDocument = newValue }
  }

  var analyticsSummaryResponseID: String? {
    get { analyticsStore.summaryResponseID }
    set { analyticsStore.summaryResponseID = newValue }
  }

  var analyticsSummaryGeneratedAt: Date? {
    get { analyticsStore.summaryGeneratedAt }
    set { analyticsStore.summaryGeneratedAt = newValue }
  }

  var analyticsSummaryRangeLabel: String? {
    get { analyticsStore.summaryRangeLabel }
    set { analyticsStore.summaryRangeLabel = newValue }
  }

  var analyticsSummaryUsedChunking: Bool {
    get { analyticsStore.summaryUsedChunking }
    set { analyticsStore.summaryUsedChunking = newValue }
  }

  var analyticsSelectedDateRange: AnalyticsSummaryDateRange? {
    analyticsStore.selectedDateRange
  }

  var analyticsCanGenerateSummary: Bool {
    analyticsStore.canGenerateSummary
  }

  var analyticsCanSendFollowUp: Bool {
    analyticsStore.canSendFollowUp
  }
}
