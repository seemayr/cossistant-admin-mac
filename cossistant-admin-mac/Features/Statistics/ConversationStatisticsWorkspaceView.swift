import Charts
import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct ConversationStatisticsWorkspaceView: View {
  @Bindable var store: InboxStore
  let workspaceChannelFilter: String?
  @State private var filters = ConversationStatisticsFilters()

  private var overview: ConversationStatisticsOverview {
    ConversationStatisticsOverview(
      conversations: store.conversations,
      filters: filters
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("Statistics")
          .font(.title.weight(.semibold))

        filtersCard
        snapshotCard

        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 360), spacing: 20, alignment: .top)],
          alignment: .leading,
          spacing: 20
        ) {
          ConversationStatisticsTimelineCard(
            breakdown: filters.volumeBreakdown,
            rows: overview.timelineRows
          )
          ConversationStatisticsCategoryCard(rows: overview.categoryRows)
          ConversationStatisticsBreakdownCard(
            title: "Sources",
            emptyText: "No source metadata found for the current filter.",
            rows: overview.sourceRows,
            tint: .teal
          )
          ConversationStatisticsBreakdownCard(
            title: "App Versions",
            emptyText: "No app version metadata found for the current filter.",
            rows: overview.appVersionRows,
            tint: .indigo
          )
          ConversationStatisticsBreakdownCard(
            title: "Games",
            emptyText: "No game ID metadata found for the current filter.",
            rows: overview.gameRows,
            tint: .pink
          )
          ConversationStatisticsBreakdownCard(
            title: "Group Coverage",
            emptyText: "No conversations match the current filter.",
            rows: overview.groupRows,
            tint: .cyan
          )
          ConversationStatisticsBreakdownCard(
            title: "Auth Identity",
            emptyText: "No conversations match the current filter.",
            rows: overview.authIdentityRows,
            tint: .mint
          )
          ConversationStatisticsStatusCard(rows: overview.statusRows)
          ConversationStatisticsPriorityCard(rows: overview.priorityRows)
          ConversationStatisticsChannelCard(rows: overview.channelRows)
          ConversationStatisticsSentimentCard(rows: overview.sentimentRows)
          ConversationStatisticsAttentionCard(rows: overview.attentionRows)

          ForEach(overview.windows) { window in
            ConversationStatisticsWindowCard(window: window)
          }
        }
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
      .textSelection(.enabled)
    }
    .onAppear {
      filters.applyWorkspaceChannelFilter(workspaceChannelFilter)
    }
    .onChange(of: workspaceChannelFilter) { _, channelFilter in
      filters.applyWorkspaceChannelFilter(channelFilter)
    }
  }

  private var filtersCard: some View {
    PrototypeInfoCard(title: "Filters") {
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 190), spacing: 10, alignment: .leading)],
        alignment: .leading,
        spacing: 10
      ) {
        filterMenu(
          title: "Range",
          value: filters.dateRange.label,
          systemImage: .calendar
        ) {
          Picker("Range", selection: $filters.dateRange) {
            ForEach(ConversationStatisticsDateRange.allCases) { range in
              Text(range.label)
                .tag(range)
            }
          }
        }

        filterMenu(
          title: "Date",
          value: filters.dateBasis.label,
          systemImage: .clock
        ) {
          Picker("Date", selection: $filters.dateBasis) {
            ForEach(ConversationStatisticsDateBasis.allCases) { basis in
              Text(basis.label)
                .tag(basis)
            }
          }
        }

        filterMenu(
          title: "Status",
          value: filters.status.label,
          systemImage: .checkmarkCircle
        ) {
          Picker("Status", selection: $filters.status) {
            ForEach(ConversationStatisticsStatusFilter.allCases) { status in
              Text(status.label)
                .tag(status)
            }
          }
        }

        filterMenu(
          title: "Priority",
          value: filters.priority.label,
          systemImage: .flag
        ) {
          Picker("Priority", selection: $filters.priority) {
            ForEach(InboxPriorityFilter.allCases) { priority in
              Text(priority.label)
                .tag(priority)
            }
          }
        }

        filterMenu(
          title: "Sentiment",
          value: filters.sentiment.label,
          systemImage: .faceSmiling
        ) {
          Picker("Sentiment", selection: $filters.sentiment) {
            ForEach(InboxSentimentFilter.allCases) { sentiment in
              Text(sentiment.label)
                .tag(sentiment)
            }
          }
        }

        filterMenu(
          title: "Volume",
          value: filters.volumeBreakdown.label,
          systemImage: .chartBar
        ) {
          Picker("Volume Breakdown", selection: $filters.volumeBreakdown) {
            ForEach(ConversationStatisticsVolumeBreakdown.allCases) { breakdown in
              Text(breakdown.label)
                .tag(breakdown)
            }
          }
        }

        optionMenu(
          title: "Channel",
          value: filters.channel,
          fallbackValue: "Any Channel",
          systemImage: .bubbleLeftAndBubbleRight,
          options: overview.availableChannels
        ) { channel in
          filters.channel = channel
        }

        optionMenu(
          title: "Category",
          value: filters.category,
          fallbackValue: "Any Category",
          systemImage: .tag,
          options: overview.availableCategories
        ) { category in
          filters.category = category
        }

        optionMenu(
          title: "Source",
          value: filters.source,
          fallbackValue: "Any Source",
          systemImage: .trayFull,
          options: overview.availableSources
        ) { source in
          filters.source = source
        }

        optionMenu(
          title: "App Version",
          value: filters.appVersion,
          fallbackValue: "Any Version",
          systemImage: .shippingbox,
          options: overview.availableAppVersions
        ) { appVersion in
          filters.appVersion = appVersion
        }

        optionMenu(
          title: "Game",
          value: filters.gameID,
          fallbackValue: "Any Game",
          systemImage: .gamecontroller,
          options: overview.availableGameIDs
        ) { gameID in
          filters.gameID = gameID
        }
      }

      Divider()

      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 190), spacing: 10, alignment: .leading)],
        alignment: .leading,
        spacing: 8
      ) {
        Toggle("Non-empty conversations", isOn: $filters.isNonEmptyOnly)
        Toggle("Exclude archived", isOn: $filters.excludesArchived)
        Toggle("Unread only", isOn: $filters.isUnreadOnly)
        Toggle("Needs human", isOn: $filters.needsHumanOnly)
        Toggle("Needs clarification", isOn: $filters.needsClarificationOnly)
        Toggle("Has visitor rating", isOn: $filters.hasVisitorRatingOnly)
        Toggle("Has group ID", isOn: $filters.hasGroupIDOnly)
        Toggle("Has auth identity", isOn: $filters.hasAuthIdentityOnly)
      }
      .toggleStyle(.checkbox)

      HStack {
        Text(filterSummary)
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer()

        Button("Reset Filters") {
          filters = resetFilters
        }
        .buttonStyle(.borderless)
        .disabled(filters == resetFilters)
      }
    }
  }

  private var resetFilters: ConversationStatisticsFilters {
    var filters = ConversationStatisticsFilters()
    filters.applyWorkspaceChannelFilter(workspaceChannelFilter)
    return filters
  }

  private var snapshotCard: some View {
    PrototypeInfoCard(title: "Loaded Snapshot") {
      PrototypeFact(label: "Fetched Conversations", value: overview.fetchedConversationCount.formatted(.number))
      PrototypeFact(label: "Filtered Conversations", value: overview.filteredConversationCount.formatted(.number))
      PrototypeFact(label: "Non-Empty Filtered", value: overview.filteredNonEmptyConversationCount.formatted(.number))
      PrototypeFact(label: "Resolved", value: overview.resolvedCount.formatted(.number))
      PrototypeFact(label: "Open", value: overview.openCount.formatted(.number))
      PrototypeFact(label: "Resolution Rate", value: overview.resolutionRate.formatted(.percent.precision(.fractionLength(0))))
      PrototypeFact(label: "Loaded Pages", value: store.loadedPageCount.formatted(.number))
    }
  }

  private var filterSummary: String {
    "\(overview.filteredConversationCount.formatted(.number)) of \(overview.fetchedConversationCount.formatted(.number)) loaded conversations shown"
  }

  private func filterMenu<Content: View>(
    title: String,
    value: String,
    systemImage: SFSymbol,
    @ViewBuilder content: () -> Content
  ) -> some View {
    Menu {
      content()
    } label: {
      HeaderControlLabel(
        title: title,
        value: value,
        systemImage: systemImage
      )
    }
  }

  private func optionMenu(
    title: String,
    value: String?,
    fallbackValue: String,
    systemImage: SFSymbol,
    options: [String],
    onSelect: @escaping (String?) -> Void
  ) -> some View {
    Menu {
      Button {
        onSelect(nil)
      } label: {
        menuLabel(fallbackValue, isSelected: value == nil)
      }

      if !options.isEmpty {
        Divider()
      }

      ForEach(options, id: \.self) { option in
        Button {
          onSelect(option)
        } label: {
          menuLabel(option, isSelected: value == option)
        }
      }
    } label: {
      HeaderControlLabel(
        title: title,
        value: value ?? fallbackValue,
        systemImage: systemImage
      )
    }
  }

  private func menuLabel(_ title: String, isSelected: Bool) -> some View {
    Group {
      if isSelected {
        Label(title, systemSymbol: .checkmark)
      } else {
        Text(title)
      }
    }
  }
}

