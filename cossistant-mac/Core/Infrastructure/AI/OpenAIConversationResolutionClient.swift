import Foundation

struct OpenAIConversationResolutionClient {
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
    let maxOutputTokens: Int?

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
      maxOutputTokens: 160
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
        message: "OpenAI auto-resolve request failed (\(httpResponse.statusCode))."
      )
    }

    let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
    let responseText: String?
    if let outputText = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines),
       !outputText.isEmpty {
      responseText = outputText
    } else {
      let nestedContentItems = decoded.output?.flatMap { $0.content ?? [] } ?? []
      responseText = nestedContentItems
        .first(where: { $0.type == "output_text" || $0.type == "text" })?
        .text?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    guard let responseText, !responseText.isEmpty else {
      throw ConversationAssistantError.invalidResponse
    }

    return Self.parseVerdict(from: responseText)
  }

  private static func parseVerdict(
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
      body: body
    )
  }
}
