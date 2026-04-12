import SwiftUI
import SFSafeSymbols

struct AIAutoResolveWorkspaceView: View {
  @Bindable var store: AutoResolveStore
  let inspectedConversation: DashboardConversation?
  let inspectedVisitor: DashboardVisitor?
  let inspectedTimelineItems: [DashboardTimelineItem]
  let inspectedSeenData: [DashboardConversationSeen]
  let translatedMessagesByID: [String: DashboardMessageTranslation]
  let canUseMessageTranslations: Bool
  let showTranslations: Bool
  let isTranslatingMessages: Bool
  let translationErrorMessage: String?
  let loadState: ConversationSelectionLoadState
  let canLoadMoreTimeline: Bool
  let isLoadingMoreTimeline: Bool
  let canStart: Bool
  let onStart: () -> Void
  let onCancel: () -> Void
  let onClearResults: () -> Void
  let onInspectConversation: (String) async -> Void
  let onOpenConversation: (String) -> Void
  let onResolveAnyway: (String) async -> Void
  let onMarkAsSeen: (String) async -> Void
  let onSetShowTranslations: (Bool) async -> Void
  let onLoadMoreTimeline: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text("Auto-Resolve")
            .font(.largeTitle.weight(.semibold))

          Text("Review recent conversations one by one with AI, automatically resolve safe cases, and inspect a running decision list as results come in.")
            .font(.title3)
            .foregroundStyle(.secondary)

          autoResolveControlsCard

          if let status = store.statusMessage {
            Label(
              status,
              systemSymbol: store.isRunning ? .clockArrowTriangleheadCounterclockwiseRotate90 : .sparkles
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
          }

          autoResolveResultsCard
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
      }

      Divider()

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

      Text("Conversations are reviewed conservatively. Empty conversations resolve immediately. Feedback and idea-only threads also resolve, while anything waiting on a person stays open.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if !store.hasOpenAIAPIKey {
        Label("Add an OpenAI API key in Settings to enable auto-resolve.", systemSymbol: .keyFill)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      HStack {
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

        Spacer()
      }
    }
  }

  private var autoResolveResultsCard: some View {
    PrototypeInfoCard(title: "Review Results (\(store.results.count))") {
      if store.results.isEmpty {
        ContentUnavailableView(
          "No review results yet",
          systemImage: SFSymbol.sparkles.rawValue,
          description: Text("Start the workflow to build a per-conversation list of AI resolve decisions.")
        )
      } else {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(store.results) { result in
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
              }
            )
          }
        }
      }
    }
  }

  private var autoResolveInspectorColumn: some View {
    AutoResolveConversationInspectorView(
      conversation: inspectedConversation,
      visitor: inspectedVisitor,
      timelineItems: inspectedTimelineItems,
      seenData: inspectedSeenData,
      translatedMessagesByID: translatedMessagesByID,
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

private struct AutoResolveResultRow: View {
  let result: AutoResolveResult
  let isSelected: Bool
  let onInspectConversation: () async -> Void
  let onOpenConversation: () -> Void
  let onResolveAnyway: () async -> Void
  let onMarkAsSeen: () async -> Void
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

        if !result.isSeen {
          Button(result.isMarkingSeen ? "Marking seen..." : "Mark as seen") {
            Task {
              await onMarkAsSeen()
            }
          }
          .buttonStyle(.borderless)
          .font(.caption)
          .disabled(result.isMarkingSeen)
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
}
