import Foundation

struct DashboardBootstrap {
  let website: DashboardWebsite
  let organization: DashboardOrganization
  let inbox: DashboardConversationPage
}

enum DashboardAPIError: LocalizedError {
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

final class DashboardAPIClient {
  private let configuration: DashboardConfiguration
  private let session: URLSession
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()
  private static let queryValueAllowedCharacters: CharacterSet = {
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

  func fetchBootstrap(limit: Int = 100) async throws -> DashboardBootstrap {
    let website: DashboardWebsite = try await request(path: "websites")
    let organization: DashboardOrganization = try await request(
      path: "organizations/\(website.organizationId)"
    )
    let inbox = try await fetchInbox(limit: limit, cursor: nil)

    return DashboardBootstrap(
      website: website,
      organization: organization,
      inbox: inbox
    )
  }

  func fetchInbox(limit: Int = 100, cursor: String?) async throws -> DashboardConversationPage {
    var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
    if let cursor {
      queryItems.append(URLQueryItem(name: "cursor", value: cursor))
    }

    return try await request(path: "conversations/inbox", queryItems: queryItems)
  }

  func fetchConversation(id: DashboardConversation.ID) async throws -> DashboardConversationDetail {
    let response: DashboardConversationResponse = try await request(path: "conversations/\(id)")
    return response.conversation
  }

  func fetchTimeline(
    conversationID: DashboardConversation.ID,
    limit: Int = 50,
    cursor: String? = nil
  ) async throws -> DashboardTimelinePage {
    var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
    if let cursor {
      queryItems.append(URLQueryItem(name: "cursor", value: cursor))
    }

    return try await request(
      path: "conversations/\(conversationID)/timeline",
      queryItems: queryItems
    )
  }

  func fetchConversationSeenData(
    conversationID: DashboardConversation.ID
  ) async throws -> [DashboardConversationSeen] {
    let response: DashboardConversationSeenResponse = try await request(
      path: "conversations/\(conversationID)/seen"
    )
    return response.seenData
  }

  func markConversationRead(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/read"
    )
    return response.conversation
  }

  func setConversationTyping(
    conversationID: DashboardConversation.ID,
    payload: DashboardConversationTypingRequest
  ) async throws -> DashboardConversationTypingResponse {
    try await request(
      method: "POST",
      path: "conversations/\(conversationID)/typing",
      body: payload
    )
  }

  func resolveConversation(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/resolve"
    )
    return response.conversation
  }

