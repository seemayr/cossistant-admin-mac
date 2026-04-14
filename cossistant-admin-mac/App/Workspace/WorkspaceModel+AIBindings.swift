import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  var autoResolveTask: Task<Void, Never>? {
    get { autoResolveStore.task }
    set { autoResolveStore.task = newValue }
  }

  var autoResolveSourceScope: AutoResolveSourceScope {
    get { autoResolveStore.sourceScope }
    set { autoResolveStore.sourceScope = newValue }
  }

  var autoResolveStatusMessage: String? {
    get { autoResolveStore.statusMessage }
    set { autoResolveStore.statusMessage = newValue }
  }

  var autoResolveIsRunning: Bool {
    get { autoResolveStore.isRunning }
    set { autoResolveStore.isRunning = newValue }
  }

  var autoResolveResults: [AutoResolveResult] {
    get { autoResolveStore.results }
    set { autoResolveStore.results = newValue }
  }

  var faqOptimizationTask: Task<Void, Never>? {
    get { faqStore.optimizationTask }
    set { faqStore.optimizationTask = newValue }
  }

  var faqConversationBuildTask: Task<Void, Never>? {
    get { faqStore.conversationBuildTask }
    set { faqStore.conversationBuildTask = newValue }
  }

  var faqDraft: FAQDraft {
    get { faqStore.draft }
    set { faqStore.draft = newValue }
  }

  var faqSuggestion: FAQDraftSuggestion? {
    get { faqStore.suggestion }
    set { faqStore.suggestion = newValue }
  }

  var faqStatusMessage: String? {
    get { faqStore.statusMessage }
    set { faqStore.statusMessage = newValue }
  }

  var faqErrorMessage: String? {
    get { faqStore.errorMessage }
    set { faqStore.errorMessage = newValue }
  }

  var faqIsOptimizing: Bool {
    get { faqStore.isOptimizing }
    set { faqStore.isOptimizing = newValue }
  }

  var faqIsBuildingFromConversation: Bool {
    get { faqStore.isBuildingFromConversation }
    set { faqStore.isBuildingFromConversation = newValue }
  }

  var faqCanOptimize: Bool {
    faqStore.canOptimize
  }

  var faqCanBuildFromConversation: Bool {
    canUseOpenAIReplyDrafts
      && selectedConversation != nil
      && !faqIsOptimizing
      && !faqIsBuildingFromConversation
  }
}
