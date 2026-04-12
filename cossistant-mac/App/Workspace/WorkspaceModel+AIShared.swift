import Foundation

@MainActor
extension WorkspaceModel {
  func fetchAIMessageItems(
    conversationID: String,
    client: CossistantAPIClient,
    maxPages: Int
  ) async throws -> [DashboardTimelineItem] {
    var collectedItems: [DashboardTimelineItem] = []
    var seenIDs = Set<String>()
    var cursor: String?
    var pageCount = 0

    repeat {
      try Task.checkCancellation()
      let page = try await client.fetchTimeline(
        conversationID: conversationID,
        limit: 100,
        cursor: cursor
      )

      for item in page.items where item.type == .message && item.deletedAt == nil {
        if seenIDs.insert(item.id).inserted {
          collectedItems.append(item)
        }
      }

      cursor = page.nextCursor
      pageCount += 1
    } while cursor != nil && pageCount < maxPages

    return collectedItems.sorted {
      ($0.createdAtDate ?? .distantPast) < ($1.createdAtDate ?? .distantPast)
    }
  }
}
