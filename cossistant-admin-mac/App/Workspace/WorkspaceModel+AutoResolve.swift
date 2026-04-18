import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  func inspectAutoResolveConversation(_ conversationID: DashboardConversation.ID) async {
    autoResolveStore.inspectedConversationID = conversationID
    selectConversation(conversationID)
  }

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

  func markAutoResolveResultSeen(_ conversationID: DashboardConversation.ID) async {
    guard let index = autoResolveResults.firstIndex(where: { $0.conversationID == conversationID }) else {
      return
    }

    autoResolveResults[index].isMarkingSeen = true

    do {
      manuallyUnreadConversationIDs.remove(conversationID)

      let optimisticSeenAt = ISO8601DateFormatter.internetDateTime.string(from: .now)
      setConversationLastSeenAt(conversationID: conversationID, lastSeenAt: optimisticSeenAt)

      let updatedConversation = try await backendClient.conversations.markConversationRead(
        conversationID: conversationID
      )
      applyMutatedConversation(
        updatedConversation,
        preserveExistingLastMessageAt: true,
        preserveExistingLastSeenAt: true
      )

      if selectedConversationID == conversationID {
        let seenData = try await backendClient.conversations.fetchConversationSeenData(
          conversationID: conversationID
        )
        selectedSeenData = seenData
        syncConversationSeenState(
          conversationID: conversationID,
          with: seenData,
          fallbackCurrentActorSeenAt: optimisticSeenAt
        )
      }

      guard let updatedIndex = autoResolveResults.firstIndex(where: { $0.conversationID == conversationID }) else {
        return
      }

      autoResolveResults[updatedIndex].isMarkingSeen = false
      autoResolveResults[updatedIndex].isSeen = true
      autoResolveResults[updatedIndex].decisionNote = "Marked as seen from the Auto-Resolve results."
    } catch {
      errorMessage = error.localizedDescription

      guard let updatedIndex = autoResolveResults.firstIndex(where: { $0.conversationID == conversationID }) else {
        return
      }

      autoResolveResults[updatedIndex].isMarkingSeen = false
      autoResolveResults[updatedIndex].decisionNote = "Mark as seen failed: \(error.localizedDescription)"
    }
  }
}
