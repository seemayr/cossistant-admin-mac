import Foundation

enum DashboardUploadScope: Sendable {
  case conversation(organizationId: String, websiteId: String, conversationId: String)
  case user(organizationId: String, websiteId: String, userId: String)
  case contact(organizationId: String, websiteId: String, contactId: String)
  case visitor(organizationId: String, websiteId: String, visitorId: String)
}

extension DashboardUploadScope: Encodable {
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .conversation(let organizationId, let websiteId, let conversationId):
      try container.encode("conversation", forKey: .type)
      try container.encode(organizationId, forKey: .organizationId)
      try container.encode(websiteId, forKey: .websiteId)
      try container.encode(conversationId, forKey: .conversationId)
    case .user(let organizationId, let websiteId, let userId):
      try container.encode("user", forKey: .type)
      try container.encode(organizationId, forKey: .organizationId)
      try container.encode(websiteId, forKey: .websiteId)
      try container.encode(userId, forKey: .userId)
    case .contact(let organizationId, let websiteId, let contactId):
      try container.encode("contact", forKey: .type)
      try container.encode(organizationId, forKey: .organizationId)
      try container.encode(websiteId, forKey: .websiteId)
      try container.encode(contactId, forKey: .contactId)
    case .visitor(let organizationId, let websiteId, let visitorId):
      try container.encode("visitor", forKey: .type)
      try container.encode(organizationId, forKey: .organizationId)
      try container.encode(websiteId, forKey: .websiteId)
      try container.encode(visitorId, forKey: .visitorId)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case organizationId
    case websiteId
    case conversationId
    case userId
    case contactId
    case visitorId
  }
}

struct DashboardSignedUploadRequest: Encodable, Sendable {
  let contentType: String
  let websiteId: String
  let scope: DashboardUploadScope
  var path: String?
  var fileName: String?
  var fileExtension: String?
  var useCdn: Bool?
  var expiresInSeconds: Int?
}

struct DashboardSignedUploadResponse: Decodable, Hashable, Sendable {
  let uploadURL: URL
  let key: String
  let bucket: String
  let expiresAt: String
  let contentType: String
  let publicURL: URL

  enum CodingKeys: String, CodingKey {
    case uploadURL = "uploadUrl"
    case key
    case bucket
    case expiresAt
    case contentType
    case publicURL = "publicUrl"
  }
}
