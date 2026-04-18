import SwiftUI
import SFSafeSymbols
import CossistantAdmin

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
  let timelinePresentation: DashboardTimelinePresentationBundle?
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
          onLoadMoreTimeline: onLoadMoreTimeline,
          presentation: timelinePresentation
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

  @ViewBuilder
  var body: some View {
    if let clarification = conversation.activeClarification {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemSymbol: .questionmarkBubbleFill)
            .font(.title3)
            .foregroundStyle(.indigo)
            .frame(width: 24, height: 24)

          VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
              Text("Knowledge Clarification")
                .font(.headline)

              WorkspaceInlineBadge(
                title: clarification.status.replacingOccurrences(of: "_", with: " ").capitalized,
                systemImage: .sparklesRectangleStack,
                tint: .indigo
              )
            }

            Text(clarificationStatusSummary(for: clarification))
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer(minLength: 0)

          Button {
            onDismiss()
          } label: {
            Image(systemSymbol: .xmark)
              .font(.caption.weight(.semibold))
              .frame(width: 24, height: 24)
          }
          .buttonStyle(.plain)
          .foregroundStyle(.tertiary)
          .background(.quaternary.opacity(0.16), in: Circle())
          .contentShape(Circle())
          .help("Dismiss clarification")
          .accessibilityLabel("Dismiss clarification")
        }

        if let question = displayedQuestion(for: clarification),
           !question.isEmpty {
          Text(question)
            .font(.body)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Text("Reply, retry, and draft review still use the newer clarification workflow in the web dashboard.")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      .padding(16)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .strokeBorder(.separator.opacity(0.14), lineWidth: 1)
      }
    }
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