private struct ConversationStatisticsTimelineCard: View {
  let breakdown: ConversationStatisticsVolumeBreakdown
  let rows: [ConversationStatisticsTimelineRow]

  var body: some View {
    PrototypeInfoCard(title: "Conversation Volume") {
      Text("Grouped by \(breakdown.label.lowercased()).")
        .font(.caption)
        .foregroundStyle(.secondary)

      if rows.isEmpty {
        ConversationStatisticsEmptyChartView(text: "No conversations match the selected filters.")
      } else {
        Chart(rows) { row in
          BarMark(
            x: .value("Time", row.bucket),
            y: .value("Conversations", row.count)
          )
          .foregroundStyle(by: .value(breakdown.label, row.groupLabel))
        }
        .frame(height: 220)
        .chartLegend(position: .bottom, alignment: .leading)
      }
    }
  }
}

private struct ConversationStatisticsBreakdownCard: View {
  let title: String
  let emptyText: String
  let rows: [ConversationStatisticsBreakdownRow]
  let tint: Color

  var body: some View {
    PrototypeInfoCard(title: title) {
      if rows.isEmpty {
        ConversationStatisticsEmptyChartView(text: emptyText)
      } else {
        Chart(rows) { row in
          BarMark(
            x: .value("Conversations", row.count),
            y: .value(title, row.chartLabel)
          )
          .foregroundStyle(tint)
        }
        .frame(height: max(120, CGFloat(rows.count) * 26))
      }
    }
  }
}

