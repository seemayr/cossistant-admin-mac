import Foundation

enum DashboardKnowledgeType: String, Codable, CaseIterable, Identifiable, Sendable {
  case url
  case faq
  case article

  var id: String { rawValue }

  var label: String {
    switch self {
    case .url:
      "URL"
    case .faq:
      "FAQ"
    case .article:
      "Article"
    }
  }
}

struct DashboardPaginationMetadata: Decodable, Hashable, Sendable {
  let page: Int
  let limit: Int
  let total: Int
  let hasMore: Bool
}

struct DashboardKnowledgeListResponse: Decodable, Sendable {
  let items: [DashboardKnowledge]
  let pagination: DashboardPaginationMetadata
}

struct DashboardKnowledge: Identifiable, Decodable, Hashable, Sendable {
  let id: String
  let organizationId: String
  let websiteId: String
  let aiAgentId: String?
  let linkSourceId: String?
  let type: DashboardKnowledgeType
  let sourceUrl: URL?
  let sourceTitle: String?
  let origin: String
  let createdBy: String
  let contentHash: String
  let payload: JSONValue
  let metadata: DashboardMetadata?
  let isIncluded: Bool
  let sizeBytes: Int
  let createdAt: String
  let updatedAt: String
  let deletedAt: String?

  var titleText: String {
    sourceTitle ?? sourceUrl?.absoluteString ?? id
  }

  var createdAbsoluteText: String {
    DashboardTimestampParser.absoluteString(from: createdAt) ?? createdAt
  }

  var updatedAbsoluteText: String {
    DashboardTimestampParser.absoluteString(from: updatedAt) ?? updatedAt
  }

  var faqPayload: DashboardFAQKnowledgePayload? {
    payload.dashboardDecoded(as: DashboardFAQKnowledgePayload.self)
  }

  var articlePayload: DashboardArticleKnowledgePayload? {
    payload.dashboardDecoded(as: DashboardArticleKnowledgePayload.self)
  }

  var urlPayload: DashboardURLKnowledgePayload? {
    payload.dashboardDecoded(as: DashboardURLKnowledgePayload.self)
  }
}

struct DashboardKnowledgeDraft: Encodable, Sendable {
  var aiAgentId: String?
  var type: DashboardKnowledgeType
  var sourceUrl: URL?
  var sourceTitle: String?
  var origin: String
  var payload: JSONValue
  var metadata: DashboardMetadata?
}

enum DashboardKnowledgeIncludedFilter: String, CaseIterable, Identifiable, Sendable {
  case all
  case included
  case excluded

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      "All"
    case .included:
      "Included"
    case .excluded:
      "Excluded"
    }
  }

  var queryValue: String? {
    switch self {
    case .all:
      nil
    case .included:
      "true"
    case .excluded:
      "false"
    }
  }
}
