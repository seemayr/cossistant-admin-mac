import Foundation

@MainActor
final class AutoResolveCoordinator {
  private let store: AutoResolveStore
  private let configuration: DashboardConfiguration
  private let canUseOpenAI: Bool
  private let openAIAPIKey: String
  private let workspaceName: String?
  private let candidateConversations: (InboxScope) -> [DashboardConversation]
  private let eligibleScope: (InboxScope) -> Bool
  private let fetchAIMessageItems: (
    _ conversationID: String,
    _ client: CossistantAPIClient,
    _ maxPages: Int
  ) async throws -> [DashboardTimelineItem]
  private let applyMutatedConversation: (DashboardConversationMutation) -> Void
  private let refreshSelectedConversationIfNeeded: (DashboardConversation.ID) async -> Void
  private let setGlobalErrorMessage: (any Error) -> Void
  private let isIgnorableCancellation: (any Error) -> Bool

  init(
    store: AutoResolveStore,
    configuration: DashboardConfiguration,
    canUseOpenAI: Bool,
    openAIAPIKey: String,
    workspaceName: String?,
    candidateConversations: @escaping (InboxScope) -> [DashboardConversation],
    eligibleScope: @escaping (InboxScope) -> Bool,
    fetchAIMessageItems: @escaping (
      _ conversationID: String,
      _ client: CossistantAPIClient,
      _ maxPages: Int
    ) async throws -> [DashboardTimelineItem],
    applyMutatedConversation: @escaping (DashboardConversationMutation) -> Void,
    refreshSelectedConversationIfNeeded: @escaping (DashboardConversation.ID) async -> Void,
    setGlobalErrorMessage: @escaping (any Error) -> Void,
    isIgnorableCancellation: @escaping (any Error) -> Bool
  ) {
    self.store = store
    self.configuration = configuration
    self.canUseOpenAI = canUseOpenAI
    self.openAIAPIKey = openAIAPIKey
    self.workspaceName = workspaceName
    self.candidateConversations = candidateConversations
    self.eligibleScope = eligibleScope
    self.fetchAIMessageItems = fetchAIMessageItems
    self.applyMutatedConversation = applyMutatedConversation
    self.refreshSelectedConversationIfNeeded = refreshSelectedConversationIfNeeded
    self.setGlobalErrorMessage = setGlobalErrorMessage
    self.isIgnorableCancellation = isIgnorableCancellation
  }

  func start() {
    let scope = store.sourceScope.inboxScope
    guard eligibleScope(scope) else { return }
    guard store.task == nil else { return }
    guard canUseOpenAI else {
      store.statusMessage = "Add an OpenAI API key in settings to use AI auto-resolve."
      return
    }

    let candidates = candidateConversations(scope)
    guard !candidates.isEmpty else {
      store.statusMessage = "No open conversations match the selected source queue."
      return
    }

    store.results = []
    store.inspectedConversationID = nil
    log("Starting auto-resolve for \(candidates.count) conversations in \(scope.rawValue) queue")
    store.task = Task {
      await self.run(in: scope)
      if !Task.isCancelled {
        self.store.task = nil
      }
    }
  }

  func cancel() {
    store.task?.cancel()
    store.task = nil
    store.isRunning = false
    if store.statusMessage != nil {
      store.statusMessage = "AI auto-resolve cancelled."
    }
  }

  func clearResults() {
    store.results = []
    store.inspectedConversationID = nil
    store.statusMessage = nil
  }