private struct ConversationStatisticsCategoryCard: View {
  let rows: [ConversationStatisticsBreakdownRow]

  var body: some View {
    PrototypeInfoCard(title: "Categories") {
      if rows.isEmpty {
        ConversationStatisticsEmptyChartView(text: "No category metadata found for the current filter.")
      } else {
        Chart(rows) { row in
          BarMark(
            x: .value("Conversations", row.count),
            y: .value("Category", row.chartLabel)
          )
          .foregroundStyle(.purple)
        }
        .frame(height: max(120, CGFloat(rows.count) * 26))
      }
    }
  }
}

private struct ConversationStatisticsStatusCard: View {
  let rows: [ConversationStatisticsStatusRow]

  var body: some View {
    PrototypeInfoCard(title: "Status") {
      Chart(rows) { row in
        BarMark(
          x: .value("Status", row.status.label),
          y: .value("Conversations", row.count)
        )
        .foregroundStyle(row.status.tint)
      }
      .frame(height: 180)

      HStack(spacing: 12) {
        ForEach(rows) { row in
          ConversationStatisticsStatusBadge(
            title: row.status.label,
            count: row.count,
            tint: row.status.tint
          )
        }
      }
    }
  }
}

private struct ConversationStatisticsPriorityCard: View {
  let rows: [ConversationStatisticsPriorityRow]

