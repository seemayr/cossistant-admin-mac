import Foundation

typealias DashboardMetadata = [String: JSONValue]

struct DashboardContactListResponse: Decodable, Sendable {
  let items: [DashboardContactListItem]
  let page: Int
  let pageSize: Int
  let totalCount: Int
}

struct DashboardContactListItem: Identifiable, Decodable, Hashable, Sendable {
  let id: String
  let name: String?
  let email: String?
  let image: URL?
  let createdAt: String
  let updatedAt: String
  let visitorCount: Int
  let lastSeenAt: String?
  let contactOrganizationId: String?
  let contactOrganizationName: String?

  var displayName: String {
    DashboardIdentity.contactDisplayName(
      name: name,
      email: email,
      contactID: id
    )
  }

  var avatarSeed: String {
    email ?? id
  }

  var createdAtDate: Date? {
    DashboardTimestampParser.date(from: createdAt)
  }

  var updatedAtDate: Date? {
    DashboardTimestampParser.date(from: updatedAt)
  }

  var lastSeenAtDate: Date? {
    DashboardTimestampParser.date(from: lastSeenAt)
  }

  var createdRelativeText: String {
    DashboardTimestampParser.relativeString(from: createdAt) ?? createdAt
  }

  var lastSeenRelativeText: String {
    DashboardTimestampParser.relativeString(from: lastSeenAt) ?? "Not seen yet"
  }

  var createdAbsoluteText: String {
    DashboardTimestampParser.absoluteString(from: createdAt) ?? createdAt
  }

  var updatedAbsoluteText: String {
    DashboardTimestampParser.absoluteString(from: updatedAt) ?? updatedAt
  }

  var lastSeenAbsoluteText: String {
    DashboardTimestampParser.absoluteString(from: lastSeenAt) ?? "Not seen yet"
  }
}

struct DashboardContact: Identifiable, Decodable, Hashable, Sendable {
  let id: String
  let externalId: String?
  let name: String?
  let email: String?
  let image: URL?
  let metadata: DashboardMetadata?
  let contactOrganizationId: String?
  let websiteId: String
  let organizationId: String
  let userId: String?
  let createdAt: String
  let updatedAt: String

  var displayName: String {
    DashboardIdentity.contactDisplayName(
      name: name,
      email: email,
      contactID: id
    )
  }

  var avatarSeed: String {
    email ?? id
  }

  var createdAbsoluteText: String {
    DashboardTimestampParser.absoluteString(from: createdAt) ?? createdAt
  }

  var updatedAbsoluteText: String {
    DashboardTimestampParser.absoluteString(from: updatedAt) ?? updatedAt
  }
}

struct DashboardContactDraft: Encodable, Sendable {
  var externalId: String?
  var name: String?
  var email: String?
  var image: URL?
  var metadata: DashboardMetadata?
  var contactOrganizationId: String?
}

struct DashboardContactMetadataUpdateRequest: Encodable, Sendable {
  let metadata: DashboardMetadata
}

struct DashboardIdentifyContactRequest: Encodable, Sendable {
  var id: String?
  var visitorId: String
  var externalId: String?
  var name: String?
  var email: String?
  var image: URL?
  var metadata: DashboardMetadata?
  var contactOrganizationId: String?
}

struct DashboardIdentifyContactResponse: Decodable, Sendable {
  let contact: DashboardContact
  let visitorId: String
}

struct DashboardContactOrganization: Identifiable, Decodable, Hashable, Sendable {
  let id: String
  let name: String
  let externalId: String?
  let domain: String?
  let description: String?
  let metadata: DashboardMetadata?
  let websiteId: String
  let organizationId: String
  let createdAt: String
  let updatedAt: String
}

struct DashboardContactOrganizationDraft: Encodable, Sendable {
  var name: String?
  var externalId: String?
  var domain: String?
  var description: String?
  var metadata: DashboardMetadata?
}

enum DashboardContactSortBy: String, CaseIterable, Identifiable, Sendable {
  case name
  case email
  case createdAt
  case updatedAt
  case visitorCount
  case lastSeenAt

  var id: String { rawValue }

  var label: String {
    switch self {
    case .name:
      return "Name"
    case .email:
      return "Email"
    case .createdAt:
      return "Created"
    case .updatedAt:
      return "Updated"
    case .visitorCount:
      return "Visit Count"
    case .lastSeenAt:
      return "Last Seen"
    }
  }
}

enum DashboardSortOrder: String, CaseIterable, Identifiable, Sendable {
  case asc
  case desc

  var id: String { rawValue }

  var label: String {
    switch self {
    case .asc:
      return "Ascending"
    case .desc:
      return "Descending"
    }
  }
}

enum DashboardContactVisitorStatus: String, CaseIterable, Identifiable, Sendable {
  case all
  case withVisitors
  case withoutVisitors

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      return "All"
    case .withVisitors:
      return "With Visitors"
    case .withoutVisitors:
      return "Without Visitors"
    }
  }
}
