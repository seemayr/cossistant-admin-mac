import Foundation
import CossistantAdmin

@MainActor
final class FAQCoordinator {
  private let store: FAQStore
  private let canUseOpenAI: Bool
  private let openAIAPIKey: String
  private let workspaceName: String?
  private let selectedConversation: () -> DashboardConversation?
  private let fetchSelectedConversationTranscript: () async throws -> ConversationMachineTranscript
  private let encodeConversationTranscript: (ConversationMachineTranscript) throws -> String
  private let isIgnorableCancellation: (any Error) -> Bool

  init(
    store: FAQStore,
    canUseOpenAI: Bool,
    openAIAPIKey: String,
    workspaceName: String?,
    selectedConversation: @escaping () -> DashboardConversation?,
    fetchSelectedConversationTranscript: @escaping () async throws -> ConversationMachineTranscript,
    encodeConversationTranscript: @escaping (ConversationMachineTranscript) throws -> String,
    isIgnorableCancellation: @escaping (any Error) -> Bool
  ) {
    self.store = store
    self.canUseOpenAI = canUseOpenAI
    self.openAIAPIKey = openAIAPIKey
    self.workspaceName = workspaceName
    self.selectedConversation = selectedConversation
    self.fetchSelectedConversationTranscript = fetchSelectedConversationTranscript
    self.encodeConversationTranscript = encodeConversationTranscript
    self.isIgnorableCancellation = isIgnorableCancellation
  }

  func startOptimization() {
    guard store.optimizationTask == nil else { return }

    store.optimizationTask = Task {
      await self.optimizeDraft()
      if !Task.isCancelled {
        self.store.optimizationTask = nil
      }
    }
  }

  func startBuildFromSelectedConversation() {
    guard store.conversationBuildTask == nil else { return }

    store.conversationBuildTask = Task {
      await self.buildFromSelectedConversation()
      if !Task.isCancelled {
        self.store.conversationBuildTask = nil
      }
    }
  }

  func optimizeDraft() async {
    guard !store.isOptimizing else { return }
    guard canUseOpenAI else {
      store.errorMessage = "Add an OpenAI API key in settings to optimize FAQ entries."
      return
    }
    guard store.draft.hasMeaningfulContent else {
      store.errorMessage = "Fill at least one FAQ field before optimizing."
      return
    }

    store.isOptimizing = true
    store.errorMessage = nil
    store.statusMessage = "Optimizing FAQ draft…"
    defer { store.isOptimizing = false }

    do {
      let client = OpenAIFAQDraftingClient(apiKey: openAIAPIKey)
      let suggestion = try await client.optimizeDraft(
        store.draft,
        workspaceName: workspaceName
      )
      store.suggestion = suggestion
      store.statusMessage = "Created an optimized FAQ suggestion."
      store.optimizationTask = nil
    } catch {
      if isIgnorableCancellation(error) {
        store.optimizationTask = nil
        store.statusMessage = nil
        store.errorMessage = nil
        return
      }
      store.statusMessage = nil
      store.errorMessage = error.localizedDescription
      store.optimizationTask = nil
    }
  }

  func buildFromSelectedConversation() async {
    guard !store.isBuildingFromConversation else { return }
    guard canUseOpenAI else {
      store.errorMessage = "Add an OpenAI API key in settings to draft FAQs from conversations."
      return
    }
    guard selectedConversation() != nil else {
      store.errorMessage = "Select a conversation first."
      return
    }

    store.isBuildingFromConversation = true
    store.errorMessage = nil
    store.statusMessage = "Collecting the selected conversation…"
    defer { store.isBuildingFromConversation = false }

    do {
      let transcript = try await fetchSelectedConversationTranscript()
      guard !transcript.messages.isEmpty else {
        throw ConversationAssistantError.noConversationMessages
      }

      store.statusMessage = "Drafting FAQ from the selected conversation…"
      let transcriptJSON = try encodeConversationTranscript(transcript)
      let client = OpenAIFAQDraftingClient(apiKey: openAIAPIKey)
      var suggestion = try await client.buildDraftFromConversation(
        transcript: transcriptJSON,
        workspaceName: workspaceName,
        conversationTitle: transcript.title,
        messageCount: transcript.messages.count
      )
      suggestion = FAQDraftSuggestion(
        draft: suggestion.draft,
        notes: suggestion.notes,
        sourceConversationId: transcript.conversationId,
        sourceConversationTitle: transcript.title,
        sourceMessageCount: transcript.messages.count
      )
      store.suggestion = suggestion
      store.statusMessage = "Drafted a FAQ suggestion from \(transcript.messages.count) conversation messages."
      store.conversationBuildTask = nil
    } catch {
      if isIgnorableCancellation(error) {
        store.conversationBuildTask = nil
        store.statusMessage = nil
        store.errorMessage = nil
        return
      }
      store.statusMessage = nil
      store.errorMessage = error.localizedDescription
      store.conversationBuildTask = nil
    }
  }
}
