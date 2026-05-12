import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct AIAutoResolveWorkspaceView: View {
  @Bindable var store: AutoResolveStore
  let inspectedConversation: DashboardConversation?
  let inspectedVisitor: DashboardVisitor?
  let inspectedTimelineItems: [DashboardTimelineItem]
  let inspectedSeenData: [DashboardConversationSeen]
  let translatedMessagesByID: [String: DashboardMessageTranslation]
  let showBackendTranslatedSubjects: Bool
  let canUseMessageTranslations: Bool
  let showTranslations: Bool
  let isTranslatingMessages: Bool
  let translationErrorMessage: String?
  let loadState: ConversationSelectionLoadState
  let canLoadMoreTimeline: Bool
  let isLoadingMoreTimeline: Bool
  let canStart: Bool
  let candidateCount: () -> Int
  let availableChannelFilters: () -> [InboxChannelFilterOption]
  let availableMetadataFilters: () -> [InboxMetadataFilterSection]
  let availableAppVersionFilters: () -> [AutoResolveTextFilterOption]
  let availableGameIDFilters: () -> [AutoResolveTextFilterOption]
  let onStart: () -> Void
  let onCancel: () -> Void
  let onClearResults: () -> Void
  let onInspectConversation: (String) async -> Void
  let onOpenConversation: (String) -> Void
  let onResolveAnyway: (String) async -> Void
  let onMarkAsSeen: (String) async -> Void
  let onMarkAsUnread: (String) async -> Void
  let onMarkAllAsSeen: () async -> Void
  let onSetShowTranslations: (Bool) async -> Void
  let onLoadMoreTimeline: () -> Void

  var body: some View {
    HSplitView {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text("Auto-Resolve")
            .font(.title.weight(.semibold))

          autoResolveControlsCard

          if let status = store.statusMessage {
            Label(
              status,
              systemSymbol: store.isRunning ? .clockArrowTriangleheadCounterclockwiseRotate90 : .sparkles
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
          }

          if hasAutoResolveActivity {
            autoResolveResultsCard
          }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
      }

      autoResolveInspectorColumn
    }
  }

  private var autoResolveControlsCard: some View {
    PrototypeInfoCard(title: "Workflow") {
      Picker("Source Queue", selection: $store.sourceScope) {
        ForEach(AutoResolveSourceScope.allCases) { scope in
          Text(scope.label)
            .tag(scope)
        }
      }
      .pickerStyle(.segmented)
      .disabled(store.isRunning)

      candidateFilterControls

      Text("\(candidateCount().formatted(.number)) conversations match the source queue and candidate filters.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Text("Designed for conservative cleanup. Unclear or people-dependent threads stay open.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if !store.hasOpenAIAPIKey {
        Label("Add an OpenAI API key in Settings to enable auto-resolve.", systemSymbol: .keyFill)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      ViewThatFits(in: .horizontal) {
        HStack {
          workflowButtons
          Spacer()
        }

        VStack(alignment: .leading, spacing: 8) {
          workflowButtons
        }
      }
    }
  }

  private var workflowButtons: some View {
    Group {
      if store.isRunning {
        Button("Cancel") {
          onCancel()
        }
      } else {
        Button("Start Auto-Resolve") {
          onStart()
        }
        .disabled(!canStart)
      }

      Button("Clear Results") {
        onClearResults()
      }
      .disabled(!store.canClearResults)
    }
  }

  private var candidateFilterControls: some View {
    VStack(alignment: .leading, spacing: 8) {
      LazyVGrid(columns: candidateFilterColumns, alignment: .leading, spacing: 8) {
        if !availableChannelFilters().isEmpty {
          channelFilterMenu
        }

        candidateFilterMenu(
          title: "Priority",
          value: store.priorityFilter.label,
          systemImage: .flag
        ) {
          Picker("Priority", selection: $store.priorityFilter) {
            ForEach(InboxPriorityFilter.allCases) { filter in
              Text(filter.label)
                .tag(filter)
            }
          }
        }

        candidateFilterMenu(
          title: "Date",
          value: dateFilterValue,
          systemImage: .calendar
        ) {
          Picker("Range", selection: $store.dateRange) {
            ForEach(AutoResolveDateRange.allCases) { range in
              Text(range.label)
                .tag(range)
            }
          }

          Picker("Date", selection: $store.dateBasis) {
            ForEach(AutoResolveDateBasis.allCases) { basis in
              Text(basis.label)
                .tag(basis)
            }
          }
        }

        candidateFilterMenu(
          title: "Attention",
          value: store.attentionFilter.label,
          systemImage: .personCropCircleBadgeQuestionmark
        ) {
          Picker("Attention", selection: $store.attentionFilter) {
            ForEach(AutoResolveAttentionFilter.allCases) { filter in
              Text(filter.label)
                .tag(filter)
            }
          }
        }

        if !availableMetadataFilters().isEmpty {
          metadataFilterMenu
        }

        if !availableAppVersionFilters().isEmpty {
          textFilterMenu(
            title: "App Version",
            value: store.appVersionFilter,
            fallbackValue: "Any Version",
            systemImage: .shippingbox,
            options: availableAppVersionFilters()
          ) { value in
            store.appVersionFilter = value
          }
        }

        if !availableGameIDFilters().isEmpty {
          textFilterMenu(
            title: "Game",
            value: store.gameIDFilter,
            fallbackValue: "Any Game",
            systemImage: .gamecontroller,
            options: availableGameIDFilters()
          ) { value in
            store.gameIDFilter = value
          }
        }
      }
      .padding(.vertical, 2)
      .disabled(store.isRunning)

      if store.hasActiveCandidateFilters {
        Button("Clear Candidate Filters") {
          store.clearCandidateFilters()
        }
        .buttonStyle(.borderless)
        .font(.caption.weight(.medium))
        .disabled(store.isRunning)
      }
    }
  }

  private var candidateFilterColumns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(minimum: 140), spacing: 8, alignment: .leading),
      count: 3
    )
  }

  private var dateFilterValue: String {
    guard store.dateRange != .all else {
      return store.dateRange.label
    }

    return "\(store.dateRange.label) • \(store.dateBasis.label)"
  }

  private var channelFilterMenu: some View {
    Menu {
      Button {
        store.channelFilter = nil
      } label: {
        menuLabel("Any Channel", isSelected: store.channelFilter == nil)
      }

      ForEach(availableChannelFilters()) { option in
        Button {
          store.channelFilter = option.value
        } label: {
          menuLabel(
            option.label,
            isSelected: store.channelFilter == option.value
          )
        }
      }
    } label: {
      HeaderControlLabel(
        title: "Channel",
        value: store.channelFilter.map { InboxChannelFilterOption(value: $0).label } ?? "Any Channel",
        systemImage: .bubbleLeftAndBubbleRight
      )
    }
  }

  private var metadataFilterMenu: some View {
    Menu {
      ForEach(availableMetadataFilters()) { section in
        Menu(section.label) {
          Button {
            store.setMetadataFilter(nil, for: section.key)
          } label: {
            menuLabel(
              "Any \(section.label)",
              isSelected: store.selectedMetadataValue(for: section.key) == nil
            )
          }

          ForEach(section.options) { option in
            Button {
              store.setMetadataFilter(option.value, for: section.key)
            } label: {
              menuLabel(
                option.label,
                isSelected: store.selectedMetadataValue(for: section.key) == option.value
              )
            }
          }
        }
      }
    } label: {
      HeaderControlLabel(
        title: "Metadata",
        value: metadataFilterSummary ?? "Any Metadata",
        systemImage: .tag
      )
    }
  }

  private var metadataFilterSummary: String? {
    let values: [String] = availableMetadataFilters().compactMap { section in
      guard let selectedValue = store.selectedMetadataValue(for: section.key) else {
        return nil
      }

      return "\(section.label): \(selectedValue.dashboardDisplayText)"
    }

    guard !values.isEmpty else { return nil }
    return values.joined(separator: " • ")
  }

  private func candidateFilterMenu<Content: View>(
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

  private func textFilterMenu(
    title: String,
    value: String?,
    fallbackValue: String,
    systemImage: SFSymbol,
    options: [AutoResolveTextFilterOption],
    onSelect: @escaping (String?) -> Void
  ) -> some View {
    Menu {
      Button {
        onSelect(nil)
      } label: {
        menuLabel(fallbackValue, isSelected: value == nil)
      }

      ForEach(options) { option in
        Button {
          onSelect(option.value)
        } label: {
          menuLabel(option.label, isSelected: value == option.value)
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

  private var autoResolveResultsCard: some View {
    PrototypeInfoCard(title: "Results (\(filteredResults.count))") {
      VStack(alignment: .leading, spacing: 12) {
        autoResolveResultSummary

        if !store.results.isEmpty {
          autoResolveResultFilters
          autoResolveCategoryFilters
        }

        if filteredResults.isEmpty {
          ContentUnavailableView(
            "No matching results",
            systemImage: SFSymbol.checkmarkCircle.rawValue,
            description: Text("Adjust the result or category filters to show more conversations.")
          )
        }

        ForEach(filteredResults) { result in
          AutoResolveResultRow(
            result: result,
            isSelected: result.conversationID == store.inspectedConversationID,
            onInspectConversation: {
              await onInspectConversation(result.conversationID)
            },
            onOpenConversation: {
              onOpenConversation(result.conversationID)
            },
            onResolveAnyway: {
              await onResolveAnyway(result.conversationID)
            },
            onMarkAsSeen: {
              await onMarkAsSeen(result.conversationID)
            },
            onMarkAsUnread: {
              await onMarkAsUnread(result.conversationID)
            }
          )
        }
      }
    }
  }

  private var hasAutoResolveActivity: Bool {
    !store.results.isEmpty || store.closedEmptyConversationCount > 0
  }

  private var filteredResults: [AutoResolveResult] {
    store.results.filter { result in
      let matchesOutcome = store.selectedOutcomeFilter?.includes(result) ?? true
      let matchesCategory = store.selectedCategoryFilter.map { result.category == $0 } ?? true
      return matchesOutcome && matchesCategory
    }
  }

  private var categoryCounts: [(category: AutoResolveConversationCategory, count: Int)] {
    let counts = Dictionary(grouping: outcomeFilteredResults, by: \.category)
      .mapValues(\.count)

    return AutoResolveConversationCategory.allCases.compactMap { category in
      guard let count = counts[category], count > 0 else { return nil }
      return (category, count)
    }
  }

  private var outcomeFilteredResults: [AutoResolveResult] {
    guard let selectedOutcomeFilter = store.selectedOutcomeFilter else {
      return store.results
    }

    return store.results.filter(selectedOutcomeFilter.includes)
  }

  private var outcomeFilterCounts: [(filter: AutoResolveResultFilter, count: Int)] {
    AutoResolveResultFilter.allCases.map { filter in
      (filter, store.results.filter(filter.includes).count)
    }
  }

  private var autoResolveResultSummary: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) {
        resultSummaryText

        Spacer(minLength: 0)

        markAllReadButton
      }

      VStack(alignment: .leading, spacing: 8) {
        resultSummaryText
        markAllReadButton
      }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }

  private var resultSummaryText: some View {
    Group {
      Text("Closed empty: \(store.closedEmptyConversationCount.formatted(.number))")

      Text("Auto-resolved: \(store.autoResolvedNonEmptyConversationCount.formatted(.number))")

      Text("Kept open: \(store.keptOpenNonEmptyConversationCount.formatted(.number))")

      if unreadResultCount > 0 {
        Label("\(unreadResultCount.formatted(.number)) unread", systemSymbol: .circleFill)
          .foregroundStyle(Color.accentColor)
      }
    }
  }

  private var markAllReadButton: some View {
    Button {
      Task {
        await onMarkAllAsSeen()
      }
    } label: {
      Label(markAllReadButtonTitle, systemSymbol: .checkmarkCircle)
    }
    .buttonStyle(.borderless)
    .foregroundStyle(unreadResultCount == 0 ? Color.secondary : Color.accentColor)
    .disabled(unreadResultCount == 0 || isMarkingAnyResultRead)
    .help("Mark all Auto-Resolve results as read")
  }

  private var unreadResultCount: Int {
    store.results.filter { !$0.isSeen }.count
  }

  private var isMarkingAnyResultRead: Bool {
    store.results.contains { $0.isMarkingSeen }
  }

  private var markAllReadButtonTitle: String {
    if isMarkingAnyResultRead {
      return "Marking Read"
    }

    return "Mark All as Read"
  }

  private var autoResolveResultFilters: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        AutoResolveCategoryFilterChip(
          title: "All",
          count: store.results.count,
          isSelected: store.selectedOutcomeFilter == nil,
          action: {
            store.selectedOutcomeFilter = nil
          }
        )

        ForEach(outcomeFilterCounts, id: \.filter) { item in
          AutoResolveCategoryFilterChip(
            title: item.filter.label,
            count: item.count,
            isSelected: store.selectedOutcomeFilter == item.filter,
            action: {
              store.selectedOutcomeFilter = item.filter
            }
          )
        }
      }
      .padding(.vertical, 2)
    }
    .scrollIndicators(.hidden)
  }

  private var autoResolveCategoryFilters: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        AutoResolveCategoryFilterChip(
          title: "All",
          count: outcomeFilteredResults.count,
          isSelected: store.selectedCategoryFilter == nil,
          action: {
            store.selectedCategoryFilter = nil
          }
        )

        ForEach(categoryCounts, id: \.category) { item in
          AutoResolveCategoryFilterChip(
            title: item.category.label,
            count: item.count,
            isSelected: store.selectedCategoryFilter == item.category,
            action: {
              store.selectedCategoryFilter = item.category
            }
          )
        }
      }
      .padding(.vertical, 2)
    }
    .scrollIndicators(.hidden)
  }

  private var autoResolveInspectorColumn: some View {
    AutoResolveConversationInspectorView(
      conversation: inspectedConversation,
      visitor: inspectedVisitor,
      timelineItems: inspectedTimelineItems,
      seenData: inspectedSeenData,
      translatedMessagesByID: translatedMessagesByID,
      showBackendTranslatedSubjects: showBackendTranslatedSubjects,
      canUseMessageTranslations: canUseMessageTranslations,
      showTranslations: showTranslations,
      isTranslatingMessages: isTranslatingMessages,
      translationErrorMessage: translationErrorMessage,
      loadState: loadState,
      canLoadMoreTimeline: canLoadMoreTimeline,
      isLoadingMoreTimeline: isLoadingMoreTimeline,
      onSetShowTranslations: onSetShowTranslations,
      onLoadMoreTimeline: onLoadMoreTimeline
    )
    .frame(
      minWidth: ConversationWorkspaceLayout.inspectorMinWidth,
      idealWidth: ConversationWorkspaceLayout.inspectorIdealWidth,
      maxWidth: 520,
      maxHeight: .infinity
    )
  }
}