  var body: some View {
    PrototypeInfoCard(title: "Priority") {
      Chart(rows) { row in
        BarMark(
          x: .value("Priority", row.priority.label),
          y: .value("Conversations", row.totalCount)
        )
        .foregroundStyle(row.priority.tint)
      }
      .frame(height: 180)

      VStack(alignment: .leading, spacing: 10) {
        ForEach(rows) { row in
          ConversationStatisticsPriorityRowView(row: row)
        }
      }
    }
  }
}

private struct ConversationStatisticsChannelCard: View {
  let rows: [ConversationStatisticsBreakdownRow]

  var body: some View {
    PrototypeInfoCard(title: "Channels") {
      if rows.isEmpty {
        ConversationStatisticsEmptyChartView(text: "No channel data for the current filter.")
      } else {
        Chart(rows) { row in
          BarMark(
            x: .value("Conversations", row.count),
            y: .value("Channel", row.chartLabel)
          )
          .foregroundStyle(.blue)
        }
        .frame(height: max(120, CGFloat(rows.count) * 26))
      }
    }
  }
}

private struct ConversationStatisticsSentimentCard: View {
  let rows: [ConversationStatisticsSentimentRow]

  var body: some View {
    PrototypeInfoCard(title: "Sentiment") {
      Chart(rows) { row in
        BarMark(
          x: .value("Sentiment", row.sentiment.label),
          y: .value("Conversations", row.count)
        )
      }
      .frame(height: 180)

      VStack(alignment: .leading, spacing: 8) {
        ForEach(rows) { row in
          ConversationStatisticsCompactRow(
            title: row.sentiment.label,
            value: row.count.formatted(.number)
          )
        }
      }
    }
  }
}

private struct ConversationStatisticsAttentionCard: View {
  let rows: [ConversationStatisticsBreakdownRow]

  var body: some View {
    PrototypeInfoCard(title: "Attention") {
      Chart(rows) { row in
        BarMark(
          x: .value("Conversations", row.count),
          y: .value("Reason", row.chartLabel)
        )
        .foregroundStyle(.orange)
      }
      .frame(height: max(120, CGFloat(rows.count) * 26))
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

        Text("filtered conversations")
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
        Text("No filtered conversations in this range.")
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

private struct ConversationStatisticsCompactRow: View {
  let title: String
  let value: String

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .lineLimit(1)

      Spacer()

      Text(value)
        .font(.body.monospacedDigit())
        .foregroundStyle(.secondary)
    }
  }
}

private struct ConversationStatisticsEmptyChartView: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .frame(height: 180)
      .frame(maxWidth: .infinity, alignment: .center)
  }
}

