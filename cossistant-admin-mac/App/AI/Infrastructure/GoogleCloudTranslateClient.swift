import Foundation
import CossistantAdmin

struct GoogleCloudTranslateClient {
  private struct RequestBody: Encodable {
    let q: [String]
    let target: String
    let format: String = "text"
  }

  private struct ResponseBody: Decodable {
    struct ResponseData: Decodable {
      struct Translation: Decodable {
        let translatedText: String
        let detectedSourceLanguage: String?
      }

      let translations: [Translation]
    }

    let data: ResponseData
  }

  let apiKey: String
  let session: URLSession

  init(
    apiKey: String,
    session: URLSession = .shared
  ) {
    self.apiKey = apiKey
    self.session = session
  }

  func translate(
    texts: [String],
    targetLanguageCode: String
  ) async throws -> [DashboardMessageTranslation] {
    guard !texts.isEmpty else { return [] }

    var components = URLComponents(string: "https://translation.googleapis.com/language/translate/v2")
    components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]

    guard let url = components?.url else {
      throw ConversationAssistantError.invalidResponse
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = try JSONEncoder().encode(
      RequestBody(q: texts, target: targetLanguageCode)
    )

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ConversationAssistantError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw ConversationAssistantError.server(
        message: "Google Translate request failed (\(httpResponse.statusCode))."
      )
    }

    let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
    return decoded.data.translations.map {
      DashboardMessageTranslation(
        text: $0.translatedText.decodingHTMLEntities,
        detectedSourceLanguage: $0.detectedSourceLanguage
      )
    }
  }
}
