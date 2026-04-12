import Foundation

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

  func joinConversationEscalation(_ conversationID: DashboardConversation.ID) async {
    errorMessage = nil
    await makeConversationActionsCoordinator().mutateConversation(conversationID) { client in
      try await client.joinConversationEscalation(conversationID: conversationID)
    }
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
