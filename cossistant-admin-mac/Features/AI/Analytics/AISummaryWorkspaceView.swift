import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct AISummaryWorkspaceView: View {
  @Bindable var store: AnalyticsStore
  let onGenerateSummary: () -> Void
  let onReset: () -> Void
  let onCopySourceDocument: () -> Void
  let onSendFollowUp: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Summarize")
          .font(.largeTitle.weight(.semibold))

        Text("Summarize recent support problems across many conversations, then ask follow-up questions against the same AI thread.")
          .font(.title3)
          .foregroundStyle(.secondary)

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
    PrototypeInfoCard(title: "Summary Range") {
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
          Text("Analyze conversations active in the last \(store.lastHours) hour\(store.lastHours == 1 ? "" : "s").")
        }
      case .lastDays:
        Stepper(value: $store.lastDays, in: 1...90) {
          Text("Analyze conversations active in the last \(store.lastDays) day\(store.lastDays == 1 ? "" : "s").")
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
    PrototypeInfoCard(title: "AI Conversation") {
      if store.summaryMessages.isEmpty {
        ContentUnavailableView(
          "No summary yet",
          systemImage: SFSymbol.textBubble.rawValue,
          description: Text("Pick a time range, generate a summary, and then use follow-up questions to dig into recurring complaints or reported bugs.")
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
