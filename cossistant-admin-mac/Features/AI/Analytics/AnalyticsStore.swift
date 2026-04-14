import Foundation
import Observation
import CossistantAdmin

@Observable @MainActor
final class AnalyticsStore {
  var summaryTask: Task<Void, Never>?
  var followUpTask: Task<Void, Never>?
  var hasOpenAIAPIKey = false
  var rangeMode: AnalyticsSummaryRangeMode = .lastDays
  var lastHours = 24
  var lastDays = 7
  var customStartDate = Calendar.current.date(
    byAdding: .day,
    value: -7,
    to: Date()
  ) ?? Date()
  var customEndDate = Date()
  var summaryMessages: [AnalyticsSummaryChatMessage] = []
  var followUpDraft = ""
  var summaryStatusMessage: String?
  var summaryErrorMessage: String?
  var isGeneratingSummary = false
  var isSendingFollowUp = false
  var conversationCount = 0
  var sourceMessageCount = 0
  var sourceDocument: String?
  var summaryResponseID: String?
  var summaryGeneratedAt: Date?
  var summaryRangeLabel: String?
  var summaryUsedChunking = false

  var selectedDateRange: AnalyticsSummaryDateRange? {
    switch rangeMode {
    case .lastHours:
      guard lastHours > 0,
            let start = Calendar.current.date(byAdding: .hour, value: -lastHours, to: .now) else {
        return nil
      }
      return AnalyticsSummaryDateRange(start: start, end: .now)
    case .lastDays:
      guard lastDays > 0,
            let start = Calendar.current.date(byAdding: .day, value: -lastDays, to: .now) else {
        return nil
      }
      return AnalyticsSummaryDateRange(start: start, end: .now)
    case .custom:
      let start = min(customStartDate, customEndDate)
      let end = max(customStartDate, customEndDate)
      guard start < end else { return nil }
      return AnalyticsSummaryDateRange(start: start, end: end)
    }
  }

  var canGenerateSummary: Bool {
    hasOpenAIAPIKey
      && selectedDateRange != nil
      && !isGeneratingSummary
      && !isSendingFollowUp
  }

  var canSendFollowUp: Bool {
    summaryResponseID != nil
      && followUpDraft.nilIfEmpty != nil
      && !isGeneratingSummary
      && !isSendingFollowUp
  }
}
