import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  func makeConversationActionsCoordinator() -> ConversationActionsCoordinator {
    ConversationActionsCoordinator(
      backendClient: backendClient,
      conversationStore: conversationStore,
      selectedConversationID: { [weak self] in
        self?.selectedConversationID
      },
      selectedConversation: { [weak self] in
        self?.selectedConversation
      },
      website: { [weak self] in
        self?.website
      },
      organization: { [weak self] in
        self?.organization
      },
      conversationSnapshot: { [weak self] conversationID in
        self?.inboxStore.conversation(withID: conversationID)
      },
      setGlobalErrorMessage: setGlobalErrorMessage,
      applyMutatedConversation: { [weak self] mutation, preserveExistingLastMessageAt, preserveExistingLastSeenAt in
        self?.applyMutatedConversation(
          mutation,
          preserveExistingLastMessageAt: preserveExistingLastMessageAt,
          preserveExistingLastSeenAt: preserveExistingLastSeenAt
        )
      },
      refreshSelectedConversationIfNeeded: { [weak self] conversationID in
        guard let self, self.selectedConversationID == conversationID else { return }
        await self.loadSelectedConversation(force: true, showsLoadingState: false)
      },
      sendRealtimeTyping: { [weak self] conversationID, isTyping, visitorPreview in
        await self?.runtimeCoordinator.send(.conversationTyping(
          conversationId: conversationID,
          isTyping: isTyping,
          visitorPreview: visitorPreview
        ))
      },
      setManualUnread: { [weak self] conversationID, isUnread in
        guard let self else { return }
        if isUnread {
          self.manuallyUnreadConversationIDs.insert(conversationID)
        } else {
          self.manuallyUnreadConversationIDs.remove(conversationID)
        }
      },
      setConversationLastSeenAt: { [weak self] conversationID, lastSeenAt in
        self?.setConversationLastSeenAt(conversationID: conversationID, lastSeenAt: lastSeenAt)
      },
      setConversationTeamLastSeenAt: { [weak self] conversationID, lastSeenAt in
        self?.setConversationTeamLastSeenAt(conversationID: conversationID, lastSeenAt: lastSeenAt)
      },
      syncConversationSeenState: { [weak self] conversationID, seenData, fallbackCurrentActorSeenAt in
        self?.syncConversationSeenState(
          conversationID: conversationID,
          with: seenData,
          fallbackCurrentActorSeenAt: fallbackCurrentActorSeenAt
        )
      }
    )
  }

  func makeConversationExportCoordinator() -> ConversationExportCoordinator {
    ConversationExportCoordinator(
      store: conversationStore,
      backendClient: backendClient,
      canUseOpenAI: canUseOpenAIReplyDrafts,
      openAIAPIKey: globalSettings.trimmedOpenAIAPIKey,
      workspaceName: website?.name,
      selectedConversation: { [weak self] in
        self?.selectedConversation
      },
      selectedVisitor: { [weak self] in
        self?.selectedVisitor
      },
      selectedConversationID: { [weak self] in
        self?.selectedConversationID
      },
      website: { [weak self] in
        self?.website
      }
    )
  }
}
