import Foundation
import CossistantAdmin

@MainActor
final class AnalyticsCoordinator {
  private let store: AnalyticsStore
  private let backendClient: CossistantAdminClient
  private let canUseOpenAI: Bool
  private let openAIAPIKey: String
  private let workspaceName: String?
  private let inboxPageSize: Int
  private let fetchAIMessageItems: (
    _ conversationID: String,
    _ client: CossistantAdminClient,
    _ maxPages: Int
  ) async throws -> [DashboardTimelineItem]
  private let isIgnorableCancellation: (any Error) -> Bool

  init(
    store: AnalyticsStore,
    backendClient: CossistantAdminClient,
    canUseOpenAI: Bool,
    openAIAPIKey: String,
    workspaceName: String?,
    inboxPageSize: Int,
    fetchAIMessageItems: @escaping (
      _ conversationID: String,
      _ client: CossistantAdminClient,
      _ maxPages: Int
    ) async throws -> [DashboardTimelineItem],
    isIgnorableCancellation: @escaping (any Error) -> Bool
  ) {
    self.store = store
    self.backendClient = backendClient
    self.canUseOpenAI = canUseOpenAI
    self.openAIAPIKey = openAIAPIKey
    self.workspaceName = workspaceName
    self.inboxPageSize = inboxPageSize
    self.fetchAIMessageItems = fetchAIMessageItems
    self.isIgnorableCancellation = isIgnorableCancellation
  }

  func generateSummary() async {
    guard !store.isGeneratingSummary else { return }
    guard canUseOpenAI else {
      store.summaryErrorMessage = "Add an OpenAI API key in settings to summarize recent conversations."
      return
    }
    guard let dateRange = store.selectedDateRange else {
      store.summaryErrorMessage = "Select a valid analytics time range."
      return
    }

    store.isGeneratingSummary = true
    store.summaryErrorMessage = nil
    store.summaryStatusMessage = "Loading conversations…"
    store.summaryMessages = []
    store.followUpDraft = ""
    store.conversationCount = 0
    store.sourceMessageCount = 0
    store.sourceDocument = nil
    store.summaryResponseID = nil
    store.summaryGeneratedAt = nil
    store.summaryRangeLabel = dateRange.label
    store.summaryUsedChunking = false
    defer { store.isGeneratingSummary = false }

    do {
      let corpus = try await buildConversationCorpus(in: dateRange)
      store.conversationCount = corpus.conversationCount
      store.sourceMessageCount = corpus.messageCount
      store.sourceDocument = corpus.document
      store.summaryRangeLabel = dateRange.label

      let client = OpenAIAnalyticsSummaryClient(apiKey: openAIAPIKey)
      let turn: OpenAIAnalyticsTurn

      if corpus.chunks.count == 1, let chunk = corpus.chunks.first {
        store.summaryStatusMessage = "Generating summary with OpenAI…"
        turn = try await client.startSummaryConversation(
          sourceDocument: chunk,
          workspaceName: workspaceName,
          rangeDescription: dateRange.label,
          conversationCount: corpus.conversationCount,
          messageCount: corpus.messageCount
        )
      } else {
        store.summaryUsedChunking = true
        var chunkSummaries: [String] = []

        for (index, chunk) in corpus.chunks.enumerated() {
          store.summaryStatusMessage = "Summarizing batch \(index + 1) of \(corpus.chunks.count)…"
          let summary = try await client.summarizeChunk(
            sourceDocument: chunk,
            workspaceName: workspaceName,
            rangeDescription: dateRange.label,
            partIndex: index + 1,
            totalParts: corpus.chunks.count
          )
          chunkSummaries.append("## Batch \(index + 1)\n\(summary)")
        }

        store.summaryStatusMessage = "Combining batch summaries…"
        turn = try await client.synthesizeSummary(
          chunkSummaries: chunkSummaries,
          workspaceName: workspaceName,
          rangeDescription: dateRange.label,
          conversationCount: corpus.conversationCount,
          messageCount: corpus.messageCount
        )
      }

      store.summaryMessages = [
        AnalyticsSummaryChatMessage(
          role: .assistant,
          text: turn.text
        ),
      ]
      store.summaryResponseID = turn.responseID
      store.summaryGeneratedAt = .now
      store.summaryStatusMessage = "Analyzed \(corpus.conversationCount) conversations and \(corpus.messageCount) messages."
      store.summaryTask = nil
    } catch {
      if isIgnorableCancellation(error) {
        store.summaryTask = nil
        store.summaryStatusMessage = nil
        store.summaryErrorMessage = nil
        return
      }
      store.summaryStatusMessage = nil
      store.summaryErrorMessage = error.localizedDescription
      store.summaryTask = nil
    }
  }

