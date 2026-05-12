import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  func makeAnalyticsCoordinator() -> AnalyticsCoordinator {
    AnalyticsCoordinator(
      store: analyticsStore,
      backendClient: backendClient,
      canUseOpenAI: canUseOpenAIReplyDrafts,
      openAIAPIKey: globalSettings.trimmedOpenAIAPIKey,
      workspaceName: website?.name,
      inboxPageSize: Self.inboxPageSize,
      fetchAIMessageItems: fetchAIMessageItems,
      isIgnorableCancellation: isIgnorableCancellation
    )
  }

  func makeAutoResolveCoordinator() -> AutoResolveCoordinator {
    AutoResolveCoordinator(
      store: autoResolveStore,
      backendClient: backendClient,
      canUseOpenAI: canUseOpenAIReplyDrafts,
      openAIAPIKey: globalSettings.trimmedOpenAIAPIKey,
      workspaceName: website?.name,
      candidateConversations: autoResolveCandidateConversations,
      eligibleScope: autoResolveEligibleScope,
      fetchAIMessageItems: fetchAIMessageItems,
      applyMutatedConversation: { [weak self] mutation in
        self?.applyMutatedConversation(mutation)
      },
      refreshSelectedConversationIfNeeded: { [weak self] conversationID in
        guard let self, self.selectedConversationID == conversationID else { return }
        await self.loadSelectedConversation(force: true, showsLoadingState: false)
      },
      setGlobalErrorMessage: setGlobalErrorMessage,
      isIgnorableCancellation: isIgnorableCancellation
    )
  }

  func makeFAQResolverCoordinator() -> FAQResolverCoordinator {
    FAQResolverCoordinator(
      store: faqResolverStore,
      backendClient: backendClient,
      canUseOpenAI: canUseOpenAIReplyDrafts,
      canPreviewDraftTranslations: canUseConversationDraftTranslation,
      openAIAPIKey: globalSettings.trimmedOpenAIAPIKey,
      workspaceName: website?.name,
      humanSenderUserID: { [weak self] in
        self?.website?.availableHumanAgents.first?.id
      },
      eligibleConversations: { [weak self] in
        self?.faqResolverEligibleConversations() ?? []
      },
      fetchAIMessageItems: fetchAIMessageItems,
      translateDraftPreview: { [weak self] text in
        guard let self else { throw ConversationAssistantError.invalidResponse }
        return try await self.translateConversationDraftPreview(text)
      },
      applyMutatedConversation: { [weak self] mutation, preserveExistingLastMessageAt, preserveExistingLastSeenAt in
        self?.applyMutatedConversation(
          mutation,
          preserveExistingLastMessageAt: preserveExistingLastMessageAt,
          preserveExistingLastSeenAt: preserveExistingLastSeenAt
        )
      },
      setConversationLastSeenAt: { [weak self] conversationID, lastSeenAt in
        self?.setConversationLastSeenAt(
          conversationID: conversationID,
          lastSeenAt: lastSeenAt
        )
      },
      refreshSelectedConversationIfNeeded: { [weak self] conversationID in
        guard let self, self.selectedConversationID == conversationID else { return }
        await self.loadSelectedConversation(force: true, showsLoadingState: false)
      },
      setGlobalErrorMessage: setGlobalErrorMessage,
      isIgnorableCancellation: isIgnorableCancellation
    )
  }

  func makeFAQCoordinator() -> FAQCoordinator {
    let exportCoordinator = makeConversationExportCoordinator()

    return FAQCoordinator(
      store: faqStore,
      canUseOpenAI: canUseOpenAIReplyDrafts,
      openAIAPIKey: globalSettings.trimmedOpenAIAPIKey,
      workspaceName: website?.name,
      selectedConversation: { [weak self] in
        self?.selectedConversation
      },
      fetchSelectedConversationTranscript: {
        try await exportCoordinator.fetchSelectedConversationTranscript()
      },
      encodeConversationTranscript: exportCoordinator.encodeConversationTranscript,
      isIgnorableCancellation: isIgnorableCancellation
    )
  }
}
