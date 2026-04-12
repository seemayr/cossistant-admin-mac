import Foundation

@MainActor
final class ConversationActionsCoordinator {
  private let configuration: DashboardConfiguration
  private let conversationStore: ConversationStore
  private let selectedConversationID: () -> DashboardConversation.ID?
  private let selectedConversation: () -> DashboardConversation?
  private let website: () -> DashboardWebsite?
  private let organization: () -> DashboardOrganization?
  private let conversationSnapshot: (DashboardConversation.ID) -> DashboardConversation?
  private let setGlobalErrorMessage: (any Error) -> Void
  private let applyMutatedConversation: (DashboardConversationMutation, Bool, Bool) -> Void
  private let refreshSelectedConversationIfNeeded: (DashboardConversation.ID) async -> Void
  private let sendRealtimeTyping: (DashboardConversation.ID, Bool, String?) async -> Void
  private let setManualUnread: (DashboardConversation.ID, Bool) -> Void
  private let setConversationLastSeenAt: (DashboardConversation.ID, String?) -> Void
  private let setConversationTeamLastSeenAt: (DashboardConversation.ID, String?) -> Void
  private let syncConversationSeenState: (DashboardConversation.ID, [DashboardConversationSeen], String?) -> Void

  init(
    configuration: DashboardConfiguration,
    conversationStore: ConversationStore,
    selectedConversationID: @escaping () -> DashboardConversation.ID?,
    selectedConversation: @escaping () -> DashboardConversation?,
    website: @escaping () -> DashboardWebsite?,
    organization: @escaping () -> DashboardOrganization?,
    conversationSnapshot: @escaping (DashboardConversation.ID) -> DashboardConversation?,
    setGlobalErrorMessage: @escaping (any Error) -> Void,
    applyMutatedConversation: @escaping (DashboardConversationMutation, Bool, Bool) -> Void,
    refreshSelectedConversationIfNeeded: @escaping (DashboardConversation.ID) async -> Void,
    sendRealtimeTyping: @escaping (DashboardConversation.ID, Bool, String?) async -> Void,
    setManualUnread: @escaping (DashboardConversation.ID, Bool) -> Void,
    setConversationLastSeenAt: @escaping (DashboardConversation.ID, String?) -> Void,
    setConversationTeamLastSeenAt: @escaping (DashboardConversation.ID, String?) -> Void,
    syncConversationSeenState: @escaping (DashboardConversation.ID, [DashboardConversationSeen], String?) -> Void
  ) {
    self.configuration = configuration
    self.conversationStore = conversationStore
    self.selectedConversationID = selectedConversationID
    self.selectedConversation = selectedConversation
    self.website = website
    self.organization = organization
    self.conversationSnapshot = conversationSnapshot
    self.setGlobalErrorMessage = setGlobalErrorMessage
    self.applyMutatedConversation = applyMutatedConversation
    self.refreshSelectedConversationIfNeeded = refreshSelectedConversationIfNeeded
    self.sendRealtimeTyping = sendRealtimeTyping
    self.setManualUnread = setManualUnread
    self.setConversationLastSeenAt = setConversationLastSeenAt
    self.setConversationTeamLastSeenAt = setConversationTeamLastSeenAt
    self.syncConversationSeenState = syncConversationSeenState
  }

