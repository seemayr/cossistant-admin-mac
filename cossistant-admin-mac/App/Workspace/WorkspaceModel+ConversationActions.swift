import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  func sendTimelineItem(_ item: DashboardTimelineItemDraft) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().sendTimelineItem(item)
  }

  func sendMessage(
    text: String,
    visibility: DashboardTimelineItemVisibility,
    attachments: [DashboardComposerAttachment] = []
  ) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().sendMessage(
      text: text,
      visibility: visibility,
      attachments: attachments
    )
  }

  func generateReplyFromFAQ(
    using faq: DashboardKnowledge
  ) async -> String? {
    errorMessage = nil
    return await makeConversationExportCoordinator().generateReplyFromFAQ(using: faq)
  }

  func loadFAQEntriesForConversation(
    aiAgentID: String?
  ) async throws -> [DashboardKnowledge] {
    let resolvedAIAgentID = aiAgentID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
      ?? website?.availableAIAgents.first?.id

    let agentFilter = resolvedAIAgentID.map(DashboardKnowledgeAIAgentFilter.specific) ?? .all
    var page = 1
    var hasMore = true
    var collectedItems: [DashboardKnowledge] = []

    while hasMore {
      let response = try await backendClient.knowledge.listKnowledge(
        page: page,
        limit: 100,
        type: .faq,
        aiAgentFilter: agentFilter,
        isIncluded: .included,
        linkSourceID: nil
      )

      collectedItems.append(contentsOf: response.items)
      hasMore = response.pagination.hasMore
      page += 1
    }

    var uniqueItems: [DashboardKnowledge] = []
    var seenIDs = Set<String>()

    for item in collectedItems where item.type == .faq && item.faqPayload != nil {
      if seenIDs.insert(item.id).inserted {
        uniqueItems.append(item)
      }
    }

    return uniqueItems
  }

  func translateConversationDraftPreview(
    _ text: String
  ) async throws -> DashboardMessageTranslation {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else {
      throw ConversationAssistantError.server(message: "Write a reply first.")
    }

    guard globalSettings.hasGoogleCloudTranslateAPIKey else {
      throw ConversationAssistantError.server(
        message: "Add a Google Cloud Translate API key in settings to preview translations."
      )
    }

    let client = GoogleCloudTranslateClient(apiKey: globalSettings.trimmedGoogleCloudTranslateAPIKey)
    guard let translation = try await client.translate(
      texts: [trimmedText],
      targetLanguageCode: Self.preferredTranslationLanguageCode
    ).first else {
      throw ConversationAssistantError.invalidResponse
    }

    return translation
  }

  func markSelectedConversationRead() async {
    guard let conversationID = selectedConversationID else { return }
    await markConversationRead(conversationID)
  }

  func markConversationRead(_ conversationID: DashboardConversation.ID) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().markConversationRead(conversationID)
  }

  func setSelectedConversationTyping(
    isTyping: Bool,
    visitorPreview: String? = nil,
    visitorID: String
  ) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().setSelectedConversationTyping(
      isTyping: isTyping,
      visitorPreview: visitorPreview,
      visitorID: visitorID
    )
  }

  func resolveConversation(_ conversationID: DashboardConversation.ID) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().mutateConversation(conversationID) { client in
      try await client.resolveConversation(conversationID: conversationID)
    }
  }

  func reopenConversation(_ conversationID: DashboardConversation.ID) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().mutateConversation(conversationID) { client in
      try await client.reopenConversation(conversationID: conversationID)
    }
  }

  func markConversationSpam(_ conversationID: DashboardConversation.ID) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().mutateConversation(conversationID) { client in
      try await client.markConversationSpam(conversationID: conversationID)
    }
  }

  func markConversationNotSpam(_ conversationID: DashboardConversation.ID) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().mutateConversation(conversationID) { client in
      try await client.markConversationNotSpam(conversationID: conversationID)
    }
  }

  func markConversationUnread(_ conversationID: DashboardConversation.ID) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().markConversationUnread(conversationID)
  }

  func archiveConversation(_ conversationID: DashboardConversation.ID) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().mutateConversation(conversationID) { client in
      try await client.archiveConversation(conversationID: conversationID)
    }
  }

  func unarchiveConversation(_ conversationID: DashboardConversation.ID) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().mutateConversation(conversationID) { client in
      try await client.unarchiveConversation(conversationID: conversationID)
    }
  }

  func updateConversationTitle(
    _ conversationID: DashboardConversation.ID,
    title: String?
  ) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().mutateConversation(conversationID) { client in
      try await client.updateConversationTitle(conversationID: conversationID, title: title)
    }
  }

  func updateConversationMetadata(
    _ conversationID: DashboardConversation.ID,
    metadata: DashboardMetadata
  ) async throws {
    errorMessage = nil

    do {
      try await makeConversationActionsCoordinator().performConversationMutation(
        conversationID,
        using: { client in
          try await client.updateConversationMetadata(
            conversationID: conversationID,
            metadata: metadata
          )
        }
      )
    } catch {
      errorMessage = error.localizedDescription
      throw error
    }
  }

  func joinConversationEscalation(_ conversationID: DashboardConversation.ID) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().mutateConversation(conversationID) { client in
      try await client.joinConversationEscalation(conversationID: conversationID)
    }
  }

  func dismissConversationClarification(_ conversationID: DashboardConversation.ID) async {
    errorMessage = nil
    inboxStore.dismissActiveClarificationLocally(for: conversationID)
    conversationStore.translatedClarification = nil
  }

  func pauseConversationAI(
    _ conversationID: DashboardConversation.ID,
    durationMinutes: Int
  ) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().mutateConversation(conversationID) { client in
      try await client.pauseConversationAI(
        conversationID: conversationID,
        durationMinutes: durationMinutes
      )
    }
  }

  func resumeConversationAI(_ conversationID: DashboardConversation.ID) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().mutateConversation(conversationID) { client in
      try await client.resumeConversationAI(conversationID: conversationID)
    }
  }

  func identifySelectedVisitor(
    externalID: String? = nil,
    name: String? = nil,
    email: String? = nil,
    image: URL? = nil,
    metadata: DashboardMetadata? = nil,
    contactOrganizationID: String? = nil
  ) async {
    guard let visitorID = selectedConversation?.visitorId else { return }

    let response = await contactsStore.identifyContact(
      request: DashboardIdentifyContactRequest(
        id: nil,
        visitorId: visitorID,
        externalId: externalID,
        name: name,
        email: email,
        image: image,
        metadata: metadata,
        contactOrganizationId: contactOrganizationID
      )
    )

    if response != nil {
      await loadSelectedConversation(force: true, showsLoadingState: false)
    }
  }

  func prepareConversationUpload(
    contentType: String,
    fileName: String,
    fileExtension: String? = nil,
    path: String? = nil,
    useCdn: Bool = true,
    expiresInSeconds: Int? = nil
  ) async throws -> DashboardSignedUploadResponse {
    try await makeConversationActionsCoordinator().prepareConversationUpload(
      contentType: contentType,
      fileName: fileName,
      fileExtension: fileExtension,
      path: path,
      useCdn: useCdn,
      expiresInSeconds: expiresInSeconds
    )
  }

  func uploadConversationData(
    _ data: Data,
    contentType: String,
    fileName: String,
    fileExtension: String? = nil,
    path: String? = nil,
    useCdn: Bool = true,
    expiresInSeconds: Int? = nil
  ) async throws -> DashboardSignedUploadResponse {
    try await makeConversationActionsCoordinator().uploadConversationData(
      data,
      contentType: contentType,
      fileName: fileName,
      fileExtension: fileExtension,
      path: path,
      useCdn: useCdn,
      expiresInSeconds: expiresInSeconds
    )
  }
}

private extension String {
  var nilIfEmpty: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