private struct AutoResolveCategoryFilterChip: View {
  let title: String
  let count: Int
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text("\(title) (\(count.formatted(.number)))")
        .font(.caption.weight(.medium))
        .foregroundStyle(isSelected ? .primary : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(backgroundStyle, in: .capsule)
    }
    .buttonStyle(.plain)
  }

  private var backgroundStyle: Color {
    isSelected ? .accentColor.opacity(0.18) : .secondary.opacity(0.12)
  }
}

private struct AutoResolveResultRow: View {
  let result: AutoResolveResult
  let isSelected: Bool
  let onInspectConversation: () async -> Void
  let onOpenConversation: () -> Void
  let onResolveAnyway: () async -> Void
  let onMarkAsSeen: () async -> Void
  let onMarkAsUnread: () async -> Void
  @State private var isShowingRawResponse = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button {
        Task {
          await onInspectConversation()
        }
      } label: {
        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            AutoResolveUnreadIndicator(
              isUnread: !result.isSeen,
              isMarkingRead: result.isMarkingSeen
            )

            Text(result.outcome.label)
              .font(.caption.weight(.semibold))
              .foregroundStyle(outcomeColor)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(outcomeColor.opacity(0.12), in: .capsule)

            Text(result.title)
              .font(.headline)
              .foregroundStyle(.primary)
              .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
          }

