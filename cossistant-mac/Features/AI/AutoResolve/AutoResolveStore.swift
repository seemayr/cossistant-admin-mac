import Foundation
import Observation

@Observable @MainActor
final class AutoResolveStore {
  var task: Task<Void, Never>?
  var hasOpenAIAPIKey = false
  var sourceScope: AutoResolveSourceScope = .open
  var inspectedConversationID: String?
  var statusMessage: String?
  var isRunning = false
  var results: [AutoResolveResult] = []

  var canClearResults: Bool {
    !isRunning && (!results.isEmpty || statusMessage != nil)
  }
}
