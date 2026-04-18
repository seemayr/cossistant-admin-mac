import Foundation
import CossistantAdmin

@MainActor
final class ConversationActionsCoordinator {
  private let backendClient: CossistantAdminClient
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
  private let syncConversationSeenState: (DashboardConversation.ID, [DashboardConversationSeen], String?) -> Void

  init(
    backendClient: CossistantAdminClient,
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
    syncConversationSeenState: @escaping (DashboardConversation.ID, [DashboardConversationSeen], String?) -> Void
  ) {
    self.backendClient = backendClient
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
    self.syncConversationSeenState = syncConversationSeenState
  }

  func sendTimelineItem(_ item: DashboardTimelineItemDraft) async {
    guard let conversationID = selectedConversationID() else { return }

    do {
      _ = try await backendClient.conversations.sendTimelineItem(
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

      let updatedConversation = try await backendClient.conversations.markConversationRead(
        conversationID: conversationID
      )
      applyMutatedConversation(
        updatedConversation,
        true,
        true
      )
      if selectedConversationID() == conversationID {
        let seenData = try await backendClient.conversations.fetchConversationSeenData(
          conversationID: conversationID
        )
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
      _ = try await backendClient.conversations.setConversationTyping(
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
    using operation: (CossistantAdminClient.ConversationsAPI) async throws -> DashboardConversationMutation
  ) async {
    do {
      try await performConversationMutation(
        conversationID,
        preserveExistingLastMessageAt: preserveExistingLastMessageAt,
        preserveExistingLastSeenAt: preserveExistingLastSeenAt,
        using: operation
      )
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func performConversationMutation(
    _ conversationID: DashboardConversation.ID,
    preserveExistingLastMessageAt: Bool = false,
    preserveExistingLastSeenAt: Bool = false,
    using operation: (CossistantAdminClient.ConversationsAPI) async throws -> DashboardConversationMutation
  ) async throws {
    let updatedConversation = try await operation(backendClient.conversations)
    applyMutatedConversation(
      updatedConversation,
      preserveExistingLastMessageAt,
      preserveExistingLastSeenAt
    )

    if selectedConversationID() == conversationID {
      await refreshSelectedConversationIfNeeded(conversationID)
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

      let updatedConversation = try await backendClient.conversations.markConversationUnread(
        conversationID: conversationID
      )
      applyMutatedConversation(
        updatedConversation,
        true,
        false
      )

      if selectedConversationID() == conversationID {
        let seenData = try await backendClient.conversations.fetchConversationSeenData(
          conversationID: conversationID
        )
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

    return try await backendClient.uploads.generateUploadURL(
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

    try await backendClient.uploads.upload(data: data, using: signedUpload)
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
