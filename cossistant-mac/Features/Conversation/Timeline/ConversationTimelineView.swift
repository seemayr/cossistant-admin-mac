import SwiftUI
import SFSafeSymbols

enum ConversationTimelineLayout {
  static let threadMaxWidth: CGFloat = 760
  static let messageMaxWidth: CGFloat = 620
  static let activityMaxWidth: CGFloat = 520
  static let developerLogMaxWidth: CGFloat = 320
  static let sideSpacer: CGFloat = 88
}

struct ConversationTimelineView: View {
  let website: DashboardWebsite?
  let conversation: DashboardConversation
  let visitor: DashboardVisitor?
  let items: [DashboardTimelineItem]
  let seenData: [DashboardConversationSeen]
  let translatedMessagesByID: [String: DashboardMessageTranslation]
  let showDeveloperLogs: Bool
  let canLoadMoreTimeline: Bool
  let isLoadingMoreTimeline: Bool
  let onLoadMoreTimeline: () -> Void

  private var renderables: [DashboardTimelineRenderable] {
    DashboardTimelinePresentation.build(
      items: items,
      includeDeveloperLogs: showDeveloperLogs
    )
  }

  private var latestSeenEligibleItemID: String? {
    items
      .sorted { ($0.createdAtDate ?? .distantPast) < ($1.createdAtDate ?? .distantPast) }
      .last {
        $0.type == .message
          && $0.visibility == .public
          && !$0.isPrivateNote
          && ($0.userId != nil || $0.aiAgentId != nil)
      }?
      .id
  }

  private var seenReceipts: [TimelineSeenReceiptDisplay] {
    seenData
      .compactMap { item in
        TimelineSeenReceiptDisplay(
          seen: item,
          website: website
        )
      }
      .filter { $0.role != .person || $0.actorID != conversation.visitorId }
      .sorted { $0.lastSeenDate > $1.lastSeenDate }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      ForEach(renderables) { renderable in
        switch renderable {
        case .day(let marker):
          TimelineDaySeparatorView(date: marker.date)
        case .group(let group):
          groupView(group)
        }
      }

      if canLoadMoreTimeline {
        Button(action: onLoadMoreTimeline) {
          Label(
            isLoadingMoreTimeline ? "Loading more…" : "Load older activity",
            systemSymbol: .ellipsisCircle
          )
        }
        .buttonStyle(.borderless)
        .disabled(isLoadingMoreTimeline)
        .padding(.top, 6)
      }
    }
    .frame(maxWidth: ConversationTimelineLayout.threadMaxWidth, alignment: .leading)
  }

  @ViewBuilder
  private func groupView(_ group: DashboardTimelineGroup) -> some View {
    switch group.style {
    case .message:
      TimelineMessageGroupView(
        group: group,
        sender: senderDisplay(for: group.sender),
        translatedMessagesByID: translatedMessagesByID,
        seenReceipts: group.items.last?.id == latestSeenEligibleItemID ? seenReceipts : []
      )
    case .publicActivity:
      TimelineActivityGroupView(
        group: group,
        sender: senderDisplay(for: group.sender),
        website: website,
        conversation: conversation,
        visitor: visitor
      )
    case .developerLog:
      TimelineDeveloperLogGroupView(
        group: group,
        sender: senderDisplay(for: group.sender)
      )
    }
  }

  private func senderDisplay(for sender: DashboardTimelineSender) -> DashboardTimelineSenderDisplay {
    DashboardTimelinePresentation.senderDisplay(
      for: sender,
      website: website,
      conversation: conversation,
      visitor: visitor
    )
  }
}

private struct TimelineDaySeparatorView: View {
  let date: Date

  var body: some View {
    HStack(spacing: 12) {
      Rectangle()
        .fill(.separator.opacity(0.5))
        .frame(height: 1)

      Text(labelText)
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)

      Rectangle()
        .fill(.separator.opacity(0.5))
        .frame(height: 1)
    }
    .padding(.vertical, 4)
  }

  private var labelText: String {
    let calendar = Calendar.current

    if calendar.isDateInToday(date) {
      return "Today"
    }

    if calendar.isDateInYesterday(date) {
      return "Yesterday"
    }

    return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
  }
}