  func sendTimelineItem(_ item: DashboardTimelineItemDraft) async {
    guard let conversationID = selectedConversationID() else { return }

    do {
      let client = CossistantAPIClient(configuration: configuration)
      _ = try await client.sendTimelineItem(
        DashboardSendTimelineItemRequest(
          conversationId: conversationID,
          item: item
        )
      )
      await sendRealtimeTyping(conversationID, false, nil)
      await refreshSelectedConversationIfNeeded(conversationID)
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func sendMessage(
    text: String,
    visibility: DashboardTimelineItemVisibility,
    attachments: [DashboardComposerAttachment] = []
  ) async {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty || !attachments.isEmpty else { return }

    let senderUserID = website()?.availableHumanAgents.first?.id

    do {
      let parts = try await buildMessageParts(
        text: trimmedText,
        attachments: attachments
      )
      await sendTimelineItem(
        .message(
          trimmedText,
          visibility: visibility.rawValue,
          userID: senderUserID,
          parts: parts
        )
      )
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func markConversationRead(_ conversationID: DashboardConversation.ID) async {
    do {
      if DashboardReadDebug.isTargetConversation(conversationID),
         let existing = conversationSnapshot(conversationID) {
        DashboardReadDebug.log("WorkspaceModel.markRead", "before \(DashboardReadDebug.conversationSummary(existing))")
      }

      setManualUnread(conversationID, false)
      let optimisticSeenAt = ISO8601DateFormatter.internetDateTime.string(from: .now)
      setConversationLastSeenAt(conversationID, optimisticSeenAt)
      setConversationTeamLastSeenAt(conversationID, optimisticSeenAt)

      let client = CossistantAPIClient(configuration: configuration)
      let updatedConversation = try await client.markConversationRead(conversationID: conversationID)
      applyMutatedConversation(
        updatedConversation,
        true,
        true
      )
      if selectedConversationID() == conversationID {
        let seenData = try await client.fetchConversationSeenData(conversationID: conversationID)
        conversationStore.replaceSelectedSeenData(seenData)
        syncConversationSeenState(
          conversationID,
          seenData,
          optimisticSeenAt
        )
      }

      if DashboardReadDebug.isTargetConversation(conversationID),
         let updated = conversationSnapshot(conversationID) {
        DashboardReadDebug.log(
          "WorkspaceModel.markRead",
          "after \(DashboardReadDebug.conversationSummary(updated)) seenData=\(DashboardReadDebug.seenDataSummary(conversationStore.selectedSeenData))"
        )
      }
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func setSelectedConversationTyping(
    isTyping: Bool,
    visitorPreview: String? = nil,
    visitorID: String
  ) async {
    guard let conversationID = selectedConversationID() else { return }

    do {
      await sendRealtimeTyping(conversationID, isTyping, visitorPreview)
      let client = CossistantAPIClient(configuration: configuration)
      _ = try await client.setConversationTyping(
        conversationID: conversationID,
        payload: DashboardConversationTypingRequest(
          isTyping: isTyping,
          visitorPreview: visitorPreview,
          visitorId: visitorID
        )
      )
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func mutateConversation(
    _ conversationID: DashboardConversation.ID,
    preserveExistingLastMessageAt: Bool = false,
    preserveExistingLastSeenAt: Bool = false,
    using operation: (CossistantAPIClient) async throws -> DashboardConversationMutation
  ) async {
    do {
      let client = CossistantAPIClient(configuration: configuration)
      let updatedConversation = try await operation(client)
      applyMutatedConversation(
        updatedConversation,
        preserveExistingLastMessageAt,
        preserveExistingLastSeenAt
      )

      if selectedConversationID() == conversationID {
        await refreshSelectedConversationIfNeeded(conversationID)
      }
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func markConversationUnread(_ conversationID: DashboardConversation.ID) async {
    do {
      if DashboardReadDebug.isTargetConversation(conversationID),
         let existing = conversationSnapshot(conversationID) {
        DashboardReadDebug.log("WorkspaceModel.markUnread", "before \(DashboardReadDebug.conversationSummary(existing))")
      }

      setManualUnread(conversationID, true)
      setConversationLastSeenAt(conversationID, nil)

      let client = CossistantAPIClient(configuration: configuration)
      let updatedConversation = try await client.markConversationUnread(conversationID: conversationID)
      applyMutatedConversation(
        updatedConversation,
        true,
        false
      )

      if selectedConversationID() == conversationID {
        let seenData = try await client.fetchConversationSeenData(conversationID: conversationID)
        conversationStore.replaceSelectedSeenData(seenData)
        syncConversationSeenState(
          conversationID,
          seenData,
          nil
        )
      }

      if DashboardReadDebug.isTargetConversation(conversationID),
         let updated = conversationSnapshot(conversationID) {
        DashboardReadDebug.log(
          "WorkspaceModel.markUnread",
          "after \(DashboardReadDebug.conversationSummary(updated)) seenData=\(DashboardReadDebug.seenDataSummary(conversationStore.selectedSeenData))"
        )
      }
    } catch {
      setGlobalErrorMessage(error)
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
    guard let organization = organization(),
          let website = website(),
          let conversationID = selectedConversationID() else {
      throw StoreConfigurationError.notConfigured
    }

    let client = CossistantAPIClient(configuration: configuration)
    return try await client.generateUploadURL(
      DashboardSignedUploadRequest(
        contentType: contentType,
        websiteId: website.id,
        scope: .conversation(
          organizationId: organization.id,
          websiteId: website.id,
          conversationId: conversationID
        ),
        path: path,
        fileName: fileName,
        fileExtension: fileExtension,
        useCdn: useCdn,
        expiresInSeconds: expiresInSeconds
      )
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
    let signedUpload = try await prepareConversationUpload(
      contentType: contentType,
      fileName: fileName,
      fileExtension: fileExtension,
      path: path,
      useCdn: useCdn,
      expiresInSeconds: expiresInSeconds
    )

    let client = CossistantAPIClient(configuration: configuration)
    try await client.upload(data: data, using: signedUpload)
    return signedUpload
  }

  private func buildMessageParts(
    text: String,
    attachments: [DashboardComposerAttachment]
  ) async throws -> [JSONValue] {
    var parts: [JSONValue] = [
      .object([
        "type": .string("text"),
        "text": .string(text),
      ])
    ]

    guard !attachments.isEmpty else { return parts }

    var uploadedParts: [JSONValue] = []
    for attachment in attachments {
      let upload = try await uploadConversationData(
        attachment.data,
        contentType: attachment.contentType,
        fileName: attachment.fileName,
        fileExtension: URL(fileURLWithPath: attachment.fileName).pathExtension.nilIfEmpty
      )

      uploadedParts.append(
        .object([
          "type": .string(attachment.isImage ? "image" : "file"),
          "url": .string(upload.publicURL.absoluteString),
          "mediaType": .string(attachment.contentType),
          "filename": .string(attachment.fileName),
          "size": .number(Double(attachment.fileSizeBytes)),
        ])
      )
    }

    parts.append(contentsOf: uploadedParts)
    return parts
  }
}
