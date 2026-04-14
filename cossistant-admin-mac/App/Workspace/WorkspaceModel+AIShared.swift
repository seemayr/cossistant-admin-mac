import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  func fetchAIMessageItems(
    conversationID: String,
    client: CossistantAdminClient,
    maxPages: Int
  ) async throws -> [DashboardTimelineItem] {
    var collectedItems: [DashboardTimelineItem] = []
    var seenIDs = Set<String>()
    var cursor: String?
    var pageCount = 0

    print("[AIMessageFetch]", "Starting timeline fetch for conversation \(conversationID) maxPages=\(maxPages)")

    repeat {
      try Task.checkCancellation()
      let page: DashboardTimelinePage
      do {
        page = try await client.conversations.fetchTimeline(
          conversationID: conversationID,
          limit: 100,
          cursor: cursor
        )
      } catch {
        let nsError = error as NSError
        print(
          "[AIMessageFetch]",
          "Timeline fetch failed for conversation \(conversationID) on page \(pageCount + 1) cursor \(cursor ?? "nil"): domain=\(nsError.domain) code=\(nsError.code) message=\(nsError.localizedDescription)"
        )
        throw error
      }

      for item in page.items where item.type == .message && item.deletedAt == nil {
        if seenIDs.insert(item.id).inserted {
          collectedItems.append(item)
        }
      }

      cursor = page.nextCursor
      pageCount += 1
    } while cursor != nil && pageCount < maxPages

    print(
      "[AIMessageFetch]",
      "Finished timeline fetch for conversation \(conversationID) pages=\(pageCount) messages=\(collectedItems.count)"
    )

    return collectedItems.sorted {
      ($0.createdAtDate ?? .distantPast) < ($1.createdAtDate ?? .distantPast)
    }
  }
}
