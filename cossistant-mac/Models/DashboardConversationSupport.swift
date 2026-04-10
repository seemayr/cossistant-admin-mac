import Foundation

struct EmptyResponse: Decodable, Sendable {}

struct DashboardConversationSeenResponse: Decodable, Sendable {
  let seenData: [DashboardConversationSeen]
}

struct DashboardConversationSeen: Identifiable, Decodable, Hashable, Sendable {
  let id: String
  let conversationId: String
  let userId: String?
  let visitorId: String?
  let aiAgentId: String?
  let lastSeenAt: String
  let createdAt: String
  let updatedAt: String
  let deletedAt: String?

  var actorLabel: String {
    if userId != nil {
      return "Human agent"
    }

    if aiAgentId != nil {
      return "AI agent"
    }

    if visitorId != nil {
      return "Visitor"
    }

    return "Unknown actor"
  }

  var lastSeenDate: Date? {
    DashboardTimestampParser.date(from: lastSeenAt)
  }
}

struct DashboardMarkConversationSeenRequest: Encodable, Sendable {
  var visitorId: String?
}

struct DashboardMarkConversationSeenResponse: Decodable, Sendable {
  let conversationId: String
  let lastSeenAt: String
}

struct DashboardConversationTypingRequest: Encodable, Sendable {
  let isTyping: Bool
  var visitorPreview: String?
  var visitorId: String?
}

struct DashboardConversationTypingResponse: Decodable, Sendable {
  let conversationId: String
  let isTyping: Bool
  let visitorPreview: String?
  let sentAt: String
}

struct DashboardTimelineItemDraft: Encodable, Sendable {
  var id: String?
  var type: String = "message"
  var text: String
  var parts: [JSONValue]?
  var visibility: String = "public"
  var tool: String?
  var userId: String?
  var aiAgentId: String?
  var visitorId: String?
  var createdAt: String?

  static func message(
    _ text: String,
    visibility: String = "public",
    userID: String? = nil,
    aiAgentID: String? = nil,
    visitorID: String? = nil,
    parts: [JSONValue]? = nil
  ) -> DashboardTimelineItemDraft {
    DashboardTimelineItemDraft(
      text: text,
      parts: parts,
      visibility: visibility,
      userId: userID,
      aiAgentId: aiAgentID,
      visitorId: visitorID
    )
  }
}

struct DashboardSendTimelineItemRequest: Encodable, Sendable {
  let conversationId: String
  let item: DashboardTimelineItemDraft
}

struct DashboardSendTimelineItemResponse: Decodable, Sendable {
  let item: DashboardTimelineItem
}

struct DashboardConversationMutation: Decodable, Sendable {
  let id: String
  let organizationId: String
  let visitorId: String
  let websiteId: String
  let metadata: DashboardMetadata?
  let status: DashboardConversation.Status
  let priority: DashboardConversation.Priority
  let sentiment: String?
  let sentimentConfidence: Double?
  let channel: String
  let title: String?
  let visitorRating: Int?
  let resolvedAt: String?
  let resolvedByUserId: String?
  let resolvedByAiAgentId: String?
  let escalatedAt: String?
  let escalationHandledAt: String?
  let aiPausedUntil: String?
  let createdAt: String
  let updatedAt: String
  let deletedAt: String?
  let lastMessageAt: String?
}

struct DashboardConversationMutationResponse: Decodable, Sendable {
  let conversation: DashboardConversationMutation
}

struct DashboardPauseConversationAIRequest: Encodable, Sendable {
  let durationMinutes: Int
}

struct DashboardUpdateConversationTitleRequest: Encodable, Sendable {
  let title: String?
}
