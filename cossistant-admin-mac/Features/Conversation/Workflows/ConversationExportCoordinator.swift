import Foundation
import CossistantAdmin

private struct ConversationFullLogExport: Encodable, Sendable {
  let conversationId: String
  let title: String
  let website: String?
  let exportedAt: String
  let timeline: [DashboardTimelineItem]
}

@MainActor
final class ConversationExportCoordinator {
  private let store: ConversationStore
  private let backendClient: CossistantAdminClient
  private let canUseOpenAI: Bool
  private let openAIAPIKey: String
  private let workspaceName: String?
  private let selectedConversation: () -> DashboardConversation?
  private let selectedVisitor: () -> DashboardVisitor?
  private let selectedConversationID: () -> DashboardConversation.ID?
  private let website: () -> DashboardWebsite?

  init(
    store: ConversationStore,
    backendClient: CossistantAdminClient,
    canUseOpenAI: Bool,
    openAIAPIKey: String,
    workspaceName: String?,
    selectedConversation: @escaping () -> DashboardConversation?,
    selectedVisitor: @escaping () -> DashboardVisitor?,
    selectedConversationID: @escaping () -> DashboardConversation.ID?,
    website: @escaping () -> DashboardWebsite?
  ) {
    self.store = store
    self.backendClient = backendClient
    self.canUseOpenAI = canUseOpenAI
    self.openAIAPIKey = openAIAPIKey
    self.workspaceName = workspaceName
    self.selectedConversation = selectedConversation
    self.selectedVisitor = selectedVisitor
    self.selectedConversationID = selectedConversationID
    self.website = website
  }

  func generateReplyDraft(from draft: String) async -> String? {
    let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedDraft.isEmpty else { return nil }
    guard canUseOpenAI else {
      store.replyDraftErrorMessage = "Add an OpenAI API key in settings to draft translated replies."
      return nil
    }

    store.isGeneratingReplyDraft = true
    store.replyDraftErrorMessage = nil
    defer { store.isGeneratingReplyDraft = false }

    do {
      let transcript = try await buildSelectedConversationMessagesExport()
      let client = OpenAIReplyDraftClient(apiKey: openAIAPIKey)
      return try await client.generateDraft(
        transcript: transcript,
        operatorDraft: trimmedDraft,
        conversationTitle: selectedConversation()?.displayTitle,
        websiteName: workspaceName
      )
    } catch {
      store.replyDraftErrorMessage = error.localizedDescription
      return nil
    }
  }

  func generateReplyFromFAQ(
    using faq: DashboardKnowledge
  ) async -> String? {
    guard canUseOpenAI else {
      store.replyDraftErrorMessage = "Add an OpenAI API key in settings to generate FAQ-based replies."
      return nil
    }

    store.isGeneratingReplyDraft = true
    store.replyDraftErrorMessage = nil
    defer { store.isGeneratingReplyDraft = false }

    do {
      let transcript = try await buildSelectedConversationMessagesExport()
      let client = OpenAIReplyDraftClient(apiKey: openAIAPIKey)
      return try await client.generateFAQReply(
        transcript: transcript,
        faq: faq,
        conversationTitle: selectedConversation()?.displayTitle,
        websiteName: workspaceName,
        visitorLanguage: selectedConversation()?.visitorLanguage ?? selectedConversationDetailLanguage,
        visitorTitleLanguage: selectedConversation()?.visitorTitleLanguage
      )
    } catch {
      store.replyDraftErrorMessage = error.localizedDescription
      return nil
    }
  }

