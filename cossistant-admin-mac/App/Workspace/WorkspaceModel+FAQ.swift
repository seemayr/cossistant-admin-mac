import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  private var preferredKnowledgeAIAgentID: String? {
    website?.availableAIAgents.count == 1 ? website?.availableAIAgents.first?.id : nil
  }

  func clearFAQSuggestion() {
    faqStore.clearSuggestion()
  }

  func applyFAQSuggestionToDraft() {
    faqStore.applySuggestionToDraft()
  }

  func resetFAQDraft(keepSuggestion: Bool = true) {
    faqStore.resetDraft(keepSuggestion: keepSuggestion)
    faqStore.selectedAIAgentID = preferredKnowledgeAIAgentID
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

  @discardableResult
  func saveFAQToKnowledge(
    usingSuggestion: Bool,
    startTraining: Bool
  ) async -> DashboardKnowledge? {
    let sourceDraft: FAQDraft
    let suggestion = faqStore.suggestion

    if usingSuggestion {
      guard let suggestedDraft = suggestion?.draft else {
        faqStore.errorMessage = "There is no suggestion to save yet."
        return nil
      }
      sourceDraft = suggestedDraft
    } else {
      sourceDraft = faqStore.draft
    }

    guard sourceDraft.hasMeaningfulContent else {
      faqStore.errorMessage = "Fill the FAQ draft before saving it to knowledge."
      return nil
    }

    let selectedAIAgentID = faqStore.selectedAIAgentID ?? preferredKnowledgeAIAgentID

    if startTraining, selectedAIAgentID == nil {
      faqStore.errorMessage = "Pick an AI agent before starting training."
      return nil
    }

    faqStore.errorMessage = nil
    faqStore.isSavingToKnowledge = true
    faqStore.statusMessage = "Saving FAQ to knowledge…"
    defer { faqStore.isSavingToKnowledge = false }

    do {
      let request = try makeKnowledgeDraft(
        from: sourceDraft,
        usingSuggestion: usingSuggestion,
        suggestion: suggestion
      )
      let createdKnowledge = try await backendClient.knowledge.createKnowledge(request)
      faqStore.lastSavedKnowledgeID = createdKnowledge.id
      faqStore.lastSavedKnowledgeTitle = createdKnowledge.titleText

      if startTraining, let aiAgentID = request.aiAgentId {
        faqStore.isStartingTraining = true
        faqStore.statusMessage = "FAQ saved. Queueing AI agent training…"
        defer { faqStore.isStartingTraining = false }

        _ = try await backendClient.aiAgents.startTraining(id: aiAgentID)
        if aiAgentStore.selectedAIAgent?.id == aiAgentID {
          await aiAgentStore.refreshTrainingStatus(id: aiAgentID)
        }
        faqStore.statusMessage = "Saved the FAQ and queued training for the selected AI agent."
      } else {
        faqStore.statusMessage = "Saved the FAQ to the knowledge base."
      }

      return createdKnowledge
    } catch {
      faqStore.statusMessage = nil
      faqStore.errorMessage = error.localizedDescription
      return nil
    }
  }

  private func makeKnowledgeDraft(
    from draft: FAQDraft,
    usingSuggestion: Bool,
    suggestion: FAQDraftSuggestion?
  ) throws -> DashboardKnowledgeDraft {
    var editorDraft = DashboardKnowledgeEditorDraft(type: .faq)
    editorDraft.aiAgentID = faqStore.selectedAIAgentID ?? preferredKnowledgeAIAgentID ?? ""
    editorDraft.origin = usingSuggestion ? "faq-suggestion" : "manual"
    editorDraft.faqQuestion = draft.normalizedQuestion
    editorDraft.faqAnswer = draft.normalizedAnswer
    editorDraft.faqCategoriesText = draft.categoriesDisplayText
    editorDraft.faqRelatedQuestionsText = draft.relatedQuestionsDisplayText

    var metadata: [String: Any] = [
      "draftSource": usingSuggestion ? "ai_suggestion" : "manual",
      "createdIn": "cossistant-admin-mac",
    ]

    if let suggestion {
      if let sourceConversationId = suggestion.sourceConversationId {
        metadata["sourceConversationId"] = sourceConversationId
      }
      if let sourceConversationTitle = suggestion.sourceConversationTitle {
        metadata["sourceConversationTitle"] = sourceConversationTitle
      }
      if let sourceMessageCount = suggestion.sourceMessageCount {
        metadata["sourceMessageCount"] = sourceMessageCount
      }
    }

    if JSONSerialization.isValidJSONObject(metadata),
       let data = try? JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted]),
       let metadataText = String(data: data, encoding: .utf8) {
      editorDraft.metadataText = metadataText
    }

    return try editorDraft.makeRequest()
  }
}
