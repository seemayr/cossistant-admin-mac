import Foundation
import CossistantAdmin

struct OpenAIFAQDraftingClient {
  private struct RequestBody: Encodable {
    struct InputMessage: Encodable {
      struct Content: Encodable {
        let type: String
        let text: String
      }

      let role: String
      let content: [Content]
    }

    let model: String
    let input: [InputMessage]
    let maxOutputTokens: Int

    enum CodingKeys: String, CodingKey {
      case model
      case input
      case maxOutputTokens = "max_output_tokens"
    }
  }

  private struct ResponseBody: Decodable {
    struct OutputItem: Decodable {
      struct ContentItem: Decodable {
        let type: String
        let text: String?
      }

      let content: [ContentItem]?
    }

    let outputText: String?
    let output: [OutputItem]?

    enum CodingKeys: String, CodingKey {
      case outputText = "output_text"
      case output
    }
  }

  private static let model = "gpt-5-mini"

  let apiKey: String
  let session: URLSession

  init(
    apiKey: String,
    session: URLSession = .shared
  ) {
    self.apiKey = apiKey
    self.session = session
  }

  func optimizeDraft(
    _ draft: FAQDraft,
    workspaceName: String?
  ) async throws -> FAQDraftSuggestion {
    let sourceDraftJSON = """
    {
      "question": \(draft.normalizedQuestion.jsonQuoted),
      "categories": \(draft.normalizedCategories.jsonArrayLiteral),
      "relatedQuestions": \(draft.normalizedRelatedQuestions.jsonArrayLiteral),
      "answer": \(draft.normalizedAnswer.jsonQuoted)
    }
    """

    let prompts = try FAQPromptLibrary.optimizePrompts(
      workspaceName: workspaceName,
      draftJSON: sourceDraftJSON
    )

    let initialPayload = try await send(
      developerPrompt: prompts.developer,
      userPrompt: prompts.user,
      maxOutputTokens: 1_600,
      failureLabel: "OpenAI FAQ optimization request failed"
    )

    let reviewedPayload = try await selfCheckPayload(
      initialPayload,
      sourceLabel: "Manual FAQ draft",
      sourceMaterial: sourceDraftJSON,
      failureLabel: "OpenAI FAQ self-check request failed"
    )

    return FAQDraftSuggestion(
      draft: FAQDraft(payload: reviewedPayload),
      notes: reviewedPayload.notes
    )
  }

  func buildDraftFromConversation(
    transcript: String,
    workspaceName: String?,
    conversationTitle: String?,
    messageCount: Int
  ) async throws -> FAQDraftSuggestion {
    let prompts = try FAQPromptLibrary.buildPrompts(
      workspaceName: workspaceName,
      conversationTitle: conversationTitle,
      messageCount: messageCount,
      transcriptJSON: transcript
    )

    let initialPayload = try await send(
      developerPrompt: prompts.developer,
      userPrompt: prompts.user,
      maxOutputTokens: 1_600,
      failureLabel: "OpenAI FAQ drafting request failed"
    )

    let reviewedPayload = try await selfCheckPayload(
      initialPayload,
      sourceLabel: "Conversation transcript",
      sourceMaterial: transcript,
      failureLabel: "OpenAI FAQ self-check request failed"
    )

    return FAQDraftSuggestion(
      draft: FAQDraft(payload: reviewedPayload),
      notes: reviewedPayload.notes
    )
  }

  private func selfCheckPayload(
    _ payload: FAQDraftModelPayload,
    sourceLabel: String,
    sourceMaterial: String,
    failureLabel: String
  ) async throws -> FAQDraftModelPayload {
    let candidateJSON = """
    {
      "question": \(payload.question.jsonQuoted),
      "categories": \(payload.categories.jsonArrayLiteral),
      "relatedQuestions": \(payload.relatedQuestions.jsonArrayLiteral),
      "answer": \(payload.answer.jsonQuoted),
      "notes": \(payload.notes?.jsonQuoted ?? "null")
    }
    """

    let prompts = try FAQPromptLibrary.selfCheckPrompts(
      sourceLabel: sourceLabel,
      sourceMaterial: sourceMaterial,
      candidateJSON: candidateJSON
    )

    return try await send(
      developerPrompt: prompts.developer,
      userPrompt: prompts.user,
      maxOutputTokens: 1_600,
      failureLabel: failureLabel
    )
  }

  private func send(
    developerPrompt: String,
    userPrompt: String,
    maxOutputTokens: Int,
    failureLabel: String
  ) async throws -> FAQDraftModelPayload {
    guard let url = URL(string: "https://api.openai.com/v1/responses") else {
      throw ConversationAssistantError.invalidResponse
    }

    let body = RequestBody(
      model: Self.model,
      input: [
        .init(
          role: "developer",
          content: [.init(type: "input_text", text: developerPrompt)]
        ),
        .init(
          role: "user",
          content: [.init(type: "input_text", text: userPrompt)]
        ),
      ],
      maxOutputTokens: maxOutputTokens
    )

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ConversationAssistantError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw ConversationAssistantError.server(
        message: "\(failureLabel) (\(httpResponse.statusCode))."
      )
    }

    let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
    let nestedContentItems = decoded.output?.flatMap { $0.content ?? [] } ?? []
    let nestedText = nestedContentItems
      .first(where: { $0.type == "output_text" || $0.type == "text" })?
      .text?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedNestedText = FAQPromptText.nilIfEmpty(nestedText)
    let rawText = FAQPromptText.nilIfEmpty(decoded.outputText) ?? normalizedNestedText

    guard let rawText else {
      throw ConversationAssistantError.invalidResponse
    }

    let normalized = rawText.strippingCodeFenceIfPresent
    guard let jsonData = normalized.data(using: .utf8) else {
      throw ConversationAssistantError.invalidResponse
    }

    return try JSONDecoder().decode(FAQDraftModelPayload.self, from: jsonData).normalized
  }
}

private enum FAQPromptText {
  static func nilIfEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
