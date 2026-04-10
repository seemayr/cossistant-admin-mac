import Foundation

enum DashboardRealtimeConnectionState: Equatable {
  case disconnected
  case connecting
  case connected(connectionID: String?)
  case failed(String)

  var isConnected: Bool {
    if case .connected = self {
      return true
    }

    return false
  }
}

struct DashboardRealtimeConnectionEstablishedPayload: Decodable, Sendable {
  let connectionId: String?
  let userId: String?
  let visitorId: String?
  let organizationId: String?
  let websiteId: String?
  let timestamp: Int?
}

struct DashboardRealtimeConversationSeenPayload: Decodable, Sendable {
  let websiteId: String
  let organizationId: String
  let visitorId: String?
  let userId: String?
  let conversationId: String
  let aiAgentId: String?
  let lastSeenAt: String
  let actorType: String
  let actorId: String
}

struct DashboardRealtimeConversationTypingPayload: Decodable, Sendable {
  let websiteId: String
  let organizationId: String
  let visitorId: String?
  let userId: String?
  let conversationId: String
  let aiAgentId: String?
  let isTyping: Bool
  let visitorPreview: String?
}

struct DashboardRealtimeAIProcessingStartedPayload: Decodable, Sendable {
  let websiteId: String
  let organizationId: String
  let visitorId: String?
  let userId: String?
  let conversationId: String
  let aiAgentId: String
  let workflowRunId: String
  let triggerMessageId: String
  let phase: String?
  let audience: String?
}

struct DashboardRealtimeAIProcessingProgressPayload: Decodable, Sendable {
  struct Tool: Decodable, Sendable {
    let toolCallId: String
    let toolName: String
    let state: String
  }

  let websiteId: String
  let organizationId: String
  let visitorId: String?
  let userId: String?
  let conversationId: String
  let aiAgentId: String
  let workflowRunId: String
  let phase: String
  let message: String?
  let tool: Tool?
  let audience: String?
}

struct DashboardRealtimeAIProcessingCompletedPayload: Decodable, Sendable {
  let websiteId: String
  let organizationId: String
  let visitorId: String?
  let userId: String?
  let conversationId: String
  let aiAgentId: String
  let workflowRunId: String
  let status: String
  let action: String?
  let reason: String?
  let audience: String?
}

struct DashboardRealtimeAIProcessingState: Equatable, Sendable {
  let aiAgentId: String
  let phase: String
  let message: String?
  let toolName: String?
  let toolState: String?

  var phaseDisplayTitle: String {
    switch phase.lowercased() {
    case "thinking":
      return "Thinking"
    case "searching":
      return "Searching"
    case "generating":
      return "Generating"
    case "tool-executing":
      return "Using tools"
    default:
      return phase.replacingOccurrences(of: "-", with: " ").capitalized
    }
  }

  var statusText: String {
    if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return message
    }

    if let toolName, !toolName.isEmpty {
      return "Using \(DashboardTimelineItem.humanizeToolName(toolName))"
    }

    return phaseDisplayTitle
  }
}

struct DashboardRealtimeTimelineItemPayload: Decodable, Sendable {
  let websiteId: String
  let organizationId: String
  let visitorId: String?
  let userId: String?
  let conversationId: String
  let item: DashboardTimelineItem
}

struct DashboardRealtimeConversationCreatedPayload: Decodable, Sendable {
  let websiteId: String
  let organizationId: String
  let visitorId: String?
  let userId: String?
  let conversationId: String
}

struct DashboardRealtimeConversationUpdatedPayload: Decodable, Sendable {
  struct Updates: Decodable, Sendable {
    let title: String?
    let status: DashboardConversation.Status?
    let priority: DashboardConversation.Priority?
    let resolvedAt: String?
    let aiPausedUntil: String?
    let escalatedAt: String?
    let escalationHandledAt: String?
    let sentiment: String?
    let sentimentConfidence: Double?
    let activeClarification: DashboardConversation.Clarification?
  }

  let websiteId: String
  let organizationId: String
  let visitorId: String?
  let userId: String?
  let conversationId: String
  let updates: Updates
  let aiAgentId: String?
}

struct DashboardRealtimeVisitorIdentifiedPayload: Decodable, Sendable {
  let websiteId: String
  let organizationId: String
  let visitorId: String
  let userId: String?
  let visitor: DashboardVisitor
}

struct DashboardRealtimeVisitorConnectionPayload: Decodable, Sendable {
  let websiteId: String
  let organizationId: String
  let visitorId: String
  let userId: String?
  let connectionId: String
}

struct DashboardRealtimeVisitorPresencePayload: Decodable, Sendable {
  let websiteId: String
  let organizationId: String
  let visitorId: String
  let userId: String?
  let sessionId: String
  let activityType: String
}

enum DashboardRealtimeClientEvent: Sendable {
  case conversationTyping(
    conversationId: String,
    isTyping: Bool,
    visitorPreview: String?
  )
  case conversationSeen(conversationId: String)

  var type: String {
    switch self {
    case .conversationTyping:
      "conversationTyping"
    case .conversationSeen:
      "conversationSeen"
    }
  }

