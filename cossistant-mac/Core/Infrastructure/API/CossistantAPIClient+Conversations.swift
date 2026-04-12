import Foundation

extension CossistantAPIClient {
  func fetchInbox(limit: Int = 100, cursor: String?) async throws -> DashboardConversationPage {
    var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
    if let cursor {
      queryItems.append(URLQueryItem(name: "cursor", value: cursor))
    }

    let page: DashboardConversationPage = try await request(path: "conversations/inbox", queryItems: queryItems)

    if let trackedConversation = page.items.first(where: { DashboardReadDebug.isTargetConversation($0.id) }) {
      DashboardReadDebug.log(
        "API.fetchInbox",
        "cursor=\(cursor ?? "nil") limit=\(limit) targetFound=true \(DashboardReadDebug.conversationSummary(trackedConversation))"
      )
    } else {
      DashboardReadDebug.log(
        "API.fetchInbox",
        "cursor=\(cursor ?? "nil") limit=\(limit) targetFound=false itemCount=\(page.items.count)"
      )
    }

    return page
  }

  func fetchConversation(id: DashboardConversation.ID) async throws -> DashboardConversationDetail {
    let response: DashboardConversationResponse = try await request(path: "conversations/\(id)")
    if DashboardReadDebug.isTargetConversation(id) {
      DashboardReadDebug.log(
        "API.fetchConversation",
        "detail visitorLastSeenAt=\(response.conversation.visitorLastSeenAt ?? "nil") updatedAt=\(response.conversation.updatedAt) status=\(response.conversation.status.rawValue)"
      )
    }
    return response.conversation
  }

  func fetchTimeline(
    conversationID: DashboardConversation.ID,
    limit: Int = 50,
    cursor: String? = nil
  ) async throws -> DashboardTimelinePage {
    var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
    if let cursor {
      queryItems.append(URLQueryItem(name: "cursor", value: cursor))
    }

    return try await request(
      path: "conversations/\(conversationID)/timeline",
      queryItems: queryItems
    )
  }

  func fetchConversationSeenData(
    conversationID: DashboardConversation.ID
  ) async throws -> [DashboardConversationSeen] {
    let response: DashboardConversationSeenResponse = try await request(
      path: "conversations/\(conversationID)/seen"
    )
    if DashboardReadDebug.isTargetConversation(conversationID) {
      DashboardReadDebug.log(
        "API.fetchSeenData",
        DashboardReadDebug.seenDataSummary(response.seenData)
      )
    }
    return response.seenData
  }

  func markConversationRead(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    if DashboardReadDebug.isTargetConversation(conversationID) {
      DashboardReadDebug.log("API.markRead", "sending POST /conversations/\(conversationID)/read")
    }
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/read"
    )
    if DashboardReadDebug.isTargetConversation(conversationID) {
      DashboardReadDebug.log("API.markRead", "response \(DashboardReadDebug.mutationSummary(response.conversation))")
    }
    return response.conversation
  }

  func setConversationTyping(
    conversationID: DashboardConversation.ID,
    payload: DashboardConversationTypingRequest
  ) async throws -> DashboardConversationTypingResponse {
    try await request(
      method: "POST",
      path: "conversations/\(conversationID)/typing",
      body: payload
    )
  }

  func resolveConversation(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/resolve"
    )
    return response.conversation
  }

  func reopenConversation(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/reopen"
    )
    return response.conversation
  }

  func markConversationSpam(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/spam"
    )
    return response.conversation
  }

  func markConversationNotSpam(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/not-spam"
    )
    return response.conversation
  }

  func markConversationUnread(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    if DashboardReadDebug.isTargetConversation(conversationID) {
      DashboardReadDebug.log("API.markUnread", "sending POST /conversations/\(conversationID)/unread")
    }
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/unread"
    )
    if DashboardReadDebug.isTargetConversation(conversationID) {
      DashboardReadDebug.log("API.markUnread", "response \(DashboardReadDebug.mutationSummary(response.conversation))")
    }
    return response.conversation
  }

  func archiveConversation(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/archive"
    )
    return response.conversation
  }

  func unarchiveConversation(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/unarchive"
    )
    return response.conversation
  }

  func updateConversationTitle(
    conversationID: DashboardConversation.ID,
    title: String?
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "PATCH",
      path: "conversations/\(conversationID)",
      body: DashboardUpdateConversationTitleRequest(title: title)
    )
    return response.conversation
  }

  func updateConversationMetadata(
    conversationID: DashboardConversation.ID,
    metadata: DashboardMetadata
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "PATCH",
      path: "conversations/\(conversationID)/metadata",
      body: DashboardUpdateConversationMetadataRequest(metadata: metadata)
    )
    return response.conversation
  }

  func joinConversationEscalation(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/join-escalation"
    )
    return response.conversation
  }

  func pauseConversationAI(
    conversationID: DashboardConversation.ID,
    durationMinutes: Int
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/ai/pause",
      body: DashboardPauseConversationAIRequest(durationMinutes: durationMinutes)
    )
    return response.conversation
  }

  func resumeConversationAI(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/ai/resume"
    )
    return response.conversation
  }

  func sendTimelineItem(
    _ payload: DashboardSendTimelineItemRequest
  ) async throws -> DashboardTimelineItem {
    let response: DashboardSendTimelineItemResponse = try await request(
      method: "POST",
      path: "messages",
      body: payload
    )
    return response.item
  }
}
