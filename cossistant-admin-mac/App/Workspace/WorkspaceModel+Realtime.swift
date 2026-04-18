import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  func applyMutatedConversation(
    _ updatedConversation: DashboardConversationMutation,
    preserveExistingLastMessageAt: Bool = false,
    preserveExistingLastSeenAt: Bool = false
  ) {
    if DashboardReadDebug.isTargetConversation(updatedConversation.id) {
      DashboardReadDebug.log(
        "WorkspaceModel.applyMutatedConversation",
        "incoming \(DashboardReadDebug.mutationSummary(updatedConversation))"
      )
    }

    guard inboxStore.conversation(withID: updatedConversation.id) != nil else {
      return
    }
    let removedSelectedConversation = inboxStore.applyMutatedConversation(
      updatedConversation,
      preserveExistingLastMessageAt: preserveExistingLastMessageAt,
      preserveExistingLastSeenAt: preserveExistingLastSeenAt
    )

    if removedSelectedConversation && selectedConversationID == updatedConversation.id {
      selectedConversationID = nil
      clearSelectedConversationState()
      return
    }

    if DashboardReadDebug.isTargetConversation(updatedConversation.id) {
      DashboardReadDebug.log(
        "WorkspaceModel.applyMutatedConversation",
        "stored \(DashboardReadDebug.conversationSummary(inboxStore.conversation(withID: updatedConversation.id)!))"
      )
    }
  }

  func setConversationLastSeenAt(
    conversationID: String,
    lastSeenAt: String?
  ) {
    inboxStore.setConversationLastSeenAt(
      conversationID: conversationID,
      lastSeenAt: lastSeenAt
    )

    if DashboardReadDebug.isTargetConversation(conversationID),
       let conversation = inboxStore.conversation(withID: conversationID) {
      DashboardReadDebug.log(
        "WorkspaceModel.updateConversationLastSeenAt",
        "lastSeenAt=\(lastSeenAt ?? "nil") stored=\(DashboardReadDebug.conversationSummary(conversation))"
      )
    }
  }

  func syncConversationSeenState(
    conversationID: String,
    with seenData: [DashboardConversationSeen],
    fallbackCurrentActorSeenAt: String?
  ) {
    setConversationLastSeenAt(
      conversationID: conversationID,
      lastSeenAt: currentActorLastSeenAt(in: seenData) ?? fallbackCurrentActorSeenAt
    )
  }

  func handleRealtimeEvent(_ event: DashboardRealtimeEvent) {
    lastRealtimeEventDate = .now

    switch event {
    case .connectionEstablished(let payload):
      if let userId = payload.userId {
        currentActorUserID = userId
      }
      realtimeConnectionState = .connected(connectionID: payload.connectionId)
    case .conversationSeen(let payload):
      applyRealtimeSeen(payload)
    case .conversationTyping(let payload):
      conversationStore.updateTypingEvent(payload)
    case .aiAgentProcessingStarted(let payload):
      conversationStore.updateAIProcessingState(
        conversationID: payload.conversationId,
        state: DashboardRealtimeAIProcessingState(
          aiAgentId: payload.aiAgentId,
          phase: payload.phase ?? "thinking",
          message: nil,
          toolName: nil,
          toolState: nil
        )
      )
    case .aiAgentProcessingProgress(let payload):
      conversationStore.updateAIProcessingState(
        conversationID: payload.conversationId,
        state: DashboardRealtimeAIProcessingState(
          aiAgentId: payload.aiAgentId,
          phase: payload.phase,
          message: payload.message,
          toolName: payload.tool?.toolName,
          toolState: payload.tool?.state
        )
      )
    case .aiAgentProcessingCompleted(let payload):
      conversationStore.clearAIProcessingState(for: payload.conversationId)
    case .timelineItemCreated(let payload):
      conversationStore.clearTypingEvent(for: payload.conversationId)
      if payload.item.type == .message, payload.item.aiAgentId != nil {
        conversationStore.clearAIProcessingState(for: payload.conversationId)
      }
      applyRealtimeTimelineItem(payload.item, conversationID: payload.conversationId)
      scheduleInboxRefresh()
      if payload.conversationId == selectedConversationID {
        runtimeCoordinator.scheduleSelectedConversationRefresh { [weak self] in
          await self?.loadSelectedConversation(force: true, showsLoadingState: false)
        }
      }
    case .timelineItemUpdated(let payload):
      applyRealtimeTimelineItem(payload.item, conversationID: payload.conversationId)
      if payload.conversationId == selectedConversationID {
        runtimeCoordinator.scheduleSelectedConversationRefresh { [weak self] in
          await self?.loadSelectedConversation(force: true, showsLoadingState: false)
        }
      }
    case .conversationCreated:
      scheduleInboxRefresh()
    case .conversationUpdated(let payload):
      applyRealtimeConversationUpdate(payload)
      scheduleInboxRefresh()
      if payload.conversationId == selectedConversationID {
        runtimeCoordinator.scheduleSelectedConversationRefresh { [weak self] in
          await self?.loadSelectedConversation(force: true, showsLoadingState: false)
        }
      }
    case .visitorIdentified(let payload):
      if payload.visitorId == selectedConversation?.visitorId {
        conversationStore.updateSelectedVisitor(payload.visitor)
      }
      scheduleInboxRefresh()
    case .visitorConnected(let payload):
      applyVisitorPresence(
        DashboardVisitorPresence(
          visitorId: payload.visitorId,
          state: .active,
          lastSeenAt: ISO8601DateFormatter.internetDateTime.string(from: .now)
        )
      )
    case .visitorDisconnected(let payload):
      applyVisitorPresence(
        DashboardVisitorPresence(
          visitorId: payload.visitorId,
          state: .inactive,
          lastSeenAt: ISO8601DateFormatter.internetDateTime.string(from: .now)
        )
      )
    case .visitorPresenceUpdate(let payload):
      applyVisitorPresence(
        DashboardVisitorPresence(
          visitorId: payload.visitorId,
          state: .active,
          lastSeenAt: ISO8601DateFormatter.internetDateTime.string(from: .now)
        )
      )
    case .serverError(let message):
      errorMessage = message
    case .unsupported:
      break
    }
  }

  private func applyRealtimeTimelineItem(
    _ item: DashboardTimelineItem,
    conversationID: String
  ) {
    conversationStore.applyRealtimeTimelineItem(
      item,
      conversationID: conversationID,
      selectedConversationID: selectedConversationID
    )
  }

  private func applyRealtimeSeen(_ payload: DashboardRealtimeConversationSeenPayload) {
    if DashboardReadDebug.isTargetConversation(payload.conversationId) {
      DashboardReadDebug.log(
        "WorkspaceModel.applyRealtimeSeen",
        "payload actorType=\(payload.actorType) actorId=\(payload.actorId) userId=\(payload.userId ?? "nil") visitorId=\(payload.visitorId ?? "nil") aiAgentId=\(payload.aiAgentId ?? "nil") lastSeenAt=\(payload.lastSeenAt) selectedConversationID=\(selectedConversationID ?? "nil")"
      )
    }

    if payload.actorType == "user", let userId = payload.userId {
      if currentActorUserID == nil {
        currentActorUserID = userId
      }

      if userId == currentActorUserID {
        setConversationLastSeenAt(
          conversationID: payload.conversationId,
          lastSeenAt: payload.lastSeenAt
        )
      }
    }

    guard payload.conversationId == selectedConversationID else { return }

    let item = DashboardConversationSeen(
      id: "\(payload.conversationId):\(payload.actorType):\(payload.actorId)",
      conversationId: payload.conversationId,
      userId: payload.userId,
      visitorId: payload.visitorId,
      aiAgentId: payload.aiAgentId,
      lastSeenAt: payload.lastSeenAt,
      createdAt: payload.lastSeenAt,
      updatedAt: payload.lastSeenAt,
      deletedAt: nil
    )

    guard conversationStore.upsertSeenItem(item, selectedConversationID: selectedConversationID) else {
      return
    }

    if DashboardReadDebug.isTargetConversation(payload.conversationId) {
      DashboardReadDebug.log(
        "WorkspaceModel.applyRealtimeSeen",
        "selectedSeenData=\(DashboardReadDebug.seenDataSummary(selectedSeenData))"
      )
    }

    syncConversationSeenState(
      conversationID: payload.conversationId,
      with: selectedSeenData,
      fallbackCurrentActorSeenAt: nil
    )
  }

  private func applyRealtimeConversationUpdate(
    _ payload: DashboardRealtimeConversationUpdatedPayload
  ) {
    if DashboardReadDebug.isTargetConversation(payload.conversationId) {
      DashboardReadDebug.log(
        "WorkspaceModel.applyRealtimeConversationUpdate",
        "status=\(payload.updates.status?.rawValue ?? "nil") priority=\(payload.updates.priority?.rawValue ?? "nil") title=\(payload.updates.title ?? "nil") escalatedAt=\(payload.updates.escalatedAt ?? "nil") escalationHandledAt=\(payload.updates.escalationHandledAt ?? "nil") aiPausedUntil=\(payload.updates.aiPausedUntil ?? "nil")"
      )
    }

    guard inboxStore.conversation(withID: payload.conversationId) != nil else {
      return
    }
    inboxStore.applyRealtimeConversationUpdate(payload)

    if DashboardReadDebug.isTargetConversation(payload.conversationId) {
      DashboardReadDebug.log(
        "WorkspaceModel.applyRealtimeConversationUpdate",
        "after \(DashboardReadDebug.conversationSummary(inboxStore.conversation(withID: payload.conversationId)!))"
      )
    }
  }

  private func applyVisitorPresence(_ presence: DashboardVisitorPresence) {
    visitorPresenceByID[presence.visitorId] = presence
  }

  private func currentActorLastSeenAt(in seenData: [DashboardConversationSeen]) -> String? {
    guard let currentActorUserID else { return nil }

    return seenData
      .filter { $0.userId == currentActorUserID }
      .max { left, right in
        (left.lastSeenDate ?? .distantPast) < (right.lastSeenDate ?? .distantPast)
      }?
      .lastSeenAt
  }
}