  func payload(
    websiteID: String,
    organizationID: String?
  ) -> [String: JSONValue] {
    var payload: [String: JSONValue] = [
      "websiteId": .string(websiteID),
      "organizationId": organizationID.map(JSONValue.string) ?? .null,
      "visitorId": .null,
      "userId": .null,
      "aiAgentId": .null,
    ]

    switch self {
    case .conversationTyping(let conversationId, let isTyping, let visitorPreview):
      payload["conversationId"] = .string(conversationId)
      payload["isTyping"] = .bool(isTyping)
      payload["visitorPreview"] = visitorPreview.map(JSONValue.string) ?? .null
    case .conversationSeen(let conversationId):
      payload["conversationId"] = .string(conversationId)
      payload["lastSeenAt"] = .string(ISO8601DateFormatter.internetDateTime.string(from: .now))
      payload["actorType"] = .string("user")
      payload["actorId"] = .string("api-key")
    }

    return payload
  }
}

enum DashboardRealtimeEvent: Sendable {
  case connectionEstablished(DashboardRealtimeConnectionEstablishedPayload)
  case conversationSeen(DashboardRealtimeConversationSeenPayload)
  case conversationTyping(DashboardRealtimeConversationTypingPayload)
  case aiAgentProcessingStarted(DashboardRealtimeAIProcessingStartedPayload)
  case aiAgentProcessingProgress(DashboardRealtimeAIProcessingProgressPayload)
  case aiAgentProcessingCompleted(DashboardRealtimeAIProcessingCompletedPayload)
  case timelineItemCreated(DashboardRealtimeTimelineItemPayload)
  case timelineItemUpdated(DashboardRealtimeTimelineItemPayload)
  case conversationCreated(DashboardRealtimeConversationCreatedPayload)
  case conversationUpdated(DashboardRealtimeConversationUpdatedPayload)
  case visitorIdentified(DashboardRealtimeVisitorIdentifiedPayload)
  case visitorConnected(DashboardRealtimeVisitorConnectionPayload)
  case visitorDisconnected(DashboardRealtimeVisitorConnectionPayload)
  case visitorPresenceUpdate(DashboardRealtimeVisitorPresencePayload)
  case serverError(message: String)
  case unsupported(type: String)

  init(data: Data, decoder: JSONDecoder = JSONDecoder()) throws {
    let envelope = try decoder.decode(DashboardRealtimeEnvelope.self, from: data)

    if let error = envelope.error {
      self = .serverError(message: envelope.message ?? error)
      return
    }

    guard let type = envelope.type else {
      self = .serverError(message: envelope.message ?? "Unknown realtime message.")
      return
    }

    switch type {
    case "CONNECTION_ESTABLISHED":
      self = .connectionEstablished(
        try envelope.decodePayload(
          as: DashboardRealtimeConnectionEstablishedPayload.self,
          decoder: decoder
        )
      )
    case "conversationSeen":
      self = .conversationSeen(
        try envelope.decodePayload(
          as: DashboardRealtimeConversationSeenPayload.self,
          decoder: decoder
        )
      )
    case "conversationTyping":
      self = .conversationTyping(
        try envelope.decodePayload(
          as: DashboardRealtimeConversationTypingPayload.self,
          decoder: decoder
        )
      )
    case "aiAgentProcessingStarted":
      self = .aiAgentProcessingStarted(
        try envelope.decodePayload(
          as: DashboardRealtimeAIProcessingStartedPayload.self,
          decoder: decoder
        )
      )
    case "aiAgentProcessingProgress":
      self = .aiAgentProcessingProgress(
        try envelope.decodePayload(
          as: DashboardRealtimeAIProcessingProgressPayload.self,
          decoder: decoder
        )
      )
    case "aiAgentProcessingCompleted":
      self = .aiAgentProcessingCompleted(
        try envelope.decodePayload(
          as: DashboardRealtimeAIProcessingCompletedPayload.self,
          decoder: decoder
        )
      )
    case "timelineItemCreated":
      self = .timelineItemCreated(
        try envelope.decodePayload(
          as: DashboardRealtimeTimelineItemPayload.self,
          decoder: decoder
        )
      )
    case "timelineItemUpdated":
      self = .timelineItemUpdated(
        try envelope.decodePayload(
          as: DashboardRealtimeTimelineItemPayload.self,
          decoder: decoder
        )
      )
    case "conversationCreated":
      self = .conversationCreated(
        try envelope.decodePayload(
          as: DashboardRealtimeConversationCreatedPayload.self,
          decoder: decoder
        )
      )
    case "conversationUpdated":
      self = .conversationUpdated(
        try envelope.decodePayload(
          as: DashboardRealtimeConversationUpdatedPayload.self,
          decoder: decoder
        )
      )
    case "visitorIdentified":
      self = .visitorIdentified(
        try envelope.decodePayload(
          as: DashboardRealtimeVisitorIdentifiedPayload.self,
          decoder: decoder
        )
      )
    case "visitorConnected":
      self = .visitorConnected(
        try envelope.decodePayload(
          as: DashboardRealtimeVisitorConnectionPayload.self,
          decoder: decoder
        )
      )
    case "visitorDisconnected":
      self = .visitorDisconnected(
        try envelope.decodePayload(
          as: DashboardRealtimeVisitorConnectionPayload.self,
          decoder: decoder
        )
      )
    case "visitorPresenceUpdate":
      self = .visitorPresenceUpdate(
        try envelope.decodePayload(
          as: DashboardRealtimeVisitorPresencePayload.self,
          decoder: decoder
        )
      )
    default:
      self = .unsupported(type: type)
    }
  }
}

private struct DashboardRealtimeEnvelope: Decodable {
  let type: String?
  let payload: JSONValue?
  let error: String?
  let message: String?

  func decodePayload<T: Decodable>(
    as type: T.Type,
    decoder: JSONDecoder
  ) throws -> T {
    let payloadData = try JSONEncoder().encode(payload ?? .object([:]))
    return try decoder.decode(T.self, from: payloadData)
  }
}
