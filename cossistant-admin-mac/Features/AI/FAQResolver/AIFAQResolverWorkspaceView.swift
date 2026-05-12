import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct AIFAQResolverWorkspaceView: View {
  @Bindable var store: FAQResolverStore
  let availableAIAgents: [DashboardWebsite.AIAgent]
  let conversations: [DashboardConversation]
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
  let canRunFullResolve: Bool
  let canRunAutoAssignAll: Bool
  let canPreviewDraftTranslations: Bool
  let autoAssignAllCandidateCount: Int
  let availableChannelFilters: () -> [InboxChannelFilterOption]
  let availableMetadataFilters: () -> [InboxMetadataFilterSection]
  let availableAppVersionFilters: () -> [FAQResolverTextFilterOption]
  let availableGameIDFilters: () -> [FAQResolverTextFilterOption]
  let onReloadFAQs: () async -> Void
  let onInspectConversation: (String) async -> Void
  let onOpenConversation: (String) -> Void
  let onMarkSeen: (String) async -> Void
  let onMarkUnseen: (String) async -> Void
  let onResolveInspectorConversation: (String) async -> Void
  let onReopenInspectorConversation: (String) async -> Void
  let onAutoAssignFAQ: (String) async -> Void
  let onStartAutoAssignAll: () -> Void
  let onCancelAutoAssignAll: () -> Void
  let onResolveConversation: (String) async -> Void
  let onConfirmConversation: (String) async -> Void
  let onResetResolveResult: (String) -> Void
  let onTranslatePendingDrafts: () async -> Void
  let onConfirmAll: () async -> Void
  let onStartFullResolve: () -> Void
  let onCancelFullResolve: () -> Void
  let onSetShowTranslations: (Bool) async -> Void
  let onLoadMoreTimeline: () -> Void

  @State private var pickerContext: FAQResolverPickerContext?

  var body: some View {
    HSplitView {
      VStack(spacing: 0) {
        header

        Divider()

        conversationList
      }

      FAQResolverConversationInspectorView(
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
        onOpenConversation: onOpenConversation,
        onMarkSeen: onMarkSeen,
        onMarkUnseen: onMarkUnseen,
        onResolveConversation: onResolveInspectorConversation,
        onReopenConversation: onReopenInspectorConversation,
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
    .sheet(item: $pickerContext) { context in
      FAQResolverPickerSheet(
        faqEntries: store.faqEntries,
        initialSelection: Set(store.assignedFAQIDs(for: context.conversationID)),
        onSave: { selectedIDs in
          store.setAssignedFAQIDs(
            Array(selectedIDs),
            for: context.conversationID,
            source: .manual
          )
        }
      )
    }
    .onChange(of: store.previewsDraftTranslations) { _, isEnabled in
      guard isEnabled else { return }
      Task {
        await onTranslatePendingDrafts()
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text("FAQ Resolver")
          .font(.title.weight(.semibold))

        Spacer(minLength: 0)

        Button {
          Task {
            await onReloadFAQs()
          }
        } label: {
          Label(store.isLoadingFAQs ? "Loading..." : "Reload FAQs", systemSymbol: .arrowClockwise)
        }
        .disabled(!store.canReloadFAQs)

        if store.isRunningAutoAssignAll {
          Button("Stop Auto Assign") {
            onCancelAutoAssignAll()
          }
          .help("Stop Auto Assign All after the current in-flight request cancels")
        } else {
          Button("Auto Assign All") {
            onStartAutoAssignAll()
          }
          .disabled(!canRunAutoAssignAll)
          .help("Auto assign untouched eligible conversations")
        }

        if pendingConfirmationCount > 0 {
          Button("Confirm All") {
            Task {
              await onConfirmAll()
            }
          }
          .disabled(store.isConfirmingAll || store.isRunningFullResolve || store.isRunningAutoAssignAll)
        }

        if store.isRunningFullResolve {
          Button("Stop Full Resolve") {
            onCancelFullResolve()
          }
        } else {
          Button("Full Resolve") {
            onStartFullResolve()
          }
          .buttonStyle(.borderedProminent)
          .disabled(!canRunFullResolve)
        }
      }

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 10) {
          aiAgentPicker
          countBadge("\(store.faqEntries.count.formatted(.number)) FAQs loaded", symbol: .questionmarkCircle)
          countBadge("\(conversations.count.formatted(.number)) eligible conversations", symbol: .bubbleLeftAndBubbleRight)
          countBadge("\(autoAssignAllCandidateCount.formatted(.number)) untouched", symbol: .wandAndSparkles)
          if pendingConfirmationCount > 0 {
            countBadge("\(pendingConfirmationCount.formatted(.number)) pending confirmation", symbol: .checkmarkCircle)
          }
          draftTranslationToggle
          Spacer(minLength: 0)
        }

        VStack(alignment: .leading, spacing: 8) {
          aiAgentPicker

          HStack(spacing: 8) {
            countBadge("\(store.faqEntries.count.formatted(.number)) FAQs loaded", symbol: .questionmarkCircle)
            countBadge("\(conversations.count.formatted(.number)) eligible conversations", symbol: .bubbleLeftAndBubbleRight)
            countBadge("\(autoAssignAllCandidateCount.formatted(.number)) untouched", symbol: .wandAndSparkles)
            if pendingConfirmationCount > 0 {
              countBadge("\(pendingConfirmationCount.formatted(.number)) pending confirmation", symbol: .checkmarkCircle)
            }
          }

          draftTranslationToggle
        }
      }

      filterControls

      if !store.hasOpenAIAPIKey {
        Label("Add an OpenAI API key in Settings to enable auto assignment and Full Resolve.", systemSymbol: .keyFill)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if let statusMessage = store.statusMessage {
        Label(statusMessage, systemSymbol: store.isRunningFullResolve ? .clockArrowTriangleheadCounterclockwiseRotate90 : .sparkles)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if let faqErrorMessage = store.faqErrorMessage {
        Label(faqErrorMessage, systemSymbol: .exclamationmarkTriangle)
          .font(.subheadline)
          .foregroundStyle(.red)
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.bar)
  }

  private var aiAgentPicker: some View {
    Picker(
      "AI Agent",
      selection: Binding(
        get: { store.selectedAIAgentID },
        set: { newValue in
          guard store.selectedAIAgentID != newValue else { return }
          store.selectedAIAgentID = newValue
          store.faqEntries = []
          Task {
            await onReloadFAQs()
          }
        }
      )
    ) {
      Text("Select AI Agent")
        .tag(nil as String?)

      ForEach(availableAIAgents) { agent in
        Text(agent.displayName)
          .tag(Optional(agent.id))
      }
    }
    .pickerStyle(.menu)
    .frame(minWidth: 220, alignment: .leading)
  }

  private var draftTranslationToggle: some View {
    Toggle(isOn: $store.previewsDraftTranslations) {
      Label("Translate drafts", systemSymbol: .translate)
    }
    .toggleStyle(.switch)
    .font(.caption.weight(.medium))
    .disabled(!canPreviewDraftTranslations)
    .help(canPreviewDraftTranslations ? "Translate drafted answers for confirmation" : "Add a Google Cloud Translate API key to translate drafted answers")
  }

  private var filterControls: some View {
    VStack(alignment: .leading, spacing: 8) {
      LazyVGrid(columns: filterColumns, alignment: .leading, spacing: 8) {
        filterMenu(title: "Source", value: store.sourceScope.label, systemImage: .trayFull) {
          Picker("Source", selection: $store.sourceScope) {
            ForEach(FAQResolverSourceScope.allCases) { scope in
              Text(scope.label)
                .tag(scope)
            }
          }
        }

        filterMenu(title: "Priority", value: store.priorityFilter.label, systemImage: .flag) {
          Picker("Priority", selection: $store.priorityFilter) {
            ForEach(InboxPriorityFilter.allCases) { filter in
              Text(filter.label)
                .tag(filter)
            }
          }
        }

        filterMenu(title: "Date", value: dateFilterValue, systemImage: .calendar) {
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

        filterMenu(title: "Summary", value: store.summaryFilter.label, systemImage: .textBubble) {
          Picker("Summary", selection: $store.summaryFilter) {
            ForEach(FAQResolverSummaryFilter.allCases) { filter in
              Text(filter.label)
                .tag(filter)
            }
          }
        }

        filterMenu(title: "Reply State", value: store.visitorWaitingFilter.label, systemImage: .clock) {
          Picker("Reply State", selection: $store.visitorWaitingFilter) {
            ForEach(FAQResolverVisitorWaitingFilter.allCases) { filter in
              Text(filter.label)
                .tag(filter)
            }
          }
        }

        filterMenu(title: "Team Need", value: store.teamActionFilter.label, systemImage: .exclamationmarkTriangle) {
          Picker("Team Need", selection: $store.teamActionFilter) {
            ForEach(FAQResolverTeamActionFilter.allCases) { filter in
              Text(filter.label)
                .tag(filter)
            }
          }
        }

        Toggle(isOn: $store.ignoresHandledTimestamps) {
          Label("Ignore handled", systemSymbol: .arrowCounterclockwise)
        }
        .toggleStyle(.switch)
        .font(.caption.weight(.medium))
        .help("Include conversations even when faqResolverHandledAt is current")

        if !availableChannelFilters().isEmpty {
          channelFilterMenu
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

      if store.hasActiveCandidateFilters {
        Button("Clear Candidate Filters") {
          store.clearCandidateFilters()
        }
        .buttonStyle(.borderless)
        .font(.caption.weight(.medium))
      }
    }
    .disabled(store.isRunningFullResolve)
  }

  private var conversationList: some View {
    List(conversations) { conversation in
      FAQResolverConversationRow(
        store: store,
        conversation: conversation,
        showBackendTranslatedSubjects: showBackendTranslatedSubjects,
        isSelected: conversation.id == store.inspectedConversationID,
        onInspect: {
          await onInspectConversation(conversation.id)
        },
        onAssign: {
          pickerContext = FAQResolverPickerContext(conversationID: conversation.id)
        },
        onAutoAssign: {
          await onAutoAssignFAQ(conversation.id)
        },
        onResolve: {
          await onResolveConversation(conversation.id)
        },
        onConfirm: {
          await onConfirmConversation(conversation.id)
        },
        onResetResolveResult: {
          onResetResolveResult(conversation.id)
        },
        onRemoveFAQ: { faqID in
          store.removeAssignedFAQ(faqID, from: conversation.id)
        },
        onRemoveResolveWithoutReply: {
          store.setCanResolveWithoutReply(false, for: conversation.id)
        },
        onRemoveNoActionNeeded: {
          store.setNoActionNeeded(false, for: conversation.id)
        },
        onRemoveUrgentlyNeedsTeam: {
          store.setUrgentlyNeedsTeam(false, for: conversation.id)
        }
      )
      .listRowBackground(
        conversation.id == store.inspectedConversationID
          ? Color.accentColor.opacity(0.12)
          : Color.clear
      )
    }
    .listStyle(.inset(alternatesRowBackgrounds: false))
    .overlay {
      if conversations.isEmpty {
        ContentUnavailableView(
          "No eligible conversations",
          systemImage: SFSymbol.questionmarkBubble.rawValue,
          description: Text("Adjust filters or load more conversations in the inbox.")
        )
      }
    }
  }

  private var filterColumns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(minimum: 140), spacing: 8, alignment: .leading),
      count: 4
    )
  }

  private var dateFilterValue: String {
    guard store.dateRange != .all else {
      return store.dateRange.label
    }

    return "\(store.dateRange.label) • \(store.dateBasis.label)"
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

  private var fullResolveConversationCount: Int {
    conversations.filter { store.state(for: $0.id).hasPendingResolveWork }.count
  }

  private var pendingConfirmationCount: Int {
    conversations.filter { store.pendingConfirmation(for: $0.id) != nil }.count
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
          menuLabel(option.label, isSelected: store.channelFilter == option.value)
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

  private func filterMenu<Content: View>(
    title: String,
    value: String,
    systemImage: SFSymbol,
    @ViewBuilder content: () -> Content
  ) -> some View {
    Menu {
      content()
    } label: {
      HeaderControlLabel(title: title, value: value, systemImage: systemImage)
    }
  }

  private func textFilterMenu(
    title: String,
    value: String?,
    fallbackValue: String,
    systemImage: SFSymbol,
    options: [FAQResolverTextFilterOption],
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

  private func countBadge(_ title: String, symbol: SFSymbol) -> some View {
    Label(title, systemSymbol: symbol)
      .font(.caption.weight(.medium))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.quinary.opacity(0.8), in: .rect(cornerRadius: 7))
  }
}

private struct FAQResolverConversationRow: View {
  @Bindable var store: FAQResolverStore
  let conversation: DashboardConversation
  let showBackendTranslatedSubjects: Bool
  let isSelected: Bool
  let onInspect: () async -> Void
  let onAssign: () -> Void
  let onAutoAssign: () async -> Void
  let onResolve: () async -> Void
  let onConfirm: () async -> Void
  let onResetResolveResult: () -> Void
  let onRemoveFAQ: (DashboardKnowledge.ID) -> Void
  let onRemoveResolveWithoutReply: () -> Void
  let onRemoveNoActionNeeded: () -> Void
  let onRemoveUrgentlyNeedsTeam: () -> Void

  var body: some View {
    Button {
      Task {
        await onInspect()
      }
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        rowHeader
        previewText
        metadataRow
        assignedFAQRow
        pendingConfirmationRow
        statusRow
        actionRow
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 8)
      .contentShape(.rect)
      .opacity(isResolvedRow ? 0.52 : 1)
    }
    .buttonStyle(.plain)
  }

  private var rowHeader: some View {
    HStack(alignment: .top, spacing: 8) {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 7) {
          if conversation.hasUnreadActivity {
            Circle()
              .fill(Color.accentColor)
              .frame(width: 8, height: 8)
          }

          Text(conversation.visitorDisplayName)
            .font(.headline.weight(conversation.hasUnreadActivity ? .semibold : .regular))
            .lineLimit(1)
        }

        HStack(alignment: .firstTextBaseline, spacing: 3) {
          if conversation.hasUpdatesSinceLastSeen {
            Image(systemSymbol: .clockArrowTriangleheadCounterclockwiseRotate90)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
          }

          Text(titleText)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }

      Spacer(minLength: 0)

      VStack(alignment: .trailing, spacing: 3) {
        timestamp(title: "Last", value: conversation.lastActivityRelativeText, emphasized: true)
        timestamp(title: "Created", value: conversation.createdRelativeText, emphasized: false)
      }
    }
  }

  private var previewText: some View {
    Text(conversation.inboxMetadataSummaryPreviewText ?? conversation.previewText)
      .font(.subheadline)
      .foregroundStyle(conversation.inboxMetadataSummaryPreviewText == nil ? .secondary : .primary)
      .lineLimit(3)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var metadataRow: some View {
    HStack(spacing: 6) {
      FAQResolverPriorityChip(priority: conversation.priority)

      RowTag(title: conversation.channelLabel, systemSymbol: .bubbleLeftAndBubbleRight, tint: .secondary)

      if let version = conversation.appVersionIndicatorText {
        RowTag(title: version, systemSymbol: .shippingbox, tint: .secondary)
      }

      if conversation.needsHumanIntervention {
        RowTag(title: "Human intervention", systemSymbol: .personFillBadgePlus, tint: .orange)
      }

      if let waitingLabel = conversation.visitorWaitingLabel {
        RowTag(title: waitingLabel, systemSymbol: .clock, tint: conversation.visitorWaitingTint)
      }
    }
  }

  private var assignedFAQRow: some View {
    let assignedFAQs = store.assignedFAQs(for: conversation.id)
    let state = store.state(for: conversation.id)
    let canResolveWithoutReply = state.canResolveWithoutReply
    let noActionNeeded = state.noActionNeeded
    let urgentlyNeedsTeam = state.urgentlyNeedsTeam

    return ScrollView(.horizontal) {
      HStack(spacing: 6) {
        if assignedFAQs.isEmpty && !canResolveWithoutReply && !noActionNeeded && !urgentlyNeedsTeam {
          Text("No FAQs assigned")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }

        if canResolveWithoutReply {
          FAQResolverAssignedFAQChip(
            title: "Resolve without reply",
            tint: .green,
            onRemove: onRemoveResolveWithoutReply
          )
        }

        if noActionNeeded {
          FAQResolverAssignedFAQChip(
            title: "No action, mark seen",
            tint: .orange,
            onRemove: onRemoveNoActionNeeded
          )
        }

        if urgentlyNeedsTeam {
          FAQResolverAssignedFAQChip(
            title: state.teamActionNeeded.map { "Needs team: \($0)" } ?? "Needs team",
            tint: .red,
            onRemove: onRemoveUrgentlyNeedsTeam
          )
        }

        ForEach(assignedFAQs) { faq in
          FAQResolverAssignedFAQChip(
            title: faq.titleText,
            tint: .accentColor,
            onRemove: {
              onRemoveFAQ(faq.id)
            }
          )
        }
      }
      .padding(.vertical, 1)
    }
    .scrollIndicators(.hidden)
  }

  @ViewBuilder
  private var pendingConfirmationRow: some View {
    if let pending = store.pendingConfirmation(for: conversation.id) {
      VStack(alignment: .leading, spacing: 8) {
        ScrollView(.horizontal) {
          HStack(spacing: 6) {
            ForEach(pending.actions, id: \.self) { action in
              RowTag(
                title: action.label,
                systemSymbol: pendingActionSymbol(for: action),
                tint: pendingActionTint(for: action)
              )
            }

            if let teamActionNeeded = pending.teamActionNeeded {
              RowTag(
                title: "Needs team: \(teamActionNeeded)",
                systemSymbol: .exclamationmarkTriangle,
                tint: .red
              )
            }
          }
          .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)

        if let message = pending.message {
          VStack(alignment: .leading, spacing: 4) {
            Text("Draft answer")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.tertiary)

            Text(message)
              .font(.caption)
              .foregroundStyle(.primary)
              .lineLimit(6)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(8)
          .background(.quinary.opacity(0.7), in: .rect(cornerRadius: 7))
        }

        if store.previewsDraftTranslations,
           let translatedMessage = pending.translatedMessage {
          VStack(alignment: .leading, spacing: 4) {
            Text("Translation")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.tertiary)

            Text(translatedMessage.text)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(6)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(8)
          .background(Color.accentColor.opacity(0.08), in: .rect(cornerRadius: 7))
        } else if store.previewsDraftTranslations,
                  let translationErrorMessage = pending.translationErrorMessage {
          Label(translationErrorMessage, systemSymbol: .exclamationmarkTriangle)
            .font(.caption)
            .foregroundStyle(.orange)
        }
      }
    }
  }

  @ViewBuilder
  private var statusRow: some View {
    let state = store.state(for: conversation.id)
    if let status = state.status.label {
      Label(
        status,
        systemSymbol: statusSymbol(for: state.status)
      )
      .font(.caption)
      .foregroundStyle(statusTint(for: state.status))
      .lineLimit(2)
    }
  }

  private var actionRow: some View {
    HStack(spacing: 8) {
      Button("ASSIGN FAQ") {
        onAssign()
      }
      .disabled(store.faqEntries.isEmpty || store.isRunningFullResolve || store.isRunningAutoAssignAll || isResolvedRow)

      Button("AUTO ASSIGN FAQ") {
        Task {
          await onAutoAssign()
        }
      }
      .disabled(store.faqEntries.isEmpty || store.isRunningFullResolve || store.isRunningAutoAssignAll || store.state(for: conversation.id).status == .assigning || isResolvedRow)

      Button("RESOLVE") {
        Task {
          await onResolve()
        }
      }
      .disabled(!canResolveRow)

      if store.pendingConfirmation(for: conversation.id) != nil {
        Button("CONFIRM") {
          Task {
            await onConfirm()
          }
        }
        .disabled(!canConfirmRow)
      }

      if canShowResetResolveResult {
        Button("RESET") {
          onResetResolveResult()
        }
        .disabled(!canResetResolveResult)
      }

      if let source = store.state(for: conversation.id).assignmentSource {
        Text(source.label)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      }
    }
    .buttonStyle(.borderless)
    .font(.caption.weight(.semibold))
  }

  private var titleText: String {
    conversation.displayTitle(showBackendTranslatedSubjects: showBackendTranslatedSubjects)
  }

  private var canResolveRow: Bool {
    let state = store.state(for: conversation.id)
    return store.hasOpenAIAPIKey
      && !store.isRunningFullResolve
      && !store.isRunningAutoAssignAll
      && conversation.status == .open
      && !conversation.isArchived
      && !isResolvedRow
      && state.hasPendingResolveWork
      && state.status != .resolving
      && state.status != .pendingConfirmation
      && state.status != .confirming
      && state.status != .assigning
      && state.status != .resolved
  }

  private var canConfirmRow: Bool {
    let state = store.state(for: conversation.id)
    return !store.isRunningFullResolve
      && !store.isRunningAutoAssignAll
      && !store.isConfirmingAll
      && conversation.status == .open
      && !conversation.isArchived
      && !isResolvedRow
      && state.pendingConfirmation != nil
      && state.status != .confirming
  }

  private var canResetResolveResult: Bool {
    !store.isRunningFullResolve
      && !store.isRunningAutoAssignAll
      && !store.isConfirmingAll
      && canShowResetResolveResult
      && store.state(for: conversation.id).status != .confirming
  }

  private var canShowResetResolveResult: Bool {
    let state = store.state(for: conversation.id)
    if state.pendingConfirmation != nil {
      return true
    }

    switch state.status {
    case .failed, .skipped:
      return state.hasResolvableWork
    default:
      return false
    }
  }

  private var isResolvedRow: Bool {
    conversation.status == .resolved || store.state(for: conversation.id).status == .resolved
  }

  private func statusSymbol(for status: FAQResolverRowStatus) -> SFSymbol {
    switch status {
    case .assigning, .resolving, .confirming:
      .clockArrowTriangleheadCounterclockwiseRotate90
    case .pendingConfirmation:
      .checkmarkCircle
    case .markedSeen:
      .eye
    case .needsTeam:
      .exclamationmarkTriangle
    case .assigned:
      .checkmarkCircle
    case .sent:
      .paperplane
    case .resolved:
      .checkmarkSeal
    case .skipped:
      .minusCircle
    case .failed:
      .exclamationmarkTriangle
    case .idle:
      .circle
    }
  }

  private func statusTint(for status: FAQResolverRowStatus) -> Color {
    switch status {
    case .failed:
      .red
    case .skipped:
      .secondary
    case .resolved:
      .green
    case .sent, .assigned, .pendingConfirmation:
      .accentColor
    case .markedSeen:
      .secondary
    case .needsTeam:
      .red
    case .assigning, .resolving, .confirming:
      .orange
    case .idle:
      .secondary
    }
  }

  private func pendingActionSymbol(for action: FAQResolverPendingAction) -> SFSymbol {
    switch action {
    case .pauseAI:
      .lightbulbSlashFill
    case .sendAnswer:
      .paperplane
    case .markRead:
      .eye
    case .resolveAfterAnswer, .resolveNow:
      .checkmarkSeal
    case .markUnread:
      .eyeSlash
    case .doNothing:
      .minusCircle
    }
  }

  private func pendingActionTint(for action: FAQResolverPendingAction) -> Color {
    switch action {
    case .pauseAI:
      .orange
    case .sendAnswer:
      .accentColor
    case .markRead, .doNothing:
      .secondary
    case .resolveAfterAnswer, .resolveNow:
      .green
    case .markUnread:
      .red
    }
  }

  private func timestamp(title: String, value: String, emphasized: Bool) -> some View {
    HStack(spacing: 4) {
      Text(title)
        .font(.caption2.weight(.medium))
        .foregroundStyle(.tertiary)

      Text(value)
        .font(emphasized ? .caption.weight(.medium) : .caption2)
        .foregroundStyle(emphasized ? .secondary : .tertiary)
    }
  }
}

private struct FAQResolverPriorityChip: View {
  let priority: DashboardConversation.Priority

  var body: some View {
    RowTag(title: priority.label, systemSymbol: .flagFill, tint: priority.tint)
  }
}

private struct FAQResolverAssignedFAQChip: View {
  let title: String
  var tint: Color = .accentColor
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 5) {
      Text(title)
        .lineLimit(1)

      Button {
        onRemove()
      } label: {
        Image(systemSymbol: .xmarkCircleFill)
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .help("Remove FAQ")
    }
    .font(.caption.weight(.medium))
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(tint.opacity(0.12), in: .rect(cornerRadius: 6))
    .foregroundStyle(tint)
  }
}

private struct FAQResolverPickerContext: Identifiable {
  let conversationID: DashboardConversation.ID

  var id: String {
    conversationID
  }
}

private struct FAQResolverPickerSheet: View {
  let faqEntries: [DashboardKnowledge]
  let onSave: (Set<DashboardKnowledge.ID>) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var searchText = ""
  @State private var selectedFAQIDs: Set<DashboardKnowledge.ID>

  init(
    faqEntries: [DashboardKnowledge],
    initialSelection: Set<DashboardKnowledge.ID>,
    onSave: @escaping (Set<DashboardKnowledge.ID>) -> Void
  ) {
    self.faqEntries = faqEntries
    self.onSave = onSave
    _selectedFAQIDs = State(initialValue: initialSelection)
  }

  var body: some View {
    NavigationStack {
      List(filteredFAQs) { faq in
        Button {
          toggle(faq.id)
        } label: {
          HStack(spacing: 10) {
            Image(systemSymbol: selectedFAQIDs.contains(faq.id) ? .checkmarkCircleFill : .circle)
              .foregroundStyle(selectedFAQIDs.contains(faq.id) ? Color.accentColor : Color.secondary)

            Text(faq.titleText)
              .lineLimit(2)

            Spacer(minLength: 0)
          }
        }
        .buttonStyle(.plain)
      }
      .searchable(text: $searchText, prompt: "Search FAQ titles")
      .navigationTitle("Assign FAQs")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(selectedFAQIDs)
            dismiss()
          }
        }
      }
      .frame(minWidth: 520, minHeight: 520)
    }
  }

  private var filteredFAQs: [DashboardKnowledge] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return faqEntries }

    return faqEntries.filter {
      $0.titleText.localizedCaseInsensitiveContains(query)
    }
  }

  private func toggle(_ id: DashboardKnowledge.ID) {
    if selectedFAQIDs.contains(id) {
      selectedFAQIDs.remove(id)
    } else {
      selectedFAQIDs.insert(id)
    }
  }
}
