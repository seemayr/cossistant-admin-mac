import SwiftUI
import CossistantAdmin

struct ConversationStatisticsWorkspaceView: View {
  @Bindable var store: InboxStore

  private var overview: ConversationStatisticsOverview {
    ConversationStatisticsOverview(conversations: store.conversations)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("Statistics")
          .font(.title.weight(.semibold))

        snapshotCard

        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 320), spacing: 20, alignment: .top)],
          alignment: .leading,
          spacing: 20
        ) {
          ForEach(overview.windows) { window in
            ConversationStatisticsWindowCard(window: window)
          }
        }
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
      .textSelection(.enabled)
    }
  }

  private var snapshotCard: some View {
    PrototypeInfoCard(title: "Loaded Snapshot") {
      PrototypeFact(label: "Fetched Conversations", value: overview.fetchedConversationCount.formatted(.number))
      PrototypeFact(label: "Non-Empty Conversations", value: overview.nonEmptyConversationCount.formatted(.number))
      PrototypeFact(label: "Loaded Pages", value: store.loadedPageCount.formatted(.number))
    }
  }
}

private struct ConversationStatisticsWindowCard: View {
  let window: ConversationStatisticsWindow

  var body: some View {
    PrototypeInfoCard(title: window.range.title) {
      Text(window.range.subtitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(window.totalCount.formatted(.number))
          .font(.system(size: 34, weight: .semibold, design: .rounded))

        Text("non-empty conversations")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 12) {
        ConversationStatisticsStatusBadge(
          title: "Resolved",
          count: window.resolvedCount,
          tint: .secondary
        )

        ConversationStatisticsStatusBadge(
          title: "Unresolved",
          count: window.unresolvedCount,
          tint: .blue
        )
      }

      Divider()

      Text("Priority Breakdown")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      if window.totalCount == 0 {
        Text("No non-empty conversations in this range.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        VStack(alignment: .leading, spacing: 10) {
          HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Priority")
              .frame(maxWidth: .infinity, alignment: .leading)

            Text("Total")
              .frame(minWidth: 40, alignment: .trailing)

            Text("Resolved / Unresolved")
              .frame(minWidth: 120, alignment: .trailing)
          }
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

          ForEach(window.priorityRows) { row in
            ConversationStatisticsPriorityRowView(row: row)
          }
        }
      }
    }
  }
}

private struct ConversationStatisticsStatusBadge: View {
  let title: String
  let count: Int
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      Text(count.formatted(.number))
        .font(.title3.weight(.semibold))
        .foregroundStyle(tint)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

private struct ConversationStatisticsPriorityRowView: View {
  let row: ConversationStatisticsPriorityRow

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Circle()
        .fill(row.priority.tint)
        .frame(width: 8, height: 8)

      Text(row.priority.label)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text(row.totalCount.formatted(.number))
        .font(.body.monospacedDigit())
        .frame(minWidth: 40, alignment: .trailing)

      Text("\(row.resolvedCount.formatted(.number)) / \(row.unresolvedCount.formatted(.number))")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(minWidth: 120, alignment: .trailing)
    }
  }
}

private struct ConversationStatisticsOverview {
  let fetchedConversationCount: Int
  let nonEmptyConversationCount: Int
  let windows: [ConversationStatisticsWindow]

  init(conversations: [DashboardConversation], now: Date = .now) {
    let nonEmptyConversations = conversations.filter(\.hasContent)

    fetchedConversationCount = conversations.count
    nonEmptyConversationCount = nonEmptyConversations.count
    windows = ConversationStatisticsRange.allCases.map {
      ConversationStatisticsWindow(
        range: $0,
        sourceConversations: nonEmptyConversations,
        now: now
      )
    }
  }

  func window(with range: ConversationStatisticsRange) -> ConversationStatisticsWindow {
    windows.first(where: { $0.range == range }) ?? ConversationStatisticsWindow(
      range: range,
      sourceConversations: [],
      now: .now
    )
  }
}

private struct ConversationStatisticsWindow: Identifiable {
  let range: ConversationStatisticsRange
  let conversations: [DashboardConversation]
  let resolvedCount: Int
  let unresolvedCount: Int
  let priorityRows: [ConversationStatisticsPriorityRow]

  var id: ConversationStatisticsRange { range }
  var totalCount: Int { conversations.count }

  init(
    range: ConversationStatisticsRange,
    sourceConversations: [DashboardConversation],
    now: Date
  ) {
    let cutoffDate = now.addingTimeInterval(-range.lookbackInterval)
    let matchingConversations = sourceConversations.filter { conversation in
      guard let createdAtDate = conversation.createdAtDate else { return false }
      return createdAtDate >= cutoffDate
    }

    self.range = range
    conversations = matchingConversations
    resolvedCount = matchingConversations.filter { $0.status == .resolved }.count
    unresolvedCount = matchingConversations.count - resolvedCount
    priorityRows = ConversationStatisticsPriorityRow.all(from: matchingConversations)
  }
}

private struct ConversationStatisticsPriorityRow: Identifiable {
  let priority: DashboardConversation.Priority
  let totalCount: Int
  let resolvedCount: Int
  let unresolvedCount: Int

  var id: DashboardConversation.Priority { priority }

  static func all(from conversations: [DashboardConversation]) -> [ConversationStatisticsPriorityRow] {
    ConversationStatisticsRange.priorityDisplayOrder.map { priority in
      let priorityConversations = conversations.filter { $0.priority == priority }
      let resolvedCount = priorityConversations.filter { $0.status == .resolved }.count

      return ConversationStatisticsPriorityRow(
        priority: priority,
        totalCount: priorityConversations.count,
        resolvedCount: resolvedCount,
        unresolvedCount: priorityConversations.count - resolvedCount
      )
    }
  }
}

private enum ConversationStatisticsRange: String, CaseIterable, Identifiable {
  case last24Hours
  case last7Days

  static let priorityDisplayOrder: [DashboardConversation.Priority] = [.urgent, .high, .normal, .low]

  var id: String { rawValue }

  var title: String {
    switch self {
    case .last24Hours:
      "Last 24 Hours"
    case .last7Days:
      "Last 7 Days"
    }
  }

  var subtitle: String {
    switch self {
    case .last24Hours:
      "Created in the last 24 hours"
    case .last7Days:
      "Created in the last 7 days"
    }
  }

  var lookbackInterval: TimeInterval {
    switch self {
    case .last24Hours:
      24 * 60 * 60
    case .last7Days:
      7 * 24 * 60 * 60
    }
  }
}