  func sendFollowUp() async {
    let question = store.followUpDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !question.isEmpty else { return }
    guard let summaryResponseID = store.summaryResponseID else {
      store.summaryErrorMessage = "Generate a summary before asking follow-up questions."
      return
    }

    store.isSendingFollowUp = true
    store.summaryErrorMessage = nil
    store.summaryStatusMessage = "Asking follow-up…"
    store.followUpDraft = ""

    let pendingUserMessage = AnalyticsSummaryChatMessage(
      role: .user,
      text: question
    )
    store.summaryMessages.append(pendingUserMessage)
    defer { store.isSendingFollowUp = false }

    do {
      let client = OpenAIAnalyticsSummaryClient(apiKey: openAIAPIKey)
      let turn = try await client.continueSummaryConversation(
        previousResponseID: summaryResponseID,
        userQuestion: question,
        workspaceName: workspaceName,
        rangeDescription: store.summaryRangeLabel ?? store.selectedDateRange?.label ?? "Selected range",
        conversationCount: store.conversationCount,
        messageCount: store.sourceMessageCount
      )
      store.summaryMessages.append(
        AnalyticsSummaryChatMessage(
          role: .assistant,
          text: turn.text
        )
      )
      store.summaryResponseID = turn.responseID
      store.summaryStatusMessage = nil
      store.followUpTask = nil
    } catch {
      if isIgnorableCancellation(error) {
        store.followUpTask = nil
        store.summaryStatusMessage = nil
        store.summaryErrorMessage = nil
        return
      }
      store.summaryMessages.removeAll { $0.id == pendingUserMessage.id }
      store.followUpDraft = question
      store.summaryStatusMessage = nil
      store.summaryErrorMessage = error.localizedDescription
      store.followUpTask = nil
    }
  }

  private func buildConversationCorpus(
    in dateRange: AnalyticsSummaryDateRange
  ) async throws -> AnalyticsConversationCorpus {
    try Task.checkCancellation()

    let candidateConversations = try await fetchAnalyticsConversations(
      in: dateRange,
      client: backendClient
    )

    guard !candidateConversations.isEmpty else {
      throw ConversationAssistantError.noAnalyticsMessages
    }

    var sections: [String] = []
    var messageCount = 0

    for (index, conversation) in candidateConversations.enumerated() {
      try Task.checkCancellation()
      store.summaryStatusMessage = "Collecting message histories (\(index + 1)/\(candidateConversations.count))…"
      let items = try await fetchAIMessageItems(
        conversation.id,
        backendClient,
        20
      )

      guard let section = buildConversationSection(
        for: conversation,
        items: items
      ) else {
        continue
      }

      sections.append(section.markdown)
      messageCount += section.messageCount
    }

    guard !sections.isEmpty, messageCount > 0 else {
      throw ConversationAssistantError.noAnalyticsMessages
    }

    let header = analyticsDocumentHeader(
      for: dateRange,
      conversationCount: sections.count,
      messageCount: messageCount
    )
    let document = ([header] + sections)
      .joined(separator: "\n\n---\n\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return AnalyticsConversationCorpus(
      document: document,
      chunks: analyticsSourceChunks(
        from: sections,
        header: header
      ),
      conversationCount: sections.count,
      messageCount: messageCount
    )
  }

  private func fetchAnalyticsConversations(
    in dateRange: AnalyticsSummaryDateRange,
    client: CossistantAdminClient
  ) async throws -> [DashboardConversation] {
    var collected: [DashboardConversation] = []
    var seenIDs = Set<String>()
    var cursor: String?
    var pageIndex = 0

    repeat {
      try Task.checkCancellation()
      store.summaryStatusMessage = "Loading conversations (page \(pageIndex + 1))…"
      let page = try await client.conversations.fetchInbox(
        limit: inboxPageSize,
        cursor: cursor
      )
      pageIndex += 1

      let uniqueItems = page.items.filter { seenIDs.insert($0.id).inserted }
      collected.append(
        contentsOf: uniqueItems.filter {
          conversation($0, overlaps: dateRange)
        }
      )

      cursor = page.nextCursor

      if uniqueItems.allSatisfy({ !conversationCouldAppearLaterInRange($0, dateRange: dateRange) }) {
        cursor = nil
      }
    } while cursor != nil

    return collected.sorted {
      $0.latestActivityDate > $1.latestActivityDate
    }
  }

