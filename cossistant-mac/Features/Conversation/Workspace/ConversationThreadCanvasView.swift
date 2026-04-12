import SwiftUI
import SFSafeSymbols

struct ConversationThreadCanvasView: View {
  let website: DashboardWebsite?
  let conversation: DashboardConversation
  let visitor: DashboardVisitor?
  let visitorPresence: DashboardVisitorPresence?
  let timelineItems: [DashboardTimelineItem]
  let seenData: [DashboardConversationSeen]
  let typingEvent: DashboardRealtimeConversationTypingPayload?
  let aiProcessingState: DashboardRealtimeAIProcessingState?
  let realtimeConnectionState: DashboardRealtimeConnectionState
  let loadState: ConversationSelectionLoadState
  let showDeveloperLogs: Bool
  let translatedMessagesByID: [String: DashboardMessageTranslation]
  let translatedClarification: DashboardMessageTranslation?
  let canLoadMoreTimeline: Bool
  let isLoadingMoreTimeline: Bool
  let onLoadMoreTimeline: () -> Void

  @State private var dismissedClarificationRequestID: String?

  var body: some View {
    VStack(spacing: 0) {
      if let clarification = conversation.activeClarification,
         dismissedClarificationRequestID != clarification.requestId {
        ConversationClarificationPanel(
          conversation: conversation,
          translatedQuestion: translatedClarification?.text,
          onDismiss: {
            dismissedClarificationRequestID = clarification.requestId
          }
        )
        .padding(.horizontal, ConversationWorkspaceLayout.panePadding)
        .padding(.vertical, 16)

        Divider()
      }

      if typingEvent != nil || aiProcessingState != nil {
        ConversationLiveStatusSection(
          website: website,
          conversation: conversation,
          visitor: visitor,
          visitorPresence: visitorPresence,
          typingEvent: typingEvent,
          aiProcessingState: aiProcessingState
        )
        .padding(.horizontal, ConversationWorkspaceLayout.panePadding)
        .padding(.vertical, 16)

        Divider()
      }

      threadContent
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .onChange(of: conversation.activeClarification?.requestId) { _, newRequestID in
      if dismissedClarificationRequestID != newRequestID {
        dismissedClarificationRequestID = nil
      }
    }
  }

  @ViewBuilder
  private var threadContent: some View {
    switch loadState {
    case .idle where timelineItems.isEmpty, .loading where timelineItems.isEmpty:
      VStack(spacing: 14) {
        ProgressView()
          .controlSize(.large)

        Text("Loading conversation activity…")
          .font(.title3.weight(.medium))
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

    case .failed(let message) where timelineItems.isEmpty:
      ContentUnavailableView(
        "Timeline Unavailable",
        systemImage: SFSymbol.exclamationmarkTriangle.rawValue,
        description: Text(message)
      )

    default:
      ScrollView {
        ConversationTimelineView(
          website: website,
          conversation: conversation,
          visitor: visitor,
          items: timelineItems,
          seenData: seenData,
          translatedMessagesByID: translatedMessagesByID,
          showDeveloperLogs: showDeveloperLogs,
          canLoadMoreTimeline: canLoadMoreTimeline,
          isLoadingMoreTimeline: isLoadingMoreTimeline,
          onLoadMoreTimeline: onLoadMoreTimeline
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, ConversationWorkspaceLayout.panePadding)
        .padding(.top, 28)
        .padding(.bottom, 34)
      }
      .background(Color.clear)
    }
  }
}

private struct ConversationClarificationPanel: View {
  let conversation: DashboardConversation
  let translatedQuestion: String?
  let onDismiss: () -> Void

  var body: some View {
    guard let clarification = conversation.activeClarification else {
      return AnyView(EmptyView())
    }

    return AnyView(
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemSymbol: .questionmarkBubbleFill)
            .font(.title3)
            .foregroundStyle(.indigo)

          VStack(alignment: .leading, spacing: 4) {
            Text("Knowledge Clarification")
              .font(.headline)

            Text(clarificationStatusSummary(for: clarification))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Spacer(minLength: 0)

          Button {
            onDismiss()
          } label: {
            Image(systemSymbol: .xmark)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.tertiary)
          }
          .buttonStyle(.plain)
          .help("Dismiss clarification")

          WorkspaceInlineBadge(
            title: clarification.status.replacingOccurrences(of: "_", with: " ").capitalized,
            systemImage: .sparklesRectangleStack,
            tint: .indigo
          )
        }

        if let question = displayedQuestion(for: clarification),
           !question.isEmpty {
          Text(question)
            .font(.body)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Text("The Mac client currently shows the live clarification state and prompt. The interactive answer, retry, and draft-review flow still depends on the newer clarification APIs used by the web dashboard.")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      .padding(16)
      .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    )
  }

  private func clarificationStatusSummary(for clarification: DashboardConversation.Clarification) -> String {
    let updatedText = DashboardTimestampParser.relativeString(from: clarification.updatedAt) ?? clarification.updatedAt
    return "Updated \(updatedText)"
  }

  private func displayedQuestion(
    for clarification: DashboardConversation.Clarification
  ) -> String? {
    let originalQuestion = clarification.question?.trimmingCharacters(in: .whitespacesAndNewlines)
    let translatedQuestion = translatedQuestion?.trimmingCharacters(in: .whitespacesAndNewlines)

    if let translatedQuestion, !translatedQuestion.isEmpty, translatedQuestion != originalQuestion {
      return translatedQuestion
    }

    return originalQuestion
  }
}
