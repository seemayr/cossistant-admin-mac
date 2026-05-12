import Foundation
import Observation
import CossistantAdmin

@Observable @MainActor
final class AutoResolveStore {
  private var workspaceChannelFilter: String?

  var task: Task<Void, Never>?
  var hasOpenAIAPIKey = false
  var sourceScope: AutoResolveSourceScope = .open
  var priorityFilter: InboxPriorityFilter = .all
  var dateRange: AutoResolveDateRange = .all
  var dateBasis: AutoResolveDateBasis = .latestActivity
  var attentionFilter: AutoResolveAttentionFilter = .all
  var channelFilter: String?
  var metadataFilters: [InboxMetadataFilterKey: JSONValue] = [:]
  var appVersionFilter: String?
  var gameIDFilter: String?
  var inspectedConversationID: String?
  var statusMessage: String?
  var isRunning = false
  var results: [AutoResolveResult] = []
  var selectedCategoryFilter: AutoResolveConversationCategory?
  var selectedOutcomeFilter: AutoResolveResultFilter?
  var closedEmptyConversationCount = 0
  var autoResolvedNonEmptyConversationCount = 0
  var keptOpenNonEmptyConversationCount = 0

  var canClearResults: Bool {
    !isRunning && (!results.isEmpty || statusMessage != nil || closedEmptyConversationCount > 0)
  }

  var hasActiveCandidateFilters: Bool {
    priorityFilter != .all
      || dateRange != .all
      || attentionFilter != .all
      || channelFilter != nil
      || !metadataFilters.isEmpty
      || appVersionFilter != nil
      || gameIDFilter != nil
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

  func clearCandidateFilters() {
    priorityFilter = .all
    dateRange = .all
    dateBasis = .latestActivity
    attentionFilter = .all
    channelFilter = workspaceChannelFilter
    metadataFilters = [:]
    appVersionFilter = nil
    gameIDFilter = nil
  }

  func applyWorkspaceChannelFilter(_ channelFilter: String?) {
    workspaceChannelFilter = channelFilter
    self.channelFilter = channelFilter
  }

  func resetResults() {
    results = []
    selectedCategoryFilter = nil
    selectedOutcomeFilter = nil
    inspectedConversationID = nil
    statusMessage = nil
    closedEmptyConversationCount = 0
    autoResolvedNonEmptyConversationCount = 0
    keptOpenNonEmptyConversationCount = 0
  }
}