private struct ConversationStatisticsOverview {
  let fetchedConversationCount: Int
  let filteredConversationCount: Int
  let filteredNonEmptyConversationCount: Int
  let resolvedCount: Int
  let openCount: Int
  let resolutionRate: Double
  let availableChannels: [String]
  let availableCategories: [String]
  let availableSources: [String]
  let availableAppVersions: [String]
  let availableGameIDs: [String]
  let timelineRows: [ConversationStatisticsTimelineRow]
  let categoryRows: [ConversationStatisticsBreakdownRow]
  let sourceRows: [ConversationStatisticsBreakdownRow]
  let appVersionRows: [ConversationStatisticsBreakdownRow]
  let gameRows: [ConversationStatisticsBreakdownRow]
  let groupRows: [ConversationStatisticsBreakdownRow]
  let authIdentityRows: [ConversationStatisticsBreakdownRow]
  let statusRows: [ConversationStatisticsStatusRow]
  let priorityRows: [ConversationStatisticsPriorityRow]
  let channelRows: [ConversationStatisticsBreakdownRow]
  let sentimentRows: [ConversationStatisticsSentimentRow]
  let attentionRows: [ConversationStatisticsBreakdownRow]
  let windows: [ConversationStatisticsWindow]

  init(
    conversations: [DashboardConversation],
    filters: ConversationStatisticsFilters,
    now: Date = .now
  ) {
    let filteredConversations = conversations.filter {
      filters.includes($0, now: now)
    }

    fetchedConversationCount = conversations.count
    filteredConversationCount = filteredConversations.count
    filteredNonEmptyConversationCount = filteredConversations.filter(\.hasContent).count
    resolvedCount = filteredConversations.filter { $0.status == .resolved }.count
    openCount = filteredConversations.filter { $0.status == .open }.count
    resolutionRate = filteredConversations.isEmpty ? 0 : Double(resolvedCount) / Double(filteredConversations.count)
    availableChannels = Self.uniqueValues(from: conversations.map(\.statisticsChannelLabel))
    availableCategories = Self.uniqueValues(from: conversations.map(\.statisticsCategoryLabel))
    availableSources = Self.uniqueValues(from: conversations.map(\.statisticsSourceLabel))
    availableAppVersions = Self.uniqueValues(from: conversations.map(\.statisticsAppVersionLabel))
    availableGameIDs = Self.uniqueValues(from: conversations.map(\.statisticsGameIDLabel))
    timelineRows = ConversationStatisticsTimelineRow.all(
      from: filteredConversations,
      filters: filters,
      breakdown: filters.volumeBreakdown
    )
    categoryRows = ConversationStatisticsBreakdownRow.all(
      from: filteredConversations.map(\.statisticsCategoryLabel),
      excluding: "Uncategorized"
    )
    sourceRows = ConversationStatisticsBreakdownRow.all(
      from: filteredConversations.map(\.statisticsSourceLabel),
      excluding: "Unknown Source"
    )
    appVersionRows = ConversationStatisticsBreakdownRow.all(
      from: filteredConversations.map(\.statisticsAppVersionLabel),
      excluding: "Unknown Version"
    )
    gameRows = ConversationStatisticsBreakdownRow.all(
      from: filteredConversations.map(\.statisticsGameIDLabel),
      excluding: "Unknown Game"
    )
    groupRows = ConversationStatisticsBreakdownRow.all(
      from: filteredConversations.map(\.statisticsGroupPresenceLabel)
    )
    authIdentityRows = ConversationStatisticsBreakdownRow.all(
      from: filteredConversations.map(\.statisticsAuthIdentityPresenceLabel)
    )
    statusRows = ConversationStatisticsStatusRow.all(from: filteredConversations)
    priorityRows = ConversationStatisticsPriorityRow.all(from: filteredConversations)
    channelRows = ConversationStatisticsBreakdownRow.all(from: filteredConversations.map(\.statisticsChannelLabel))
    sentimentRows = ConversationStatisticsSentimentRow.all(from: filteredConversations)
    attentionRows = ConversationStatisticsBreakdownRow.all(
      from: filteredConversations.map(\.statisticsAttentionLabel)
    )
    windows = ConversationStatisticsRange.allCases.map {
      ConversationStatisticsWindow(
        range: $0,
        sourceConversations: filteredConversations,
        now: now
      )
    }
  }

  private static func uniqueValues(from values: [String]) -> [String] {
    values
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .reduce(into: Set<String>()) { result, value in
        result.insert(value)
      }
      .sorted {
        $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
      }
  }
}

