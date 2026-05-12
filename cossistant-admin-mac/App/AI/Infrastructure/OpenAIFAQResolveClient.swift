import Foundation
import CossistantAdmin

struct OpenAIFAQResolveClient {
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
    let type: String
    let description: String?
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

  func resolveConversation(
    transcript: String,
    faqDocument: String,
    websiteName: String?,
    conversationID: String
  ) async throws -> FAQResolverDraftResponse {
    guard let url = URL(string: "https://api.openai.com/v1/responses") else {
      throw ConversationAssistantError.invalidResponse
    }

    let developerPrompt = """
    You draft support replies using only the assigned FAQ entries and the conversation transcript.
    Reply in the language of the visitor or conversation.
    The reply is sent from a human/team account in the dashboard. Write as the teammate who is already answering, not as an AI handoff.
    Do not say that you will escalate, forward, pass this to the team, or have a team member review it. If more account-specific information is needed, ask for it directly so you can take a closer look.
    If the correct outcome is that a human/team member must investigate before any useful reply can be sent, return an empty message and set urgentlyNeedsTeam instead of drafting a handoff message.
    Before drafting a reply, check whether an Admin or AI Agent message already gave the same answer, troubleshooting step, request for information, or waiting instruction.
    Treat AI Agent messages as prior team-side support replies when checking for duplicate or already-covered content.
    If the existing conversation already contains the relevant answer or troubleshooting step and the next required step is visitor testing, visitor confirmation, visitor data, a visitor reply, a known external event, or passive waiting, return an empty message with noActionNeeded true and autoResolve false.
    Do not send reminders or repeat the same FAQ guidance just because an assigned FAQ matches.
    Draft a message only when it adds materially new information, corrects an incomplete or wrong previous answer, or answers a visitor question that is still open.
    Return an empty message when the assigned FAQs do not clearly answer the visitor's request.
    Set autoResolve to true only if the sent message would answer all currently open visitor questions and no human follow-up is needed.
    Set noActionNeeded to true only when no reply should be sent now because the next required step is visitor action, a known external event, or passive waiting; the conversation should be marked seen and stay open.
    Set urgentlyNeedsTeam to true only when no reply should be sent because the visitor is waiting on the team, the request is unresolved, FAQ coverage is missing or insufficient, account-specific investigation is needed, or a teammate promised/manual follow-up is required; the conversation should be marked unread and stay open.
    When urgentlyNeedsTeam is true, write teamActionNeeded in English as a very short operator-facing reason or needed action, for example "Waiting for data migration to new account".
    When urgentlyNeedsTeam is false, teamActionNeeded must be an empty string.
    urgentlyNeedsTeam must be false when message is non-empty or autoResolve is true.
    noActionNeeded must be false when autoResolve or urgentlyNeedsTeam is true, or when message is non-empty.
    Sending a message and marking the conversation unread are mutually exclusive actions. If a useful FAQ-based answer can be sent, return that message and leave urgentlyNeedsTeam false so the team can wait for the visitor's next response.
    If there is uncertainty, partial coverage, missing account-specific data, or a promised human action is needed, set autoResolve to false.
    If no message should be sent and you are unsure between noActionNeeded and urgentlyNeedsTeam, choose urgentlyNeedsTeam when the visitor is waiting for the team, and choose noActionNeeded only when the team is waiting for the visitor or an external event.
    Do not invent facts beyond the FAQ answers.
    """

    let userPrompt = """
    Workspace: \(websiteName ?? "Cossistant")
    Conversation ID: \(conversationID)

    Assigned FAQ entries:
    \(faqDocument)

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
      maxOutputTokens: 900,
      reasoning: .init(effort: "low"),
      text: .init(
        format: .init(
          type: "json_schema",
          name: "faq_resolution_reply",
          strict: true,
          schema: Self.resolveSchema
        )
      )
    )

    let responseText = try await performRequest(body, url: url)
    guard let data = responseText.data(using: .utf8),
          let draft = try? JSONDecoder().decode(FAQResolverDraftResponse.self, from: data)
    else {
      throw ConversationAssistantError.invalidResponse
    }

    return draft
  }

  private func performRequest(
    _ body: RequestBody,
    url: URL
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
      print("[OpenAIFAQResolve] request failed status=\(httpResponse.statusCode) message=\(responseMessage)")
      throw ConversationAssistantError.server(
        message: "OpenAI FAQ resolve failed (\(httpResponse.statusCode)): \(responseMessage)"
      )
    }

    if let incompleteReason = extractIncompleteReason(from: data) {
      throw ConversationAssistantError.server(
        message: "OpenAI FAQ resolve response was incomplete: \(incompleteReason)"
      )
    }

    guard let responseText = extractResponseText(from: data) else {
      print("[OpenAIFAQResolve] unable to extract response text: \(String(decoding: data, as: UTF8.self))")
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

  private static let resolveSchema = JSONSchema(
    type: "object",
    properties: [
      "message": Property(
        type: "string",
        description: "The support reply to send. Empty string if no good FAQ fit exists."
      ),
      "autoResolve": Property(
        type: "boolean",
        description: "Whether the conversation can be resolved after the message sends successfully."
      ),
      "noActionNeeded": Property(
        type: "boolean",
        description: "Whether the conversation should only be marked seen because no reply is needed now and it is not resolved."
      ),
      "urgentlyNeedsTeam": Property(
        type: "boolean",
        description: "Whether no answer should be sent and the conversation should be marked unread because it needs human/team action and must stay open."
      ),
      "teamActionNeeded": Property(
        type: "string",
        description: "Very short English operator-facing reason/action when urgentlyNeedsTeam is true. Empty string otherwise."
      ),
    ],
    required: ["message", "autoResolve", "noActionNeeded", "urgentlyNeedsTeam", "teamActionNeeded"],
    additionalProperties: false
  )
}
