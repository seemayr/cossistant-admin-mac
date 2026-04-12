import Foundation

struct OpenAIReplyDraftClient {
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

  func generateDraft(
    transcript: String,
    operatorDraft: String,
    conversationTitle: String?,
    websiteName: String?
  ) async throws -> String {
    guard let url = URL(string: "https://api.openai.com/v1/responses") else {
      throw ConversationAssistantError.invalidResponse
    }

    let developerPrompt = """
    You are helping a customer support agent write a reply draft.
    Use the provided conversation transcript as the only source of truth.
    Infer the customer's language from the transcript and rewrite the operator draft into a natural, professional support reply in that same language.
    Preserve the intent of the operator draft, avoid inventing facts, and return only the final reply text with no framing.
    """

    let userPrompt = """
    Workspace: \(websiteName ?? "Cossistant")
    Conversation title: \(conversationTitle ?? "Untitled conversation")

    Conversation transcript (JSON):
    \(transcript)

    Operator draft in their own language:
    \(operatorDraft)
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
      ]
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
        message: "OpenAI draft request failed (\(httpResponse.statusCode))."
      )
    }

    let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
    if let outputText = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines),
       !outputText.isEmpty {
      return outputText
    }

    let nestedContentItems = decoded.output?.flatMap { $0.content ?? [] } ?? []
    if let nestedText = nestedContentItems
      .first(where: { $0.type == "output_text" || $0.type == "text" })?
      .text?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !nestedText.isEmpty {
      return nestedText
    }

    throw ConversationAssistantError.invalidResponse
  }
}