private struct ConversationStatisticsFilters: Equatable {
  var dateRange: ConversationStatisticsDateRange = .all
  var dateBasis: ConversationStatisticsDateBasis = .created
  var status: ConversationStatisticsStatusFilter = .all
  var priority: InboxPriorityFilter = .all
  var sentiment: InboxSentimentFilter = .all
  var channel: String?
  var category: String?
  var source: String?
  var appVersion: String?
  var gameID: String?
  var volumeBreakdown: ConversationStatisticsVolumeBreakdown = .status
  var isNonEmptyOnly = true
  var excludesArchived = true
  var isUnreadOnly = false
  var needsHumanOnly = false
  var needsClarificationOnly = false
  var hasVisitorRatingOnly = false
  var hasGroupIDOnly = false
  var hasAuthIdentityOnly = false

  mutating func applyWorkspaceChannelFilter(_ channelFilter: String?) {
    channel = channelFilter
  }

  func includes(_ conversation: DashboardConversation, now: Date) -> Bool {
    if isNonEmptyOnly && !conversation.hasContent {
      return false
    }
    if excludesArchived && conversation.isArchived {
      return false
    }
    if isUnreadOnly && !conversation.hasUnreadActivity {
      return false
    }
    if needsHumanOnly && !conversation.needsHumanIntervention {
      return false
    }
    if needsClarificationOnly && !conversation.needsClarification {
      return false
    }
    if hasVisitorRatingOnly && conversation.visitorRating == nil {
      return false
    }
    if hasGroupIDOnly && !conversation.statisticsHasGroupID {
      return false
    }
    if hasAuthIdentityOnly && !conversation.statisticsHasAuthIdentity {
      return false
    }
    if !status.includes(conversation.status) {
      return false
    }
    if !priority.includes(conversation.priority) {
      return false
    }
    if !sentiment.includes(conversation.sentimentCategory) {
      return false
    }
    if let channel, conversation.statisticsChannelLabel != channel {
      return false
    }
    if let category, conversation.statisticsCategoryLabel != category {
      return false
    }
    if let source, conversation.statisticsSourceLabel != source {
      return false
    }
    if let appVersion, conversation.statisticsAppVersionLabel != appVersion {
      return false
    }
    if let gameID, conversation.statisticsGameIDLabel != gameID {
      return false
    }
    guard let cutoffDate = dateRange.cutoffDate(relativeTo: now) else {
      return true
    }
    guard let date = dateBasis.date(for: conversation) else {
      return false
    }
    return date >= cutoffDate
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

private struct ConversationStatisticsTimelineRow: Identifiable {
  let bucket: Date
  let groupLabel: String
  let count: Int

  var id: String {
    "\(bucket.timeIntervalSince1970)-\(groupLabel)"
  }

  static func all(
    from conversations: [DashboardConversation],
    filters: ConversationStatisticsFilters,
    breakdown: ConversationStatisticsVolumeBreakdown,
    calendar: Calendar = .current
  ) -> [ConversationStatisticsTimelineRow] {
    let source = conversations.compactMap { conversation -> (bucket: Date, group: String)? in
      guard let date = filters.dateBasis.date(for: conversation) else { return nil }
      return (
        bucket: filters.dateRange.timelineBucket(for: date, calendar: calendar),
        group: breakdown.label(for: conversation)
      )
    }

    let grouped = Dictionary(grouping: source) {
      ConversationStatisticsTimelineKey(bucket: $0.bucket, group: $0.group)
    }

    return grouped
      .map {
        ConversationStatisticsTimelineRow(
          bucket: $0.key.bucket,
          groupLabel: $0.key.group,
          count: $0.value.count
        )
      }
      .sorted {
        if $0.bucket == $1.bucket {
          return $0.groupLabel < $1.groupLabel
        }
        return $0.bucket < $1.bucket
      }
  }
}

private struct ConversationStatisticsTimelineKey: Hashable {
  let bucket: Date
  let group: String
}

private struct ConversationStatisticsBreakdownRow: Identifiable {
  let label: String
  let count: Int

  var id: String { label }
  var chartLabel: String { "\(label) (\(count.formatted(.number)))" }

  static func all(
    from values: [String],
    excluding excludedValue: String? = nil
  ) -> [ConversationStatisticsBreakdownRow] {
    Dictionary(grouping: values, by: { $0 })
      .compactMap { label, values in
        guard label != excludedValue else { return nil }
        return ConversationStatisticsBreakdownRow(label: label, count: values.count)
      }
      .sorted {
        if $0.count == $1.count {
          return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }
        return $0.count > $1.count
      }
  }
}

private struct ConversationStatisticsStatusRow: Identifiable {
  let status: DashboardConversation.Status
  let count: Int

  var id: DashboardConversation.Status { status }

  static func all(from conversations: [DashboardConversation]) -> [ConversationStatisticsStatusRow] {
    [.open, .resolved, .spam].map { status in
      ConversationStatisticsStatusRow(
        status: status,
        count: conversations.filter { $0.status == status }.count
      )
    }
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

private struct ConversationStatisticsSentimentRow: Identifiable {
  let sentiment: DashboardConversationSentiment
  let count: Int

  var id: DashboardConversationSentiment { sentiment }

  static func all(from conversations: [DashboardConversation]) -> [ConversationStatisticsSentimentRow] {
    DashboardConversationSentiment.allCases.map { sentiment in
      ConversationStatisticsSentimentRow(
        sentiment: sentiment,
        count: conversations.filter { $0.sentimentCategory == sentiment }.count
      )
    }
  }
}

private enum ConversationStatisticsVolumeBreakdown: String, CaseIterable, Identifiable {
  case status
  case category
  case source
  case appVersion
  case groupPresence
  case gameID
  case authIdentity
  case channel
  case priority
  case sentiment
  case attention

  var id: String { rawValue }

  var label: String {
    switch self {
    case .status:
      "Status"
    case .category:
      "Category"
    case .source:
      "Source"
    case .appVersion:
      "App Version"
    case .groupPresence:
      "Group ID"
    case .gameID:
      "Game ID"
    case .authIdentity:
      "Auth Identity"
    case .channel:
      "Channel"
    case .priority:
      "Priority"
    case .sentiment:
      "Sentiment"
    case .attention:
      "Attention"
    }
  }

  func label(for conversation: DashboardConversation) -> String {
    switch self {
    case .status:
      conversation.status.label
    case .category:
      conversation.statisticsCategoryLabel
    case .source:
      conversation.statisticsSourceLabel
    case .appVersion:
      conversation.statisticsAppVersionLabel
    case .groupPresence:
      conversation.statisticsGroupPresenceLabel
    case .gameID:
      conversation.statisticsGameIDLabel
    case .authIdentity:
      conversation.statisticsAuthIdentityPresenceLabel
    case .channel:
      conversation.statisticsChannelLabel
    case .priority:
      conversation.priority.label
    case .sentiment:
      conversation.sentimentCategory.label
    case .attention:
      conversation.statisticsAttentionLabel
    }
  }
}

private enum ConversationStatisticsDateRange: String, CaseIterable, Identifiable {
  case all
  case last24Hours
  case last7Days
  case last30Days

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      "All Loaded"
    case .last24Hours:
      "Last 24 Hours"
    case .last7Days:
      "Last 7 Days"
    case .last30Days:
      "Last 30 Days"
    }
  }

  func cutoffDate(relativeTo now: Date) -> Date? {
    guard let interval else { return nil }
    return now.addingTimeInterval(-interval)
  }

  func timelineBucket(for date: Date, calendar: Calendar) -> Date {
    switch self {
    case .last24Hours:
      let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
      return calendar.date(from: components) ?? date
    case .all, .last7Days, .last30Days:
      return calendar.startOfDay(for: date)
    }
  }

  private var interval: TimeInterval? {
    switch self {
    case .all:
      nil
    case .last24Hours:
      24 * 60 * 60
    case .last7Days:
      7 * 24 * 60 * 60
    case .last30Days:
      30 * 24 * 60 * 60
    }
  }
}

private enum ConversationStatisticsDateBasis: String, CaseIterable, Identifiable {
  case created
  case latestActivity

  var id: String { rawValue }

  var label: String {
    switch self {
    case .created:
      "Created"
    case .latestActivity:
      "Latest Activity"
    }
  }

  func date(for conversation: DashboardConversation) -> Date? {
    switch self {
    case .created:
      conversation.createdAtDate
    case .latestActivity:
      conversation.latestActivityDate
    }
  }
}

private enum ConversationStatisticsStatusFilter: String, CaseIterable, Identifiable {
  case all
  case open
  case resolved
  case spam

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      "Any Status"
    case .open:
      "Open"
    case .resolved:
      "Resolved"
    case .spam:
      "Spam"
    }
  }