  func run(in scope: InboxScope) async {
    guard eligibleScope(scope) else { return }
    guard canUseOpenAI else {
      store.statusMessage = "Add an OpenAI API key in settings to use AI auto-resolve."
      store.task = nil
      return
    }

    let candidates = candidateConversations(scope)
    guard !candidates.isEmpty else {
      store.statusMessage = "No open conversations match the selected source queue."
      store.task = nil
      return
    }

    store.isRunning = true
    store.statusMessage = "Preparing \(candidates.count) conversations for AI auto-resolve…"
    defer { store.isRunning = false }

    let apiClient = CossistantAPIClient(configuration: configuration)
    let aiClient = OpenAIConversationResolutionClient(apiKey: openAIAPIKey)
    var resolvedWithoutAI = 0
    var resolvedWithAI = 0
    var leftOpen = 0
    var failed = 0
    var metadataUpdated = 0
    var metadataUpdateFailed = 0

    do {
      for (index, conversation) in candidates.enumerated() {
        try Task.checkCancellation()

        store.statusMessage = "Reviewing \(index + 1) of \(candidates.count)…"
        log("Reviewing conversation \(conversation.id) (\(index + 1)/\(candidates.count))")

        if !conversation.hasContent {
          let updatedConversation = try await apiClient.resolveConversation(conversationID: conversation.id)
          applyMutatedConversation(updatedConversation)
          await refreshSelectedConversationIfNeeded(conversation.id)
          resolvedWithoutAI += 1
          store.results.append(
            AutoResolveResult(
              conversationID: conversation.id,
              visitorID: conversation.visitorId,
              outcome: .emptyResolved,
              category: .unknown,
              title: "Empty conversation",
              body: "No message activity was found, so the conversation was resolved automatically."
            )
          )
          continue
        }

        let items: [DashboardTimelineItem]
        do {
          items = try await fetchAIMessageItems(
            conversation.id,
            apiClient,
            20
          )
          log("Fetched \(items.count) timeline messages for conversation \(conversation.id)")
        } catch {
          if isIgnorableCancellation(error) {
            throw error
          }

          failed += 1
          recordFailure(
            title: "Timeline fetch failed",
            conversation: conversation,
            error: error
          )
          continue
        }

        guard let transcript = buildConversationReviewDocument(
          for: conversation,
          items: items
        ) else {
          let updatedConversation = try await apiClient.resolveConversation(conversationID: conversation.id)
          applyMutatedConversation(updatedConversation)
          await refreshSelectedConversationIfNeeded(conversation.id)
          resolvedWithoutAI += 1
          store.results.append(
            AutoResolveResult(
              conversationID: conversation.id,
              visitorID: conversation.visitorId,
              outcome: .emptyResolved,
              category: .unknown,
              title: "Empty conversation",
              body: "No visible message content was found, so the conversation was resolved automatically."
            )
          )
          log("Resolved conversation \(conversation.id) without AI because no visible message content was found")
          continue
        }

        do {
          let verdict = try await aiClient.reviewConversation(
            transcript: transcript,
            websiteName: workspaceName,
            conversationID: conversation.id
          )
          let didPersistCategory = await persistCategory(
            verdict.category,
            for: conversation.id,
            client: apiClient
          )
          if didPersistCategory {
            metadataUpdated += 1
          } else {
            metadataUpdateFailed += 1
          }
          let shouldResolve = verdict.isResolved
            && !conversation.needsHumanIntervention

          if shouldResolve {
            let updatedConversation = try await apiClient.resolveConversation(conversationID: conversation.id)
            applyMutatedConversation(updatedConversation)
            await refreshSelectedConversationIfNeeded(conversation.id)
            resolvedWithAI += 1
            store.results.append(
              AutoResolveResult(
                conversationID: conversation.id,
                visitorID: conversation.visitorId,
                outcome: .resolved,
                aiMarkedResolved: verdict.isResolved,
                category: verdict.category,
                title: verdict.title,
                body: verdict.body,
                rawAIResponseText: verdict.rawResponseText
              )
            )
          } else {
            leftOpen += 1
            store.results.append(
              AutoResolveResult(
                conversationID: conversation.id,
                visitorID: conversation.visitorId,
                outcome: .notResolved,
                aiMarkedResolved: verdict.isResolved,
                category: verdict.category,
                title: verdict.title,
                body: verdict.body,
                decisionNote: decisionNote(
                  for: conversation,
                  aiMarkedResolved: verdict.isResolved
                ),
                rawAIResponseText: verdict.rawResponseText
              )
            )
          }
        } catch {
          if isIgnorableCancellation(error) {
            throw error
          }

          failed += 1
          recordFailure(
            title: "AI review failed",
            conversation: conversation,
            error: error
          )
        }
      }

      let resolvedTotal = resolvedWithoutAI + resolvedWithAI
      store.statusMessage = "Auto-resolved \(resolvedTotal) conversations (\(resolvedWithoutAI) empty, \(resolvedWithAI) via AI), left \(leftOpen) open, failed \(failed), updated category metadata on \(metadataUpdated) conversations" + (metadataUpdateFailed > 0 ? " (\(metadataUpdateFailed) metadata updates failed)." : ".")
      store.task = nil
    } catch {
      if isIgnorableCancellation(error) {
        store.statusMessage = "AI auto-resolve cancelled."
        store.task = nil
        return
      }
      store.statusMessage = "AI auto-resolve stopped after an error."
      store.task = nil
      setGlobalErrorMessage(error)
    }
  }

