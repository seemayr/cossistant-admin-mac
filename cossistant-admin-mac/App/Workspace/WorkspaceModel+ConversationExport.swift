import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  func copySelectedConversationMessages() async {
    guard !conversationStore.isCopyingConversationMessages else { return }

    conversationStore.isCopyingConversationMessages = true
    defer { conversationStore.isCopyingConversationMessages = false }

    do {
      let export = try await makeConversationExportCoordinator().buildSelectedConversationMessagesMarkdown()
      StringClipboardWriter.copy(export)
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func copySelectedConversationFullLog() async {
    guard !conversationStore.isCopyingConversationMessages else { return }

    conversationStore.isCopyingConversationMessages = true
    defer { conversationStore.isCopyingConversationMessages = false }

    do {
      let export = try await makeConversationExportCoordinator().buildSelectedConversationFullLogExport()
      StringClipboardWriter.copy(export)
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func generateReplyDraft(from draft: String) async -> String? {
    await makeConversationExportCoordinator().generateReplyDraft(from: draft)
  }

  func buildSelectedConversationMessagesMarkdown() async throws -> String {
    try await makeConversationExportCoordinator().buildSelectedConversationMessagesMarkdown()
  }

  func buildSelectedConversationMessagesExport() async throws -> String {
    try await makeConversationExportCoordinator().buildSelectedConversationMessagesExport()
  }

  func buildSelectedConversationFullLogExport() async throws -> String {
    try await makeConversationExportCoordinator().buildSelectedConversationFullLogExport()
  }

  func encodeConversationTranscript(
    _ transcript: ConversationMachineTranscript
  ) throws -> String {
    try makeConversationExportCoordinator().encodeConversationTranscript(transcript)
  }

  func fetchSelectedConversationTranscript(
    maxPages: Int = 20
  ) async throws -> ConversationMachineTranscript {
    try await makeConversationExportCoordinator().fetchSelectedConversationTranscript(maxPages: maxPages)
  }
}