  private func conversation(
    _ conversation: DashboardConversation,
    overlaps dateRange: AnalyticsSummaryDateRange
  ) -> Bool {
    let activityDate = conversation.latestActivityDate
    return activityDate >= dateRange.start && activityDate <= dateRange.end
  }

  private func conversationCouldAppearLaterInRange(
    _ conversation: DashboardConversation,
    dateRange: AnalyticsSummaryDateRange
  ) -> Bool {
    conversation.latestActivityDate >= dateRange.start
  }

  private func buildConversationSection(
    for conversation: DashboardConversation,
    items: [DashboardTimelineItem]
  ) -> AnalyticsConversationSection? {
    var lines = [
      "## Conversation",
      "",
      "- Status: \(conversation.status.label)",
      "- Priority: \(conversation.priority.label)",
      "- Visitor ID: \(conversation.visitorId)",
      "",
      "### Messages",
    ]
    var messageCount = 0

    for item in items {
      let text = item.renderedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let attachmentSummary = AIWorkflowFormatting.markdownAttachmentSummary(for: item)
      guard !text.isEmpty || attachmentSummary != nil else {
        continue
      }

      let senderLabel = AIWorkflowFormatting.senderLabel(for: item)
      let visibilitySuffix = item.visibility == .private ? " [private]" : ""

      lines.append("- \(senderLabel)\(visibilitySuffix):")

      if !text.isEmpty {
        lines.append(AIWorkflowFormatting.indentedMarkdownText(text, indentation: "  "))
      }

      if let attachmentSummary {
        lines.append("  _\(attachmentSummary)_")
      }

      messageCount += 1
    }

    guard messageCount > 0 else { return nil }
    return AnalyticsConversationSection(
      markdown: lines.joined(separator: "\n"),
      messageCount: messageCount
    )
  }

  private func analyticsDocumentHeader(
    for dateRange: AnalyticsSummaryDateRange,
    conversationCount: Int,
    messageCount: Int
  ) -> String {
    [
      "# Recent Support Conversation Digest",
      "",
      "- Workspace: \(workspaceName ?? "Cossistant")",
      "- Range: \(dateRange.label)",
      "- Conversations: \(conversationCount)",
      "- Messages: \(messageCount)",
      "- Generated at: \(Date.now.formatted(.dateTime.year().month().day().hour().minute()))",
    ].joined(separator: "\n")
  }

  private func analyticsSourceChunks(
    from sections: [String],
    header: String
  ) -> [String] {
    let directDocument = ([header] + sections)
      .joined(separator: "\n\n---\n\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let directLimit = 90_000
    let chunkLimit = 55_000

    if directDocument.count <= directLimit {
      return [directDocument]
    }

    let normalizedSections = sections.flatMap {
      splitAnalyticsSectionIfNeeded(
        $0,
        limit: chunkLimit - header.count - 128
      )
    }

    var groupedSections: [[String]] = []
    var currentGroup: [String] = []
    var currentLength = header.count

    for section in normalizedSections {
      let projectedLength = currentLength + section.count + 12

      if projectedLength > chunkLimit, !currentGroup.isEmpty {
        groupedSections.append(currentGroup)
        currentGroup = [section]
        currentLength = header.count + section.count
      } else {
        currentGroup.append(section)
        currentLength = projectedLength
      }
    }

    if !currentGroup.isEmpty {
      groupedSections.append(currentGroup)
    }

    let totalGroups = groupedSections.count
    return groupedSections.enumerated().map { index, group in
      [
        header,
        "",
        "_Batch \(index + 1) of \(totalGroups)_",
        "",
        group.joined(separator: "\n\n---\n\n"),
      ].joined(separator: "\n")
    }
  }

  private func splitAnalyticsSectionIfNeeded(
    _ section: String,
    limit: Int
  ) -> [String] {
    guard section.count > limit, limit > 1_000 else {
      return [section]
    }

    var chunks: [String] = []
    var currentLines: [String] = []
    var currentLength = 0

    for line in section.split(separator: "\n", omittingEmptySubsequences: false) {
      let stringLine = String(line)
      let projectedLength = currentLength + stringLine.count + 1

      if projectedLength > limit, !currentLines.isEmpty {
        chunks.append(currentLines.joined(separator: "\n"))
        currentLines = [stringLine]
        currentLength = stringLine.count
      } else {
        currentLines.append(stringLine)
        currentLength = projectedLength
      }
    }

    if !currentLines.isEmpty {
      chunks.append(currentLines.joined(separator: "\n"))
    }

    return chunks
  }
}
