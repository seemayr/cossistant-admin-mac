import Foundation

@MainActor
extension WorkspaceModel {
  func startAutoResolve() {
    makeAutoResolveCoordinator().start()
  }

  func cancelAutoResolve() {
    makeAutoResolveCoordinator().cancel()
  }

  func clearAutoResolveResults() {
    makeAutoResolveCoordinator().clearResults()
  }

  func runInboxAutoResolve(in scope: InboxScope) async {
    await makeAutoResolveCoordinator().run(in: scope)
  }

  func resolveAutoResolveResult(_ conversationID: DashboardConversation.ID) async {
    guard let index = autoResolveResults.firstIndex(where: { $0.conversationID == conversationID }) else {
      return
    }

    autoResolveResults[index].isResolvingAnyway = true

    do {
      try await makeConversationActionsCoordinator().performConversationMutation(conversationID) { client in
        try await client.resolveConversation(conversationID: conversationID)
      }

      guard let updatedIndex = autoResolveResults.firstIndex(where: { $0.conversationID == conversationID }) else {
        return
      }

      autoResolveResults[updatedIndex].isResolvingAnyway = false
      autoResolveResults[updatedIndex].outcome = .manuallyResolved
      autoResolveResults[updatedIndex].decisionNote = "Resolved manually from the Auto-Resolve results."
    } catch {
      errorMessage = error.localizedDescription

      guard let updatedIndex = autoResolveResults.firstIndex(where: { $0.conversationID == conversationID }) else {
        return
      }

      autoResolveResults[updatedIndex].isResolvingAnyway = false
      autoResolveResults[updatedIndex].decisionNote = "Manual resolve failed: \(error.localizedDescription)"
    }
  }
}
