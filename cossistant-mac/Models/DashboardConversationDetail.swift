import Foundation

struct DashboardConversationResponse: Decodable, Sendable {
  let conversation: DashboardConversationDetail
}

struct DashboardConversationDetail: Identifiable, Decodable, Hashable, Sendable {
  let id: String
  let title: String?
  let metadata: DashboardMetadata?
  let createdAt: String
  let updatedAt: String
  let visitorId: String
  let websiteId: String
  let status: DashboardConversation.Status
  let visitorRating: Int?
  let visitorRatingAt: String?
  let deletedAt: String?
  let visitorLastSeenAt: String?
  let lastTimelineItem: DashboardTimelineItem?

  var updatedAtDate: Date? {
    DashboardTimestampParser.date(from: updatedAt)
  }

  var updatedRelativeText: String {
    guard let updatedAtDate else { return updatedAt }
    return RelativeDateTimeFormatter.dashboard.localizedString(for: updatedAtDate, relativeTo: .now)
  }
}
