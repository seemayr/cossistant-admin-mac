import Foundation

struct OpenAIConversationResolutionClient {
  private struct ErrorResponseBody: Decodable {
    struct ErrorPayload: Decodable {
      let message: String?
      let type: String?
      let code: String?
    }

    let error: ErrorPayload?
  }

  private struct RequestBody: Encodable {
    struct InputMessage: Encodable {
      struct Content: Encodable {
        let type: String
        let text: String
      }

      let role: String
      let content: [Content]
    }

    struct Reasoning: Encodable {
      let effort: String
    }

    struct Text: Encodable {
      struct Format: Encodable {
        let type: String
        let name: String
        let strict: Bool
        let schema: JSONSchema
      }

      let format: Format
    }

    let model: String
    let input: [InputMessage]
    let maxOutputTokens: Int?
    let reasoning: Reasoning
    let text: Text

    enum CodingKeys: String, CodingKey {
      case model
      case input
      case maxOutputTokens = "max_output_tokens"
      case reasoning
      case text
    }
  }

  private struct JSONSchema: Encodable {
    let type: String
    let properties: [String: Property]
    let required: [String]
    let additionalProperties: Bool

    enum CodingKeys: String, CodingKey {
      case type
      case properties
      case required
      case additionalProperties = "additionalProperties"
    }
  }

  private struct Property: Encodable {
    let type: String
    let description: String?
    let enumValues: [String]?

    enum CodingKeys: String, CodingKey {
      case type
      case description
      case enumValues = "enum"
    }
  }

  private struct StructuredVerdict: Decodable {
    let verdict: String
    let category: String
    let title: String
    let body: String
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

  func reviewConversation(
    transcript: String,
    websiteName: String?,
    conversationID: String
  ) async throws -> OpenAIConversationResolutionVerdict {
    guard let url = URL(string: "https://api.openai.com/v1/responses") else {
      throw ConversationAssistantError.invalidResponse
    }

    let developerPrompt = """
    You review support conversations and decide whether the issue was fully resolved.
    Respond only in English.
    Use only the supplied conversation transcript as evidence.
    Mark a conversation as RESOLVED only if the visitor's problem was clearly answered or completed and there is strong evidence the conversation ended successfully.
    A conversation is NOT_RESOLVED if it is waiting for a support member, waiting for a teammate to join, escalated to a human, waiting on follow-up work, still unclear, or the visitor appears unsatisfied.
    Pure feedback, ideas, or feature suggestions with no unresolved support issue should be treated as RESOLVED.
    For pure feedback or ideas, use the exact title "Feedback / Idea".
    Also choose exactly one category from this list:
    feedback
    gameProblem
    productQuestion
    groupProblem
    accountProblem
    generalProblem
    other
    unknown
    Escalating to a human or promising a later action does not resolve the issue.
    If you are unsure, choose NOT_RESOLVED.
    Return exactly four lines:
    VERDICT: RESOLVED or NOT_RESOLVED
    CATEGORY: one category from the allowed list
    TITLE: a short English title on one line
    BODY: one or two short English sentences on one line
    """

    let userPrompt = """
    Workspace: \(websiteName ?? "Cossistant")
    Conversation ID: \(conversationID)

    Transcript:
    \(transcript)
    """

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
      maxOutputTokens: 400,
      reasoning: .init(effort: "low"),
      text: .init(
        format: .init(
          type: "json_schema",
          name: "auto_resolve_verdict",
          strict: true,
          schema: Self.verdictSchema
        )
      )
    )

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      print("[OpenAIAutoResolve]", "OpenAI auto-resolve returned a non-HTTP response for conversation \(conversationID)")
      throw ConversationAssistantError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      let errorBody = try? JSONDecoder().decode(ErrorResponseBody.self, from: data)
      let apiMessage = errorBody?.error?.message?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .nilIfEmpty
      let fallbackBody = String(decoding: data, as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .nilIfEmpty
      let responseMessage = apiMessage ?? fallbackBody ?? "Unexpected OpenAI error"

      print(
        "[OpenAIAutoResolve]",
        "OpenAI auto-resolve request failed for conversation \(conversationID) status=\(httpResponse.statusCode) message=\(responseMessage)"
      )
      throw ConversationAssistantError.server(
        message: "OpenAI auto-resolve request failed (\(httpResponse.statusCode)): \(responseMessage)"
      )
    }

    if let incompleteReason = extractIncompleteReason(from: data) {
      print(
        "[OpenAIAutoResolve]",
        "OpenAI auto-resolve response was incomplete for conversation \(conversationID) reason=\(incompleteReason)"
      )
      throw ConversationAssistantError.server(
        message: "OpenAI auto-resolve response was incomplete: \(incompleteReason)"
      )
    }

    guard let responseText = extractResponseText(from: data) else {
      print(
        "[OpenAIAutoResolve]",
        "Unable to extract response text for conversation \(conversationID). Raw body: \(String(decoding: data, as: UTF8.self))"
      )
      print("[OpenAIAutoResolve]", "OpenAI auto-resolve returned an empty response body for conversation \(conversationID)")
      throw ConversationAssistantError.invalidResponse
    }