  func reopenConversation(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/reopen"
    )
    return response.conversation
  }

  func markConversationSpam(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/spam"
    )
    return response.conversation
  }

  func markConversationNotSpam(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/not-spam"
    )
    return response.conversation
  }

  func markConversationUnread(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/unread"
    )
    return response.conversation
  }

  func archiveConversation(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/archive"
    )
    return response.conversation
  }

  func unarchiveConversation(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/unarchive"
    )
    return response.conversation
  }

  func updateConversationTitle(
    conversationID: DashboardConversation.ID,
    title: String?
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "PATCH",
      path: "conversations/\(conversationID)",
      body: DashboardUpdateConversationTitleRequest(title: title)
    )
    return response.conversation
  }

  func joinConversationEscalation(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/join-escalation"
    )
    return response.conversation
  }

  func pauseConversationAI(
    conversationID: DashboardConversation.ID,
    durationMinutes: Int
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/ai/pause",
      body: DashboardPauseConversationAIRequest(durationMinutes: durationMinutes)
    )
    return response.conversation
  }

  func resumeConversationAI(
    conversationID: DashboardConversation.ID
  ) async throws -> DashboardConversationMutation {
    let response: DashboardConversationMutationResponse = try await request(
      method: "POST",
      path: "conversations/\(conversationID)/ai/resume"
    )
    return response.conversation
  }

  func sendTimelineItem(
    _ payload: DashboardSendTimelineItemRequest
  ) async throws -> DashboardTimelineItem {
    let response: DashboardSendTimelineItemResponse = try await request(
      method: "POST",
      path: "messages",
      body: payload
    )
    return response.item
  }

  func fetchVisitor(id: String) async throws -> DashboardVisitor {
    try await request(path: "visitors/\(id)")
  }

  func updateVisitor(
    id: String,
    payload: DashboardVisitorUpdateRequest
  ) async throws -> DashboardVisitor {
    try await request(
      method: "PATCH",
      path: "visitors/\(id)",
      body: payload
    )
  }

  func updateVisitorMetadata(
    visitorID: String,
    metadata: DashboardMetadata
  ) async throws -> DashboardVisitor {
    try await request(
      method: "PATCH",
      path: "visitors/\(visitorID)/metadata",
      body: DashboardVisitorMetadataUpdateRequest(metadata: metadata)
    )
  }

  func listContacts(
    page: Int = 1,
    limit: Int = 20,
    search: String? = nil,
    sortBy: DashboardContactSortBy? = nil,
    sortOrder: DashboardSortOrder? = nil,
    visitorStatus: DashboardContactVisitorStatus = .all
  ) async throws -> DashboardContactListResponse {
    var queryItems = [
      URLQueryItem(name: "page", value: String(page)),
      URLQueryItem(name: "limit", value: String(limit)),
      URLQueryItem(name: "visitorStatus", value: visitorStatus.rawValue),
    ]

    if let search, !search.isEmpty {
      queryItems.append(URLQueryItem(name: "search", value: search))
    }

    if let sortBy {
      queryItems.append(URLQueryItem(name: "sortBy", value: sortBy.rawValue))
    }

    if let sortOrder {
      queryItems.append(URLQueryItem(name: "sortOrder", value: sortOrder.rawValue))
    }

    return try await request(path: "contacts", queryItems: queryItems)
  }

  func fetchContact(id: String) async throws -> DashboardContact {
    try await request(path: "contacts/\(id)")
  }

  func createContact(_ draft: DashboardContactDraft) async throws -> DashboardContact {
    try await request(method: "POST", path: "contacts", body: draft)
  }

  func updateContact(
    id: String,
    draft: DashboardContactDraft
  ) async throws -> DashboardContact {
    try await request(method: "PATCH", path: "contacts/\(id)", body: draft)
  }

  func updateContactMetadata(
    id: String,
    metadata: DashboardMetadata
  ) async throws -> DashboardContact {
    try await request(
      method: "PATCH",
      path: "contacts/\(id)/metadata",
      body: DashboardContactMetadataUpdateRequest(metadata: metadata)
    )
  }

  func deleteContact(id: String) async throws {
    let _: EmptyResponse = try await request(method: "DELETE", path: "contacts/\(id)")
  }

  func identifyContact(
    _ payload: DashboardIdentifyContactRequest
  ) async throws -> DashboardIdentifyContactResponse {
    try await request(method: "POST", path: "contacts/identify", body: payload)
  }

  func createContactOrganization(
    _ draft: DashboardContactOrganizationDraft
  ) async throws -> DashboardContactOrganization {
    try await request(
      method: "POST",
      path: "contacts/organizations",
      body: draft
    )
  }

  func fetchContactOrganization(id: String) async throws -> DashboardContactOrganization {
    try await request(path: "contacts/organizations/\(id)")
  }

  func updateContactOrganization(
    id: String,
    draft: DashboardContactOrganizationDraft
  ) async throws -> DashboardContactOrganization {
    try await request(
      method: "PATCH",
      path: "contacts/organizations/\(id)",
      body: draft
    )
  }

  func deleteContactOrganization(id: String) async throws {
    let _: EmptyResponse = try await request(
      method: "DELETE",
      path: "contacts/organizations/\(id)"
    )
  }

  func listKnowledge(
    page: Int = 1,
    limit: Int = 20,
    type: DashboardKnowledgeType? = nil,
    aiAgentID: String? = nil,
    isIncluded: DashboardKnowledgeIncludedFilter = .all,
    linkSourceID: String? = nil
  ) async throws -> DashboardKnowledgeListResponse {
    var queryItems = [
      URLQueryItem(name: "page", value: String(page)),
      URLQueryItem(name: "limit", value: String(limit)),
    ]

    if let type {
      queryItems.append(URLQueryItem(name: "type", value: type.rawValue))
    }

    if let aiAgentID {
      queryItems.append(URLQueryItem(name: "aiAgentId", value: aiAgentID))
    }

    if let isIncludedValue = isIncluded.queryValue {
      queryItems.append(URLQueryItem(name: "isIncluded", value: isIncludedValue))
    }

    if let linkSourceID, !linkSourceID.isEmpty {
      queryItems.append(URLQueryItem(name: "linkSourceId", value: linkSourceID))
    }

    return try await request(path: "knowledge", queryItems: queryItems)
  }

  func fetchKnowledge(id: String) async throws -> DashboardKnowledge {
    try await request(path: "knowledge/\(id)")
  }

  func createKnowledge(_ draft: DashboardKnowledgeDraft) async throws -> DashboardKnowledge {
    try await request(method: "POST", path: "knowledge", body: draft)
  }

  func updateKnowledge(
    id: String,
    draft: DashboardKnowledgeDraft
  ) async throws -> DashboardKnowledge {
    try await request(method: "PATCH", path: "knowledge/\(id)", body: draft)
  }

  func deleteKnowledge(id: String) async throws {
    let _: EmptyResponse = try await request(method: "DELETE", path: "knowledge/\(id)")
  }

  func generateUploadURL(
    _ payload: DashboardSignedUploadRequest
  ) async throws -> DashboardSignedUploadResponse {
    try await request(method: "POST", path: "uploads/sign-url", body: payload)
  }

  func upload(
    data: Data,
    using signedUpload: DashboardSignedUploadResponse
  ) async throws {
    var request = URLRequest(url: signedUpload.uploadURL)
    request.httpMethod = "PUT"
    request.httpBody = data
    request.setValue(signedUpload.contentType, forHTTPHeaderField: "Content-Type")

    let (_, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
      throw DashboardAPIError.invalidResponse
    }
  }

  private func request<Response: Decodable>(
    method: String = "GET",
    path: String,
    queryItems: [URLQueryItem] = []
  ) async throws -> Response {
    try await request(method: method, path: path, queryItems: queryItems, bodyData: nil)
  }

  private func request<Response: Decodable, Body: Encodable>(
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

  private func request<Response: Decodable>(
    method: String,
    path: String,
    queryItems: [URLQueryItem],
    bodyData: Data?
  ) async throws -> Response {
    guard configuration.trimmedPrivateAPIKey.hasPrefix("sk_") else {
      throw DashboardAPIError.invalidPrivateAPIKey
    }

    guard let baseURL = configuration.apiBaseURL else {
      throw DashboardAPIError.invalidBaseURL
    }

    let resourceURL = baseURL.appending(path: path)
    guard var components = URLComponents(url: resourceURL, resolvingAgainstBaseURL: false) else {
      throw DashboardAPIError.invalidBaseURL
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
      throw DashboardAPIError.invalidBaseURL
    }

    print("[API]", method, url.absoluteString)

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
      throw DashboardAPIError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      let payload = try? decoder.decode(DashboardAPIError.ErrorPayload.self, from: data)
      throw DashboardAPIError.server(
        statusCode: httpResponse.statusCode,
        message: payload?.message ?? payload?.error ?? "Unexpected API error"
      )
    }

    do {
      if data.isEmpty, Response.self == EmptyResponse.self {
        return EmptyResponse() as! Response
      }

      return try decoder.decode(Response.self, from: data)
    } catch {
      throw DashboardAPIError.invalidResponse
    }
  }
}
