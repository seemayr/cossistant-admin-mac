import Foundation

@MainActor
extension WorkspaceModel {
  func clearFAQSuggestion() {
    faqStore.clearSuggestion()
  }

  func applyFAQSuggestionToDraft() {
    faqStore.applySuggestionToDraft()
  }

  func resetFAQDraft(keepSuggestion: Bool = true) {
    faqStore.resetDraft(keepSuggestion: keepSuggestion)
  }

  func startFAQOptimization() {
    makeFAQCoordinator().startOptimization()
  }

  func startFAQBuildFromSelectedConversation() {
    makeFAQCoordinator().startBuildFromSelectedConversation()
  }

  func optimizeFAQDraft() async {
    await makeFAQCoordinator().optimizeDraft()
  }

  func buildFAQFromSelectedConversation() async {
    await makeFAQCoordinator().buildFromSelectedConversation()
  }
}
