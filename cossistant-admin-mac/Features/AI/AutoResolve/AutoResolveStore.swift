import Foundation
import Observation
import CossistantAdmin

@Observable @MainActor
final class AutoResolveStore {
  var task: Task<Void, Never>?
  var hasOpenAIAPIKey = false
  var sourceScope: AutoResolveSourceScope = .open
  var inspectedConversationID: String?
  var statusMessage: String?
  var isRunning = false
  var results: [AutoResolveResult] = []
  var selectedCategoryFilter: AutoResolveConversationCategory?
  var closedEmptyConversationCount = 0
  var autoResolvedNonEmptyConversationCount = 0
  var keptOpenNonEmptyConversationCount = 0

  var canClearResults: Bool {
    !isRunning && (!results.isEmpty || statusMessage != nil || closedEmptyConversationCount > 0)
  }

  func resetResults() {
    results = []
    selectedCategoryFilter = nil
    inspectedConversationID = nil
    statusMessage = nil
    closedEmptyConversationCount = 0
    autoResolvedNonEmptyConversationCount = 0
    keptOpenNonEmptyConversationCount = 0
  }
}