  private func recordFailure(
    title: String,
    conversation: DashboardConversation,
    error: any Error
  ) {
    log("\(title) for conversation \(conversation.id) visitor \(conversation.visitorId): \(logMessage(for: error))")

    store.results.append(
      AutoResolveResult(
        conversationID: conversation.id,
        visitorID: conversation.visitorId,
        outcome: .notResolved,
        category: .unknown,
        title: title,
        body: displayMessage(for: error)
      )
    )
  }

  private func decisionNote(
    for conversation: DashboardConversation,
    aiMarkedResolved: Bool
  ) -> String? {
    guard aiMarkedResolved else { return nil }

    var reasons: [String] = []
    if conversation.needsHumanIntervention {
      reasons.append("needsHumanIntervention")
    }
    if conversation.needsClarification {
      reasons.append("needsClarification")
    }
    guard !reasons.isEmpty else { return nil }

    return "AI marked this resolved, but the conversation stayed open because \(reasons.joined(separator: " and ")) is still set."
  }

  private func buildConversationReviewDocument(
    for conversation: DashboardConversation,
    items: [DashboardTimelineItem]
  ) -> String? {
    var lines = [
      "# Conversation Resolution Review",
      "",
      "- Status: \(conversation.status.label)",
      "- Priority: \(conversation.priority.label)",
      "- Needs human intervention: \(conversation.needsHumanIntervention ? "Yes" : "No")",
      "- Needs clarification: \(conversation.needsClarification ? "Yes" : "No")",
      "",
      "## Messages",
    ]
    var messageCount = 0

    for item in items {
      let text = item.renderedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let attachmentSummary = AIWorkflowFormatting.markdownAttachmentSummary(for: item)
      guard !text.isEmpty || attachmentSummary != nil else {
        continue
      }

      let visibilitySuffix = item.visibility == .private ? " [private]" : ""
      lines.append("- \(AIWorkflowFormatting.senderLabel(for: item))\(visibilitySuffix):")

      if !text.isEmpty {
        lines.append(AIWorkflowFormatting.indentedMarkdownText(text, indentation: "  "))
      }

      if let attachmentSummary {
        lines.append("  _\(attachmentSummary)_")
      }

      messageCount += 1
    }

    guard messageCount > 0 else { return nil }
    return lines.joined(separator: "\n")
  }

  private func persistCategory(
    _ category: AutoResolveConversationCategory,
    for conversationID: DashboardConversation.ID,
    client: CossistantAPIClient
  ) async -> Bool {
    let autoResolveTimestamp = ISO8601DateFormatter.internetDateTime.string(from: .now)

    do {
      let updatedConversation = try await client.updateConversationMetadata(
        conversationID: conversationID,
        metadata: [
          InboxMetadataFilterKey.category.rawValue: .string(category.rawValue),
          AutoResolveMetadataKey.lastAutoResolve: .string(autoResolveTimestamp),
        ]
      )
      applyMutatedConversation(updatedConversation)
      await refreshSelectedConversationIfNeeded(conversationID)
      return true
    } catch {
      log("Failed to persist auto-resolve category for conversation \(conversationID): \(logMessage(for: error))")
      return false
    }
  }

  private func displayMessage(for error: any Error) -> String {
    let message = (error as NSError).localizedDescription
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return message.isEmpty ? "An unknown error occurred." : message
  }

  private func logMessage(for error: any Error) -> String {
    let nsError = error as NSError
    let description = displayMessage(for: error)
    return "type=\(String(describing: type(of: error))) domain=\(nsError.domain) code=\(nsError.code) message=\(description)"
  }

  private func log(_ message: String) {
    print("[AutoResolve]", message)
  }
}
