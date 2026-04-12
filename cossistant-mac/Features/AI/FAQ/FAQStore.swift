import Foundation
import Observation

@Observable @MainActor
final class FAQStore {
  var optimizationTask: Task<Void, Never>?
  var conversationBuildTask: Task<Void, Never>?
  var hasOpenAIAPIKey = false
  var draft = FAQDraft()
  var suggestion: FAQDraftSuggestion?
  var statusMessage: String?
  var errorMessage: String?
  var isOptimizing = false
  var isBuildingFromConversation = false

  var canOptimize: Bool {
    hasOpenAIAPIKey
      && draft.hasMeaningfulContent
      && !isOptimizing
      && !isBuildingFromConversation
  }

  func clearSuggestion() {
    suggestion = nil
    statusMessage = nil
    errorMessage = nil
  }

  func applySuggestionToDraft() {
    guard let suggestion else { return }
    draft = suggestion.draft
    statusMessage = "Copied the suggestion into the editable FAQ draft."
    errorMessage = nil
  }

  func resetDraft(keepSuggestion: Bool = true) {
    draft = FAQDraft()
    statusMessage = nil
    errorMessage = nil

    if !keepSuggestion {
      suggestion = nil
    }
  }
}
