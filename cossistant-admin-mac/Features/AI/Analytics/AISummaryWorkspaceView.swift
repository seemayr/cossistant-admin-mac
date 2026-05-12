import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct AISummaryWorkspaceView: View {
  @Bindable var store: AnalyticsStore
  let availableChannelFilters: () -> [InboxChannelFilterOption]
  let availableMetadataFilters: () -> [InboxMetadataFilterSection]
  let availableAppVersionFilters: () -> [AutoResolveTextFilterOption]
  let availableGameIDFilters: () -> [AutoResolveTextFilterOption]
  let onGenerateSummary: () -> Void
  let onReset: () -> Void
  let onCopySourceDocument: () -> Void
  let onSendFollowUp: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("Summarize")
          .font(.title.weight(.semibold))

        analyticsRangeCard

        if let status = store.summaryStatusMessage {
          Label(status, systemSymbol: .clockArrowTriangleheadCounterclockwiseRotate90)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        if let error = store.summaryErrorMessage {
          Label(error, systemSymbol: .exclamationmarkTriangleFill)
            .font(.subheadline)
            .foregroundStyle(.red)
        }

        if store.conversationCount > 0 {
          analyticsStatsCard
        }

        analyticsConversationCard
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
      .textSelection(.enabled)
    }
  }

  private var analyticsRangeCard: some View {
    PrototypeInfoCard(title: "Range") {
      Picker("Range", selection: $store.rangeMode) {
        ForEach(AnalyticsSummaryRangeMode.allCases) { mode in
          Text(mode.label)
            .tag(mode)
        }
      }
      .pickerStyle(.segmented)

      switch store.rangeMode {
      case .lastHours:
        Stepper(value: $store.lastHours, in: 1...168) {
          Text("Last \(store.lastHours) hour\(store.lastHours == 1 ? "" : "s")")
        }
      case .lastDays:
        Stepper(value: $store.lastDays, in: 1...90) {
          Text("Last \(store.lastDays) day\(store.lastDays == 1 ? "" : "s")")
        }
      case .custom:
        VStack(alignment: .leading, spacing: 12) {
          DatePicker(
            "Start",
            selection: $store.customStartDate,
            displayedComponents: [.date, .hourAndMinute]
          )
          DatePicker(
            "End",
            selection: $store.customEndDate,
            displayedComponents: [.date, .hourAndMinute]
          )
        }
      }

      analyticsFilterControls

      if !store.hasOpenAIAPIKey {
        Label("Add an OpenAI API key in Settings to enable conversation summaries.", systemSymbol: .keyFill)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      HStack {
        Button(store.isGeneratingSummary ? "Generating…" : "Generate Summary") {
          onGenerateSummary()
        }
        .disabled(!store.canGenerateSummary)

        Button("Reset") {
          onReset()
        }
        .disabled(
          store.summaryMessages.isEmpty
            && store.sourceDocument == nil
            && store.summaryStatusMessage == nil
        )

        Spacer()

        if let dateRange = store.selectedDateRange {
          Text(dateRange.label)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var analyticsFilterControls: some View {
    VStack(alignment: .leading, spacing: 8) {
      LazyVGrid(columns: analyticsFilterColumns, alignment: .leading, spacing: 8) {
        if !availableChannelFilters().isEmpty {
          channelFilterMenu
        }

        filterMenu(
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

        filterMenu(
          title: "Status",
          value: store.statusFilter.label,
          systemImage: .circleFill
        ) {
          Picker("Status", selection: $store.statusFilter) {
            ForEach(AnalyticsSummaryStatusFilter.allCases) { filter in
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
      .disabled(store.isGeneratingSummary || store.isSendingFollowUp)

      if store.hasActiveConversationFilters {
        Button("Clear Conversation Filters") {
          store.clearConversationFilters()
        }
        .buttonStyle(.borderless)
        .font(.caption.weight(.medium))
        .disabled(store.isGeneratingSummary || store.isSendingFollowUp)
      }
    }
  }

  private var analyticsFilterColumns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(minimum: 140), spacing: 8, alignment: .leading),
      count: 3
    )
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

  private var analyticsStatsCard: some View {
    PrototypeInfoCard(title: "Run Details") {
      PrototypeFact(label: "Range", value: store.summaryRangeLabel ?? "Not generated yet")
      PrototypeFact(label: "Conversations", value: String(store.conversationCount))
      PrototypeFact(label: "Messages", value: String(store.sourceMessageCount))
      PrototypeFact(
        label: "OpenAI Mode",
        value: store.summaryUsedChunking ? "Chunked synthesis" : "Single request"
      )

      if let generatedAt = store.summaryGeneratedAt {
        PrototypeFact(
          label: "Generated",
          value: generatedAt.formatted(.dateTime.year().month().day().hour().minute())
        )
      }

      HStack {
        Button("Copy Source Markdown") {
          onCopySourceDocument()
        }
        .disabled(store.sourceDocument == nil)

        if let sourceDocument = store.sourceDocument {
          Text("\(sourceDocument.count) characters of source context")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var analyticsConversationCard: some View {
    PrototypeInfoCard(title: "Summary Thread") {
      if store.summaryMessages.isEmpty {
        ContentUnavailableView(
          "No summary yet",
          systemImage: SFSymbol.textBubble.rawValue,
          description: Text("Generate a summary to start asking follow-up questions.")
        )
      } else {
        VStack(alignment: .leading, spacing: 14) {
          ForEach(store.summaryMessages) { message in
            AnalyticsChatBubble(message: message)
          }

          Divider()

          VStack(alignment: .leading, spacing: 10) {
            TextField(
              "Ask a follow-up question about the recent complaints…",
              text: $store.followUpDraft,
              axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...4)

            HStack {
              Spacer()

              Button(store.isSendingFollowUp ? "Sending…" : "Ask Follow-Up") {
                onSendFollowUp()
              }
              .disabled(!store.canSendFollowUp)
            }
          }
        }
      }
    }
  }
}

private struct AnalyticsChatBubble: View {
  let message: AnalyticsSummaryChatMessage

  var body: some View {
    VStack(alignment: message.role == .assistant ? .leading : .trailing, spacing: 6) {
      Text(message.role == .assistant ? "AI Summary" : "You")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      Text(displayText)
        .textSelection(.enabled)
        .lineSpacing(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(backgroundStyle)
        .clipShape(.rect(cornerRadius: 16))

      Text(message.createdAt.formatted(.dateTime.hour().minute()))
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, alignment: message.role == .assistant ? .leading : .trailing)
  }

  private var backgroundStyle: some ShapeStyle {
    switch message.role {
    case .assistant:
      return AnyShapeStyle(.quinary)
    case .user:
      return AnyShapeStyle(.blue.opacity(0.12))
    }
  }

  private var displayText: String {
    guard message.role == .assistant else { return message.text }
    return message.text.analyticsSummaryDisplayText
  }
}

private extension String {
  var analyticsSummaryDisplayText: String {
    let normalized = replacingOccurrences(of: "\r\n", with: "\n")
    let lines = normalized.components(separatedBy: "\n")
    var displayLines: [String] = []

    for rawLine in lines {
      let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

      guard !trimmed.isEmpty else {
        if displayLines.last?.isEmpty == false {
          displayLines.append("")
        }
        continue
      }

      if let heading = trimmed.firstMarkdownHeadingLine {
        if !displayLines.isEmpty, displayLines.last?.isEmpty == false {
          displayLines.append("")
        }
        displayLines.append(heading)
        displayLines.append("")
        continue
      }

      if let bullet = trimmed.firstMarkdownBulletLine {
        displayLines.append("• \(bullet)")
        continue
      }

      displayLines.append(rawLine)
    }

    while displayLines.last?.isEmpty == true {
      displayLines.removeLast()
    }

    return displayLines.joined(separator: "\n")
  }

  var firstMarkdownHeadingLine: String? {
    let line = trimmingCharacters(in: .whitespaces)
    let hashes = line.prefix { $0 == "#" }
    guard !hashes.isEmpty else { return nil }

    let remainder = line.dropFirst(hashes.count).trimmingCharacters(in: .whitespaces)
    return remainder.isEmpty ? nil : remainder
  }

  var firstMarkdownBulletLine: String? {
    let line = trimmingCharacters(in: .whitespaces)

    if line.hasPrefix("- ") || line.hasPrefix("* ") {
      let bullet = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
      return bullet.isEmpty ? nil : bullet
    }

    return nil
  }
}
