import Foundation

extension CossistantAPIClient {
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
}
