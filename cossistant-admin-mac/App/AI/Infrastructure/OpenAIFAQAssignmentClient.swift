import Foundation
import CossistantAdmin

struct OpenAIFAQAssignmentClient {
  private struct ErrorResponseBody: Decodable {
    struct ErrorPayload: Decodable {
      let message: String?
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
    struct Items: Encodable {
      let type: String
    }

    let type: String
    let description: String?
    let items: Items?

    init(
      type: String,
      description: String? = nil,
      items: Items? = nil
    ) {
      self.type = type
      self.description = description
      self.items = items
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

  func assignFAQs(
    transcript: String,
    faqIndex: String,
    websiteName: String?,
    conversationID: String
  ) async throws -> FAQResolverFAQMatch {
    guard let url = URL(string: "https://api.openai.com/v1/responses") else {
      throw ConversationAssistantError.invalidResponse
    }

    let developerPrompt = """
    You match a support conversation to a small FAQ knowledge base.
    Use only the supplied FAQ IDs and conversation transcript.
    Return FAQ IDs only when the FAQ could plausibly help answer the visitor's current request.
    Prefer no match over a weak or generic match.
    Multiple FAQ IDs are allowed when the conversation asks multiple related questions.
    Set canResolveWithoutReply to true when the visitor's request is already fully handled by the existing messages and the conversation should be resolved without sending another reply.
    Set noActionNeeded to true when no team reply is needed now because the next required step is visitor action, a known external event, or passive waiting; the conversation should be marked seen and stay open.
    Set urgentlyNeedsTeam to true when the visitor is waiting on the team, the request is unresolved, FAQ coverage is missing or insufficient, account-specific investigation is needed, or a teammate promised/manual follow-up is required; the conversation should be marked unread and stay open.
    When urgentlyNeedsTeam is true, write teamActionNeeded in English as a very short operator-facing reason or needed action, for example "Waiting for data migration to new account".
    When urgentlyNeedsTeam is false, teamActionNeeded must be an empty string.
    urgentlyNeedsTeam must be false when canResolveWithoutReply is true.
    noActionNeeded must be false when canResolveWithoutReply or urgentlyNeedsTeam is true.
    If unsure between noActionNeeded and urgentlyNeedsTeam, choose urgentlyNeedsTeam when the visitor is waiting for the team, and choose noActionNeeded only when the team is waiting for the visitor or an external event.
    """

    let userPrompt = """
    Workspace: \(websiteName ?? "Cossistant")
    Conversation ID: \(conversationID)

    FAQ index:
    \(faqIndex)

    Conversation transcript:
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
      maxOutputTokens: 500,
      reasoning: .init(effort: "low"),
      text: .init(
        format: .init(
          type: "json_schema",
          name: "faq_assignment",
          strict: true,
          schema: Self.assignmentSchema
        )
      )
    )

    let responseText = try await performRequest(body, url: url, logPrefix: "OpenAIFAQAssignment")
    guard let data = responseText.data(using: .utf8),
          let match = try? JSONDecoder().decode(FAQResolverFAQMatch.self, from: data)
    else {
      throw ConversationAssistantError.invalidResponse
    }

    return match
  }

  private func performRequest(
    _ body: RequestBody,
    url: URL,
    logPrefix: String
  ) async throws -> String {
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
      let errorBody = try? JSONDecoder().decode(ErrorResponseBody.self, from: data)
      let responseMessage = errorBody?.error?.message?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .nilIfEmpty
        ?? String(decoding: data, as: UTF8.self)
      print("[\(logPrefix)] request failed status=\(httpResponse.statusCode) message=\(responseMessage)")
      throw ConversationAssistantError.server(
        message: "OpenAI FAQ assignment failed (\(httpResponse.statusCode)): \(responseMessage)"
      )
    }

    if let incompleteReason = extractIncompleteReason(from: data) {
      throw ConversationAssistantError.server(
        message: "OpenAI FAQ assignment response was incomplete: \(incompleteReason)"
      )
    }

    guard let responseText = extractResponseText(from: data) else {
      print("[\(logPrefix)] unable to extract response text: \(String(decoding: data, as: UTF8.self))")
      throw ConversationAssistantError.invalidResponse
    }

    return responseText
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
      guard let contentItems = item["content"] as? [[String: Any]] else {
        continue
      }

      for contentItem in contentItems {
        if let nestedText = normalizedText(from: contentItem["text"]) {
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

  private static let assignmentSchema = JSONSchema(
    type: "object",
    properties: [
      "faqIds": Property(
        type: "array",
        description: "FAQ IDs that may match the conversation.",
        items: .init(type: "string")
      ),
      "canResolveWithoutReply": Property(
        type: "boolean",
        description: "True when the conversation already appears fully resolved and should be closed without sending another reply."
      ),
      "noActionNeeded": Property(
        type: "boolean",
        description: "True when no reply should be sent now, but the conversation is not resolved and should only be marked seen."
      ),
      "urgentlyNeedsTeam": Property(
        type: "boolean",
        description: "True when the unresolved conversation needs human/team action and should be marked unread."
      ),
      "teamActionNeeded": Property(
        type: "string",
        description: "Very short English operator-facing reason/action when urgentlyNeedsTeam is true. Empty string otherwise."
      ),
    ],
    required: ["faqIds", "canResolveWithoutReply", "noActionNeeded", "urgentlyNeedsTeam", "teamActionNeeded"],
    additionalProperties: false
  )
}