  func buildSelectedConversationMessagesMarkdown() async throws -> String {
    guard let conversation = selectedConversation() else {
      throw ConversationAssistantError.noConversationSelected
    }

    let items = try await fetchSelectedConversationMessageItems(maxPages: 20)
    let headerLines = [
      "# \(conversation.displayTitle)",
      "",
      "- Visitor: \(conversation.visitorDisplayName)",
      "- Status: \(conversation.status.label)",
      "- Priority: \(conversation.priority.label)",
      "",
    ]

    let messageBlocks = items.compactMap { item -> String? in
      let text = item.renderedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let attachmentSummary = AIWorkflowFormatting.markdownAttachmentSummary(for: item)

      guard !text.isEmpty || attachmentSummary != nil else {
        return nil
      }

      let sender = DashboardTimelinePresentation.senderDisplay(
        for: transcriptSender(for: item),
        website: website(),
        conversation: conversation,
        visitor: selectedVisitor()
      )

      var lines = ["## \(sender.name) · \(item.createdAt)"]

      if !text.isEmpty {
        lines.append(text)
      }

      if let attachmentSummary {
        lines.append("_\(attachmentSummary)_")
      }

      return lines.joined(separator: "\n")
    }

    return (headerLines + messageBlocks)
      .joined(separator: "\n\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func buildSelectedConversationMessagesExport() async throws -> String {
    let transcript = try await fetchSelectedConversationTranscript()
    return try encodeConversationTranscript(transcript)
  }

  func buildSelectedConversationFullLogExport() async throws -> String {
    guard let conversation = selectedConversation() else {
      throw ConversationAssistantError.noConversationSelected
    }

    let timeline = try await fetchSelectedConversationTimelineItems(maxPages: 20)
    let export = ConversationFullLogExport(
      conversationId: conversation.id,
      title: conversation.displayTitle,
      website: workspaceName,
      exportedAt: ISO8601DateFormatter.internetDateTime.string(from: .now),
      timeline: timeline
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(export)
    guard let string = String(data: data, encoding: .utf8) else {
      throw ConversationAssistantError.invalidTranscriptEncoding
    }

    return string
  }

  func encodeConversationTranscript(
    _ transcript: ConversationMachineTranscript
  ) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(transcript)
    guard let string = String(data: data, encoding: .utf8) else {
      throw ConversationAssistantError.invalidTranscriptEncoding
    }

    return string
  }

  func fetchSelectedConversationTranscript(
    maxPages: Int = 20
  ) async throws -> ConversationMachineTranscript {
    guard let conversation = selectedConversation() else {
      throw ConversationAssistantError.noConversationSelected
    }

    let items = try await fetchSelectedConversationMessageItems(maxPages: maxPages)
    let messages = items.map { item in
      let sender = DashboardTimelinePresentation.senderDisplay(
        for: transcriptSender(for: item),
        website: website(),
        conversation: conversation,
        visitor: selectedVisitor()
      )

      return ConversationMachineTranscript.Message(
        id: item.id,
        createdAt: item.createdAt,
        role: sender.kind.rawValue,
        sender: sender.name,
        visibility: item.visibility.rawValue,
        text: item.renderedText ?? "",
        attachments: attachmentLabels(for: item)
      )
    }

    return ConversationMachineTranscript(
      conversationId: conversation.id,
      title: conversation.displayTitle,
      website: workspaceName,
      exportedAt: ISO8601DateFormatter.internetDateTime.string(from: .now),
      messages: messages
    )
  }

  private func fetchSelectedConversationMessageItems(
    maxPages: Int
  ) async throws -> [DashboardTimelineItem] {
    try await fetchSelectedConversationTimelineItems(maxPages: maxPages)
      .filter { $0.type == .message && $0.deletedAt == nil }
  }

  private func fetchSelectedConversationTimelineItems(
    maxPages: Int
  ) async throws -> [DashboardTimelineItem] {
    guard let conversationID = selectedConversationID() else {
      return []
    }

    var collectedItems: [DashboardTimelineItem] = []
    var seenIDs = Set<String>()
    var cursor: String?
    var pageCount = 0

    repeat {
      let page = try await backendClient.conversations.fetchTimeline(
        conversationID: conversationID,
        limit: 100,
        cursor: cursor
      )

      for item in page.items {
        if seenIDs.insert(item.id).inserted {
          collectedItems.append(item)
        }
      }

      cursor = page.nextCursor
      pageCount += 1
    } while cursor != nil && pageCount < maxPages

    return collectedItems.sorted {
      ($0.createdAtDate ?? .distantPast) < ($1.createdAtDate ?? .distantPast)
    }
  }

  private func transcriptSender(
    for item: DashboardTimelineItem
  ) -> DashboardTimelineSender {
    if let userId = item.userId {
      return DashboardTimelineSender(id: userId, kind: .human)
    }

    if let aiAgentId = item.aiAgentId {
      return DashboardTimelineSender(id: aiAgentId, kind: .ai)
    }

    if let visitorId = item.visitorId {
      return DashboardTimelineSender(id: visitorId, kind: .visitor)
    }

    return DashboardTimelineSender(id: item.id, kind: .system)
  }

  private func attachmentLabels(for item: DashboardTimelineItem) -> [String] {
    var labels: [String] = []
    labels.append(contentsOf: item.imageParts.compactMap {
      $0.filename?.nilIfEmpty ?? $0.url.nilIfEmpty ?? "image"
    })
    labels.append(contentsOf: item.fileParts.compactMap {
      $0.filename?.nilIfEmpty ?? $0.url.nilIfEmpty ?? "file"
    })
    return labels
  }

  private var selectedConversationDetailLanguage: String? {
    selectedConversation()?.visitorLanguage
  }
}
