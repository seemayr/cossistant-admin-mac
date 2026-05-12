import Foundation
import CossistantAdmin

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
    let developerPrompt = """
    You are helping a customer support agent write a reply draft.
    Use the provided conversation transcript as the only source of truth.
    Infer the customer's language from the transcript and translate or lightly rewrite the operator draft into that same language.
    Keep the result as close as possible to the operator draft's meaning, structure, length, and level of detail.
    Do not add extra troubleshooting steps, explanations, promises, policy statements, greetings, apologies, or sign-offs unless they are already present in the operator draft or clearly required to translate it naturally.
    Do not introduce any new facts or suggestions from the transcript on your own. The transcript is only for context, tone, references, and language resolution.
    If the operator draft is short, keep the result short. If it is direct, keep it direct.
    Return only the final reply text with no framing.
    """

    let userPrompt = """
    Workspace: \(websiteName ?? "Cossistant")
    Conversation title: \(conversationTitle ?? "Untitled conversation")

    Conversation transcript (JSON):
    \(transcript)

    Operator draft to preserve closely:
    \(operatorDraft)
    """

    return try await performRequest(
      developerPrompt: developerPrompt,
      userPrompt: userPrompt,
      failureContext: "OpenAI draft request failed"
    )
  }

  func generateFAQReply(
    transcript: String,
    faq: DashboardKnowledge,
    conversationTitle: String?,
    websiteName: String?,
    visitorLanguage: String?,
    visitorTitleLanguage: String?
  ) async throws -> String {
    guard let faqPayload = faq.faqPayload else {
      throw ConversationAssistantError.server(
        message: "The selected knowledge entry is not a FAQ."
      )
    }

    let developerPrompt = """
    You are helping a customer support agent reply to a conversation using one selected FAQ entry.
    Use the provided conversation transcript and the provided FAQ entry as the only sources of truth.
    Treat the FAQ answer as authoritative, do not invent product details or policy, and draft the most helpful answer you can while staying grounded in the FAQ.
    Write in the visitor's language. Prefer the explicit language hints when present; otherwise infer the language from the transcript.
    The reply will be sent from a human/team account in the dashboard. Write as the teammate who is already answering.
    Do not say that you will escalate, forward, pass this to the team, communicate it to the team, or have a team member review it.
    If more information is needed before a deeper check is possible, ask for that information directly so you can take a closer look.
    Return only the final reply text with no framing, explanation, bullets, or quotation marks.
    """

    let userPrompt = """
    Workspace: \(websiteName ?? "Cossistant")
    Conversation title: \(conversationTitle ?? "Untitled conversation")
    Visitor language hint: \(visitorLanguage ?? "unknown")
    Visitor title language hint: \(visitorTitleLanguage ?? "unknown")

    Selected FAQ entry:
    FAQ title: \(faq.sourceTitle ?? faq.titleText)
    Question: \(faqPayload.question)
    Answer: \(faqPayload.answer)
    Categories: \(faqPayload.categories.joined(separator: ", ").nilIfEmpty ?? "none")
    Related questions: \(faqPayload.relatedQuestions.joined(separator: " | ").nilIfEmpty ?? "none")

    Conversation transcript (JSON):
    \(transcript)
    """

    return try await performRequest(
      developerPrompt: developerPrompt,
      userPrompt: userPrompt,
      failureContext: "OpenAI FAQ resolution request failed"
    )
  }

  private func performRequest(
    developerPrompt: String,
    userPrompt: String,
    failureContext: String
  ) async throws -> String {
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
        message: "\(failureContext) (\(httpResponse.statusCode))."
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

private extension String {
  var nilIfEmpty: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