          HStack(spacing: 8) {
            Text(result.category.label)
              .font(.caption.weight(.medium))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(.secondary.opacity(0.12), in: .capsule)

            if let aiMarkedResolved = result.aiMarkedResolved {
              Text(aiMarkedResolved ? "AI: Resolved" : "AI: Not resolved")
                .font(.caption.weight(.medium))
                .foregroundStyle(aiMarkedResolved ? .green : .orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((aiMarkedResolved ? Color.green : .orange).opacity(0.12), in: .capsule)
            }

            Spacer(minLength: 0)
          }

          if let summaryText {
            Text(summaryText)
              .font(.subheadline.weight(.medium))
              .foregroundStyle(.primary)
              .multilineTextAlignment(.leading)
              .fixedSize(horizontal: false, vertical: true)
          }

          if let body = result.body, !body.isEmpty {
            Text(body)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.leading)
          }
        }
      }
      .buttonStyle(.plain)

      if let decisionNote = result.decisionNote, !decisionNote.isEmpty {
        Text(decisionNote)
          .font(.caption)
          .foregroundStyle(result.outcome == .manuallyResolved ? .green : .orange)
          .multilineTextAlignment(.leading)
      }

      if let rawAIResponseText = result.rawAIResponseText, !rawAIResponseText.isEmpty {
        DisclosureGroup(isExpanded: $isShowingRawResponse) {
          Text(rawAIResponseText)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        } label: {
          Text("Raw AI response")
            .font(.caption.weight(.medium))
        }
      }

      HStack(spacing: 8) {
        Label(result.visitorID, systemSymbol: .personTextRectangle)
          .font(.caption)
          .foregroundStyle(.tertiary)
          .lineLimit(1)
          .truncationMode(.middle)
          .help("Visitor ID")

        Label(result.conversationID, systemSymbol: .bubbleLeftAndBubbleRight)
          .font(.caption)
          .foregroundStyle(.tertiary)
          .lineLimit(1)
          .truncationMode(.middle)
          .help("Conversation ID")

        Spacer(minLength: 0)

        if let rawAIResponseText = result.rawAIResponseText, !rawAIResponseText.isEmpty {
          Button("Copy AI Response") {
            StringClipboardWriter.copy(rawAIResponseText)
          }
          .buttonStyle(.borderless)
          .font(.caption)
        }

        if result.outcome == .notResolved {
          Button(result.isResolvingAnyway ? "Resolving..." : "Resolve anyway") {
            Task {
              await onResolveAnyway()
            }
          }
          .buttonStyle(.borderless)
          .font(.caption)
          .disabled(result.isResolvingAnyway)
        }

        if result.isSeen {
          Button {
            Task {
              await onMarkAsUnread()
            }
          } label: {
            Label(result.isMarkingSeen ? "Marking Unread" : "Mark as Unread", systemSymbol: .eyeSlash)
          }
          .buttonStyle(.borderless)
          .font(.caption)
          .disabled(result.isMarkingSeen)
          .help("Mark this conversation as unread")
        } else {
          Button {
            Task {
              await onMarkAsSeen()
            }
          } label: {
            Label(result.isMarkingSeen ? "Marking Read" : "Mark as Read", systemSymbol: .checkmarkCircle)
          }
          .buttonStyle(.borderless)
          .font(.caption)
          .disabled(result.isMarkingSeen)
          .help("Mark this conversation as read")
        }

        Button("Open Conversation") {
          onOpenConversation()
        }
        .buttonStyle(.borderless)
        .font(.caption)

        Text(result.createdAt.formatted(.dateTime.hour().minute()))
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(rowBackground, in: .rect(cornerRadius: 16))
  }

  private var outcomeColor: Color {
    switch result.outcome {
    case .emptyResolved:
      return .secondary
    case .resolved:
      return .green
    case .manuallyResolved:
      return .green
    case .notResolved:
      return .orange
    }
  }

  private var rowBackground: Color {
    isSelected ? .secondary.opacity(0.16) : .secondary.opacity(0.08)
  }

  private var summaryText: String? {
    result.summary?
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
      .nilIfEmpty
  }
}

private struct AutoResolveUnreadIndicator: View {
  let isUnread: Bool
  let isMarkingRead: Bool

  var body: some View {
    ZStack {
      if isMarkingRead {
        ProgressView()
          .controlSize(.small)
      } else {
        Circle()
          .fill(isUnread ? Color.accentColor : Color.clear)
          .frame(width: 8, height: 8)
      }
    }
    .frame(width: 12, height: 12)
    .help(isUnread ? "Unread" : "Read")
    .accessibilityLabel(isUnread ? "Unread" : "Read")
  }
}