    return parseStructuredVerdict(from: responseText)
  }

  private func parseStructuredVerdict(
    from responseText: String
  ) -> OpenAIConversationResolutionVerdict {
    let normalized = responseText.trimmingCharacters(in: .whitespacesAndNewlines)

    guard let jsonData = normalized.data(using: .utf8),
          let verdict = try? JSONDecoder().decode(StructuredVerdict.self, from: jsonData)
    else {
      print(
        "[OpenAIAutoResolve]",
        "Structured verdict JSON could not be decoded. Response text: \(normalized)"
      )
      return Self.parseLegacyVerdict(from: normalized)
    }

    let isResolved = verdict.verdict.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "RESOLVED"
    let category = AutoResolveConversationCategory(aiValue: verdict.category) ?? .unknown
    let title = verdict.title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
      ?? (isResolved ? "Resolved conversation" : "Not resolved")
    let body = verdict.body.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? normalized

    return OpenAIConversationResolutionVerdict(
      isResolved: isResolved,
      category: category,
      title: title,
      body: body,
      rawResponseText: normalized
    )
  }

  private static func parseLegacyVerdict(
    from responseText: String
  ) -> OpenAIConversationResolutionVerdict {
    let normalized = responseText.replacingOccurrences(of: "\r\n", with: "\n")
    let lines = normalized
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map(String.init)
    let verdictLine = lines.first {
      $0.uppercased().contains("VERDICT:")
    } ?? normalized
    let titleLine = lines.first {
      $0.uppercased().contains("TITLE:")
    }
    let bodyLine = lines.first {
      $0.uppercased().contains("BODY:")
    }
    let categoryLine = lines.first {
      $0.uppercased().contains("CATEGORY:")
    }

    let uppercasedVerdict = verdictLine.uppercased()
    let isResolved = uppercasedVerdict.contains("NOT_RESOLVED") ? false : uppercasedVerdict.contains("RESOLVED")
    let category = categoryLine?
      .replacingOccurrences(of: "CATEGORY:", with: "", options: [.caseInsensitive])
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .nilIfEmpty
      .flatMap(AutoResolveConversationCategory.init(aiValue:))
      ?? .unknown
    let title = titleLine?
      .replacingOccurrences(of: "TITLE:", with: "", options: [.caseInsensitive])
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .nilIfEmpty ?? (isResolved ? "Resolved conversation" : "Not resolved")
    let body = bodyLine?
      .replacingOccurrences(of: "BODY:", with: "", options: [.caseInsensitive])
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .nilIfEmpty ?? normalized

    return OpenAIConversationResolutionVerdict(
      isResolved: isResolved,
      category: category,
      title: title,
      body: body,
      rawResponseText: normalized
    )
  }

  private func extractResponseText(from data: Data) -> String? {
    guard
      let jsonObject = try? JSONSerialization.jsonObject(with: data),
      let dictionary = jsonObject as? [String: Any]
    else {
      return nil
    }

    if let outputText = normalizedText(from: dictionary["output_text"]) {
      return outputText
    }

    guard let outputItems = dictionary["output"] as? [[String: Any]] else {
      return nil
    }

    for item in outputItems {
      if let directText = normalizedText(from: item["text"]) {
        return directText
      }

      guard let contentItems = item["content"] as? [[String: Any]] else {
        continue
      }

      for contentItem in contentItems {
        if let nestedText = normalizedText(from: contentItem["text"]) {
          return nestedText
        }

        if
          let textPayload = contentItem["text"] as? [String: Any],
          let nestedText = normalizedText(from: textPayload["value"] ?? textPayload["text"])
        {
          return nestedText
        }
      }
    }

    return nil
  }

  private func extractIncompleteReason(from data: Data) -> String? {
    guard
      let jsonObject = try? JSONSerialization.jsonObject(with: data),
      let dictionary = jsonObject as? [String: Any],
      let status = dictionary["status"] as? String,
      status == "incomplete"
    else {
      return nil
    }

    if
      let details = dictionary["incomplete_details"] as? [String: Any],
      let reason = details["reason"] as? String,
      !reason.isEmpty
    {
      return reason
    }

    return "unknown"
  }

  private func normalizedText(from value: Any?) -> String? {
    guard let string = value as? String else { return nil }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static let verdictSchema = JSONSchema(
    type: "object",
    properties: [
      "verdict": Property(
        type: "string",
        description: "Whether the conversation is resolved.",
        enumValues: ["RESOLVED", "NOT_RESOLVED"]
      ),
      "category": Property(
        type: "string",
        description: "The single best matching conversation category.",
        enumValues: [
          "feedback",
          "gameProblem",
          "productQuestion",
          "groupProblem",
          "accountProblem",
          "generalProblem",
          "other",
          "unknown",
        ]
      ),
      "title": Property(
        type: "string",
        description: "A short English title for the verdict.",
        enumValues: nil
      ),
      "body": Property(
        type: "string",
        description: "One or two short English sentences explaining the verdict.",
        enumValues: nil
      ),
    ],
    required: ["verdict", "category", "title", "body"],
    additionalProperties: false
  )
}
