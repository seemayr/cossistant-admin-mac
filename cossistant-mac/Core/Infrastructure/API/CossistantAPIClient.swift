import Foundation

struct WorkspaceBootstrap {
  let website: DashboardWebsite
  let organization: DashboardOrganization
  let inbox: DashboardConversationPage
}

enum CossistantAPIError: LocalizedError {
  struct ErrorPayload: Decodable {
    let error: String
    let message: String?
  }

  case invalidBaseURL
  case invalidPrivateAPIKey
  case invalidResponse
  case server(statusCode: Int, message: String)

  var errorDescription: String? {
    switch self {
    case .invalidBaseURL:
      "Enter a valid API base URL."
    case .invalidPrivateAPIKey:
      "Private API keys must start with `sk_`."
    case .invalidResponse:
      "The API response could not be decoded."
    case .server(let statusCode, let message):
      "API request failed (\(statusCode)): \(message)"
    }
  }
}

final class CossistantAPIClient {
  let configuration: DashboardConfiguration
  let session: URLSession
  let decoder = JSONDecoder()
  let encoder = JSONEncoder()
  static let queryValueAllowedCharacters: CharacterSet = {
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: "+&=?")
    return allowed
  }()

  init(
    configuration: DashboardConfiguration,
    session: URLSession = .shared
  ) {
    self.configuration = configuration
    self.session = session
  }

  func request<Response: Decodable>(
    method: String = "GET",
    path: String,
    queryItems: [URLQueryItem] = []
  ) async throws -> Response {
    try await request(method: method, path: path, queryItems: queryItems, bodyData: nil)
  }

  func request<Response: Decodable, Body: Encodable>(
    method: String,
    path: String,
    queryItems: [URLQueryItem] = [],
    body: Body
  ) async throws -> Response {
    try await request(
      method: method,
      path: path,
      queryItems: queryItems,
      bodyData: try encoder.encode(body)
    )
  }

  func request<Response: Decodable>(
    method: String,
    path: String,
    queryItems: [URLQueryItem],
    bodyData: Data?
  ) async throws -> Response {
    guard configuration.trimmedPrivateAPIKey.hasPrefix("sk_") else {
      throw CossistantAPIError.invalidPrivateAPIKey
    }

    guard let baseURL = configuration.apiBaseURL else {
      throw CossistantAPIError.invalidBaseURL
    }

    let resourceURL = baseURL.appending(path: path)
    guard var components = URLComponents(url: resourceURL, resolvingAgainstBaseURL: false) else {
      throw CossistantAPIError.invalidBaseURL
    }
    if queryItems.isEmpty {
      components.queryItems = nil
    } else {
      components.percentEncodedQuery = queryItems
        .map { item in
          let name = item.name.addingPercentEncoding(
            withAllowedCharacters: Self.queryValueAllowedCharacters
          ) ?? item.name
          let value = (item.value ?? "").addingPercentEncoding(
            withAllowedCharacters: Self.queryValueAllowedCharacters
          ) ?? item.value ?? ""
          return "\(name)=\(value)"
        }
        .joined(separator: "&")
    }

    guard let url = components.url else {
      throw CossistantAPIError.invalidBaseURL
    }

    print("[API]", method, url.absoluteString)
    if DashboardReadDebug.isTargetPath(path) {
      DashboardReadDebug.log(
        "API.request",
        "\(method) \(url.absoluteString) body=\(DashboardReadDebug.rawBodyString(bodyData))"
      )
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(
      "Bearer \(configuration.trimmedPrivateAPIKey)",
      forHTTPHeaderField: "Authorization"
    )

    if let bodyData {
      request.httpBody = bodyData
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw CossistantAPIError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      if DashboardReadDebug.isTargetPath(path) {
        DashboardReadDebug.log(
          "API.response",
          "status=\(httpResponse.statusCode) body=\(DashboardReadDebug.responseString(data))"
        )
      }

      let payload = try? decoder.decode(CossistantAPIError.ErrorPayload.self, from: data)
      throw CossistantAPIError.server(
        statusCode: httpResponse.statusCode,
        message: payload?.message ?? payload?.error ?? "Unexpected API error"
      )
    }

    if DashboardReadDebug.isTargetPath(path) {
      DashboardReadDebug.log(
        "API.response",
        "status=\(httpResponse.statusCode) body=\(DashboardReadDebug.responseString(data))"
      )
    }

    do {
      if data.isEmpty, Response.self == EmptyResponse.self {
        return EmptyResponse() as! Response
      }

      return try decoder.decode(Response.self, from: data)
    } catch {
      throw CossistantAPIError.invalidResponse
    }
  }
}
