import Foundation

extension CossistantAPIClient {
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
}