  func includes(_ status: DashboardConversation.Status) -> Bool {
    switch self {
    case .all:
      true
    case .open:
      status == .open
    case .resolved:
      status == .resolved
    case .spam:
      status == .spam
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
      "Created in the last 24 hours after filters"
    case .last7Days:
      "Created in the last 7 days after filters"
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

private extension DashboardConversation {
  var statisticsChannelLabel: String {
    channelLabel.statisticsFallback("Unknown Channel")
  }

  var statisticsCategoryLabel: String {
    guard let rawValue = statisticsMetadataTextValue(forKey: InboxMetadataFilterKey.category.rawValue) else {
      return "Uncategorized"
    }

    return AutoResolveConversationCategory(aiValue: rawValue)?.label
      ?? rawValue.statisticsFallback("Uncategorized")
  }

  var statisticsSourceLabel: String {
    statisticsMetadataText(forKey: InboxMetadataFilterKey.source.rawValue, fallback: "Unknown Source")
  }

  var statisticsAppVersionLabel: String {
    statisticsMetadataText(forKey: "appVersion", fallback: "Unknown Version")
  }

  var statisticsGameIDLabel: String {
    statisticsMetadataText(forKey: "gameId", fallback: "Unknown Game")
  }

  var statisticsGroupPresenceLabel: String {
    statisticsHasGroupID ? "Group ID set" : "No group ID"
  }

  var statisticsAuthIdentityPresenceLabel: String {
    statisticsHasAuthIdentity ? "Auth identity set" : "No auth identity"
  }

  var statisticsHasGroupID: Bool {
    statisticsHasMetadataText(forKey: "groupId")
  }

  var statisticsHasAuthIdentity: Bool {
    statisticsHasMetadataText(forKey: "userId")
      || statisticsHasMetadataText(forKey: "authUserId")
  }

  var statisticsAttentionLabel: String {
    if needsHumanIntervention {
      return "Needs Human"
    }
    if needsClarification {
      return "Needs Clarification"
    }
    if hasUnreadActivity {
      return "Unread"
    }
    return "No Attention Flag"
  }

  private func statisticsMetadataText(forKey key: String, fallback: String) -> String {
    statisticsMetadataTextValue(forKey: key) ?? fallback
  }

  private func statisticsMetadataTextValue(forKey key: String) -> String? {
    guard let value = metadata?[key], value != .null else { return nil }

    let trimmedValue = value.dashboardDisplayText.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedValue.isEmpty ? nil : trimmedValue
  }

  private func statisticsHasMetadataText(forKey key: String) -> Bool {
    statisticsMetadataTextValue(forKey: key) != nil
  }
}

private extension String {
  func statisticsFallback(_ fallback: String) -> String {
    let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedValue.isEmpty ? fallback : trimmedValue
  }
}
