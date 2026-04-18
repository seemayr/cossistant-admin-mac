import Foundation
import Observation
import CossistantAdmin

@Observable @MainActor
final class FAQStore {
  var optimizationTask: Task<Void, Never>?
  var conversationBuildTask: Task<Void, Never>?
  var hasOpenAIAPIKey = false
  var draft = FAQDraft()
  var suggestion: FAQDraftSuggestion?
  var selectedAIAgentID: String?
  var statusMessage: String?
  var errorMessage: String?
  var isOptimizing = false
  var isBuildingFromConversation = false
  var isSavingToKnowledge = false
  var isStartingTraining = false
  var lastSavedKnowledgeID: String?
  var lastSavedKnowledgeTitle: String?

  var canOptimize: Bool {
    hasOpenAIAPIKey
      && draft.hasMeaningfulContent
      && !isOptimizing
      && !isBuildingFromConversation
  }

  var canSaveDraftToKnowledge: Bool {
    draft.hasMeaningfulContent
      && !isOptimizing
      && !isBuildingFromConversation
      && !isSavingToKnowledge
      && !isStartingTraining
  }

  var canSaveSuggestionToKnowledge: Bool {
    suggestion != nil
      && !isOptimizing
      && !isBuildingFromConversation
      && !isSavingToKnowledge
      && !isStartingTraining
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
    selectedAIAgentID = nil
    lastSavedKnowledgeID = nil
    lastSavedKnowledgeTitle = nil
  }
}
