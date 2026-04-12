import Foundation

struct DashboardVisitor: Identifiable, Decodable, Hashable, Sendable {
  let id: String
  let browser: String?
  let browserVersion: String?
  let os: String?
  let osVersion: String?
  let device: String?
  let deviceType: String?
  let ip: String?
  let city: String?
  let region: String?
  let country: String?
  let countryCode: String?
  let latitude: Double?
  let longitude: Double?
  let language: String?
  let timezone: String?
  let screenResolution: String?
  let viewport: String?
  let createdAt: String
  let updatedAt: String
  let lastSeenAt: String?
  let websiteId: String
  let organizationId: String
  let blockedAt: String?
  let blockedByUserId: String?
  let isBlocked: Bool
  let attribution: JSONValue?
  let currentPage: JSONValue?
  let contact: DashboardContact?
}

struct DashboardVisitorUpdateRequest: Encodable, Sendable {
  var browser: String?
  var browserVersion: String?
  var os: String?
  var osVersion: String?
  var device: String?
  var deviceType: String?
  var ip: String?
  var city: String?
  var region: String?
  var country: String?
  var countryCode: String?
  var latitude: Double?
  var longitude: Double?
  var language: String?
  var timezone: String?
  var screenResolution: String?
  var viewport: String?
  var attribution: JSONValue?
  var currentPage: JSONValue?
}

struct DashboardVisitorMetadataUpdateRequest: Encodable, Sendable {
  let metadata: DashboardMetadata
}
