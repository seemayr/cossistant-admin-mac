import Foundation
import CossistantAdmin

@MainActor
final class AutoResolveCoordinator {
  private let store: AutoResolveStore
  private let backendClient: CossistantAdminClient
  private let canUseOpenAI: Bool
  private let openAIAPIKey: String
  private let workspaceName: String?
  private let candidateConversations: (InboxScope) -> [DashboardConversation]
  private let eligibleScope: (InboxScope) -> Bool
  private let fetchAIMessageItems: (
    _ conversationID: String,
    _ client: CossistantAdminClient,
    _ maxPages: Int
  ) async throws -> [DashboardTimelineItem]
  private let applyMutatedConversation: (DashboardConversationMutation) -> Void
  private let refreshSelectedConversationIfNeeded: (DashboardConversation.ID) async -> Void
  private let setGlobalErrorMessage: (any Error) -> Void
  private let isIgnorableCancellation: (any Error) -> Bool

  init(
    store: AutoResolveStore,
    backendClient: CossistantAdminClient,
    canUseOpenAI: Bool,
    openAIAPIKey: String,
    workspaceName: String?,
    candidateConversations: @escaping (InboxScope) -> [DashboardConversation],
    eligibleScope: @escaping (InboxScope) -> Bool,
    fetchAIMessageItems: @escaping (
      _ conversationID: String,
      _ client: CossistantAdminClient,
      _ maxPages: Int
    ) async throws -> [DashboardTimelineItem],
    applyMutatedConversation: @escaping (DashboardConversationMutation) -> Void,
    refreshSelectedConversationIfNeeded: @escaping (DashboardConversation.ID) async -> Void,
    setGlobalErrorMessage: @escaping (any Error) -> Void,
    isIgnorableCancellation: @escaping (any Error) -> Bool
  ) {
    self.store = store
    self.backendClient = backendClient
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

    store.resetResults()
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
    store.resetResults()
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

    store.resetResults()
    store.isRunning = true
    store.statusMessage = "Preparing \(candidates.count) conversations for AI auto-resolve…"
    defer { store.isRunning = false }

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
          let updatedConversation = try await backendClient.conversations.resolveConversation(
            conversationID: conversation.id
          )
          applyMutatedConversation(updatedConversation)
          await refreshSelectedConversationIfNeeded(conversation.id)
          resolvedWithoutAI += 1
          store.closedEmptyConversationCount = resolvedWithoutAI
          continue
        }

        let items: [DashboardTimelineItem]
        do {
          items = try await fetchAIMessageItems(
            conversation.id,
            backendClient,
            20
          )
          log("Fetched \(items.count) timeline messages for conversation \(conversation.id)")
        } catch {
          if isIgnorableCancellation(error) {
            throw error
          }

          failed += 1
          store.keptOpenNonEmptyConversationCount = leftOpen + failed
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
          let updatedConversation = try await backendClient.conversations.resolveConversation(
            conversationID: conversation.id
          )
          applyMutatedConversation(updatedConversation)
          await refreshSelectedConversationIfNeeded(conversation.id)
          resolvedWithoutAI += 1
          store.closedEmptyConversationCount = resolvedWithoutAI
          log("Resolved conversation \(conversation.id) without AI because no visible message content was found")
          continue
        }

        do {
          let verdict = try await aiClient.reviewConversation(
            transcript: transcript,
            websiteName: workspaceName,
            conversationID: conversation.id
          )
          let didPersistMetadata = await persistAutoResolveMetadata(
            category: verdict.category,
            summary: verdict.summary,
            for: conversation
          )
          if didPersistMetadata {
            metadataUpdated += 1
          } else {
            metadataUpdateFailed += 1
          }
          let shouldResolve = verdict.isResolved
            && !conversation.needsHumanIntervention

          if shouldResolve {
            let updatedConversation = try await backendClient.conversations.resolveConversation(
              conversationID: conversation.id
            )
            applyMutatedConversation(updatedConversation)
            await refreshSelectedConversationIfNeeded(conversation.id)
            resolvedWithAI += 1
            store.autoResolvedNonEmptyConversationCount = resolvedWithAI
            store.results.append(
              AutoResolveResult(
                conversationID: conversation.id,
                visitorID: conversation.visitorId,
                outcome: .resolved,
                aiMarkedResolved: verdict.isResolved,
                category: verdict.category,
                title: verdict.title,
                summary: verdict.summary,
                body: verdict.body,
                rawAIResponseText: verdict.rawResponseText,
                isSeen: !conversation.hasUnreadActivity
              )
            )
          } else {
            leftOpen += 1
            store.keptOpenNonEmptyConversationCount = leftOpen + failed
            store.results.append(
              AutoResolveResult(
                conversationID: conversation.id,
                visitorID: conversation.visitorId,
                outcome: .notResolved,
                aiMarkedResolved: verdict.isResolved,
                category: verdict.category,
                title: verdict.title,
                summary: verdict.summary,
                body: verdict.body,
                decisionNote: decisionNote(
                  for: conversation,
                  aiMarkedResolved: verdict.isResolved
                ),
                rawAIResponseText: verdict.rawResponseText,
                isSeen: !conversation.hasUnreadActivity
              )
            )
          }
        } catch {
          if isIgnorableCancellation(error) {
            throw error
          }

          failed += 1
          store.keptOpenNonEmptyConversationCount = leftOpen + failed
          recordFailure(
            title: "AI review failed",
            conversation: conversation,
            error: error
          )
        }
      }

      let resolvedTotal = resolvedWithoutAI + resolvedWithAI
      store.statusMessage = "Auto-resolved \(resolvedTotal) conversations (\(resolvedWithoutAI) empty, \(resolvedWithAI) via AI), left \(leftOpen) open, failed \(failed), updated summary/category metadata on \(metadataUpdated) conversations" + (metadataUpdateFailed > 0 ? " (\(metadataUpdateFailed) metadata updates failed)." : ".")
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
        body: displayMessage(for: error),
        isSeen: !conversation.hasUnreadActivity
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

  private func persistAutoResolveMetadata(
    category: AutoResolveConversationCategory,
    summary: String,
    for conversation: DashboardConversation
  ) async -> Bool {
    let autoResolveTimestamp = ISO8601DateFormatter.internetDateTime.string(from: .now)
    var metadata = conversation.metadata ?? [:]
    metadata[InboxMetadataFilterKey.category.rawValue] = .string(category.rawValue)
    if let normalizedSummary = summary.nilIfEmpty {
      metadata[AutoResolveMetadataKey.summary] = .string(normalizedSummary)
    } else {
      metadata.removeValue(forKey: AutoResolveMetadataKey.summary)
    }
    metadata[AutoResolveMetadataKey.lastAutoResolve] = .string(autoResolveTimestamp)

    do {
      let updatedConversation = try await backendClient.conversations.updateConversationMetadata(
        conversationID: conversation.id,
        metadata: metadata
      )
      applyMutatedConversation(updatedConversation)
      await refreshSelectedConversationIfNeeded(conversation.id)
      return true
    } catch {
      log("Failed to persist auto-resolve metadata for conversation \(conversation.id): \(logMessage(for: error))")
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
