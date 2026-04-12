import Foundation

struct DashboardMessageTranslation: Equatable, Sendable {
  let text: String
  let detectedSourceLanguage: String?
}

struct ConversationMachineTranscript: Encodable, Sendable {
  struct Message: Encodable, Sendable {
    let id: String
    let createdAt: String
    let role: String
    let sender: String
    let visibility: String
    let text: String
    let attachments: [String]
  }

  let conversationId: String
  let title: String
  let website: String?
  let exportedAt: String
  let messages: [Message]
}

enum ConversationAssistantError: LocalizedError {
  case noConversationSelected
  case noConversationMessages
  case noAnalyticsMessages
  case invalidTranscriptEncoding
  case invalidResponse
  case server(message: String)

  var errorDescription: String? {
    switch self {
    case .noConversationSelected:
      "Select a conversation first."
    case .noConversationMessages:
      "The selected conversation does not contain any usable non-empty messages."
    case .noAnalyticsMessages:
      "No non-empty conversations were found in the selected time range."
    case .invalidTranscriptEncoding:
      "The conversation transcript could not be encoded."
    case .invalidResponse:
      "The assistant response could not be decoded."
    case .server(let message):
      message
    }
  }
}
