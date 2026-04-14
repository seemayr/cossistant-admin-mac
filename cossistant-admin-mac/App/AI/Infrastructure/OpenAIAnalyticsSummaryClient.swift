import Foundation
import CossistantAdmin

struct OpenAIAnalyticsSummaryClient {
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
    let previousResponseID: String?
    let maxOutputTokens: Int?

    enum CodingKeys: String, CodingKey {
      case model
      case input
      case previousResponseID = "previous_response_id"
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

    let id: String
    let outputText: String?
    let output: [OutputItem]?

    enum CodingKeys: String, CodingKey {
      case id
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

  func startSummaryConversation(
    sourceDocument: String,
    workspaceName: String?,
    rangeDescription: String,
    conversationCount: Int,
    messageCount: Int
  ) async throws -> OpenAIAnalyticsTurn {
    let developerPrompt = """
    You analyze recent support conversations for an internal support team.
    Respond only in English.
    Use only the supplied conversation digest as evidence.
    Summarize what customers are complaining about, reporting, or struggling with lately.
    Prioritize recurring issues, affected product areas, severity, notable changes in volume, and representative examples.
    If evidence is weak or mixed, say so plainly.
    Return readable markdown with short section headers and bullets.
    Put each heading and each bullet on its own line.
    Leave a blank line between sections.
    Do not return one dense paragraph.
    """

    let userPrompt = """
    Workspace: \(workspaceName ?? "Cossistant")
    Time range: \(rangeDescription)
    Conversations analyzed: \(conversationCount)
    Messages analyzed: \(messageCount)

    Conversation digest:
    \(sourceDocument)
    """

    return try await send(
      developerPrompt: developerPrompt,
      userPrompt: userPrompt,
      previousResponseID: nil,
      maxOutputTokens: 1_600,
      failureLabel: "OpenAI analytics request failed"
    )
  }

  func summarizeChunk(
    sourceDocument: String,
    workspaceName: String?,
    rangeDescription: String,
    partIndex: Int,
    totalParts: Int
  ) async throws -> String {
    let developerPrompt = """
    You are preparing an intermediate summary of support conversations.
    Respond only in English.
    Use only the supplied batch as evidence.
    Extract the main complaints, reported bugs, confusing behavior, and support requests from this batch.
    Highlight repeated themes and a few representative examples.
    Keep the summary compact but information-dense.
    Return readable markdown bullets.
    Put each bullet on its own line.
    """

    let userPrompt = """
    Workspace: \(workspaceName ?? "Cossistant")
    Time range: \(rangeDescription)
    Batch: \(partIndex) of \(totalParts)

    Batch digest:
    \(sourceDocument)
    """

    let turn = try await send(
      developerPrompt: developerPrompt,
      userPrompt: userPrompt,
      previousResponseID: nil,
      maxOutputTokens: 1_000,
      failureLabel: "OpenAI batch summary request failed"
    )
    return turn.text
  }

  func synthesizeSummary(
    chunkSummaries: [String],
    workspaceName: String?,
    rangeDescription: String,
    conversationCount: Int,
    messageCount: Int
  ) async throws -> OpenAIAnalyticsTurn {
    let developerPrompt = """
    You are combining multiple batch summaries of support conversations into one internal report.
    Respond only in English.
    Use only the supplied batch summaries as evidence.
    Focus on the most common reported problems, what customers are trying to do, what seems broken, and what deserves investigation.
    Return readable markdown with section headers and bullets.
    Put each heading and each bullet on its own line.
    Leave a blank line between sections.
    Do not return one dense paragraph.
    """

    let userPrompt = """
    Workspace: \(workspaceName ?? "Cossistant")
    Time range: \(rangeDescription)
    Conversations analyzed: \(conversationCount)
    Messages analyzed: \(messageCount)

    Batch summaries:
    \(chunkSummaries.joined(separator: "\n\n"))
    """

    return try await send(
      developerPrompt: developerPrompt,
      userPrompt: userPrompt,
      previousResponseID: nil,
      maxOutputTokens: 1_600,
      failureLabel: "OpenAI synthesis request failed"
    )
  }

  func continueSummaryConversation(
    previousResponseID: String,
    userQuestion: String,
    workspaceName: String?,
    rangeDescription: String,
    conversationCount: Int,
    messageCount: Int
  ) async throws -> OpenAIAnalyticsTurn {
    let developerPrompt = """
    You are continuing an internal support analytics conversation.
    Respond only in English.
    Base your answer only on the support analysis context already established in this conversation plus the user's follow-up question.
    If the question requires evidence you do not have, say that explicitly.
    Prefer concise readable markdown.
    Put each heading and each bullet on its own line.
    Leave a blank line between sections when useful.
    """

    let userPrompt = """
    Workspace: \(workspaceName ?? "Cossistant")
    Time range: \(rangeDescription)
    Conversations analyzed: \(conversationCount)
    Messages analyzed: \(messageCount)

    Follow-up question:
    \(userQuestion)
    """

    return try await send(
      developerPrompt: developerPrompt,
      userPrompt: userPrompt,
      previousResponseID: previousResponseID,
      maxOutputTokens: 1_200,
      failureLabel: "OpenAI follow-up request failed"
    )
  }

  private func send(
    developerPrompt: String,
    userPrompt: String,
    previousResponseID: String?,
    maxOutputTokens: Int,
    failureLabel: String
  ) async throws -> OpenAIAnalyticsTurn {
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
      previousResponseID: previousResponseID,
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
    if let outputText = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines),
       !outputText.isEmpty {
      return OpenAIAnalyticsTurn(
        responseID: decoded.id,
        text: outputText
      )
    }

    let nestedContentItems = decoded.output?.flatMap { $0.content ?? [] } ?? []
    if let nestedText = nestedContentItems
      .first(where: { $0.type == "output_text" || $0.type == "text" })?
      .text?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !nestedText.isEmpty {
      return OpenAIAnalyticsTurn(
        responseID: decoded.id,
        text: nestedText
      )
    }

    throw ConversationAssistantError.invalidResponse
  }
}
