import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct FAQResolverConversationInspectorView: View {
  let conversation: DashboardConversation?
  let visitor: DashboardVisitor?
  let timelineItems: [DashboardTimelineItem]
  let seenData: [DashboardConversationSeen]
  let translatedMessagesByID: [String: DashboardMessageTranslation]
  let showBackendTranslatedSubjects: Bool
  let canUseMessageTranslations: Bool
  let showTranslations: Bool
  let isTranslatingMessages: Bool
  let translationErrorMessage: String?
  let loadState: ConversationSelectionLoadState
  let canLoadMoreTimeline: Bool
  let isLoadingMoreTimeline: Bool
  let onOpenConversation: (String) -> Void
  let onMarkSeen: (String) async -> Void
  let onMarkUnseen: (String) async -> Void
  let onResolveConversation: (String) async -> Void
  let onReopenConversation: (String) async -> Void
  let onSetShowTranslations: (Bool) async -> Void
  let onLoadMoreTimeline: () -> Void

  private var messageTimelineItems: [DashboardTimelineItem] {
    timelineItems
      .filter { $0.type == .message }
      .filter { $0.deletedAt == nil }
  }

  var body: some View {
    VStack(spacing: 0) {
      header

      Divider()

      threadContent
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(.thinMaterial)
  }

  @ViewBuilder
  private var threadContent: some View {
    if let conversation {
      switch loadState {
      case .idle where messageTimelineItems.isEmpty, .loading where messageTimelineItems.isEmpty:
        VStack(spacing: 14) {
          ProgressView()
            .controlSize(.large)

          Text("Loading conversation messages...")
            .font(.title3.weight(.medium))
            .foregroundStyle(.secondary)
        }
      case .failed(let message) where messageTimelineItems.isEmpty:
        ContentUnavailableView(
          "Preview Unavailable",
          systemImage: SFSymbol.exclamationmarkTriangle.rawValue,
          description: Text(message)
        )
      default:
        ScrollView {
          ConversationTimelineView(
            website: nil,
            conversation: conversation,
            visitor: visitor,
            items: messageTimelineItems,
            seenData: seenData,
            translatedMessagesByID: translatedMessagesByID,
            showDeveloperLogs: false,
            canLoadMoreTimeline: canLoadMoreTimeline,
            isLoadingMoreTimeline: isLoadingMoreTimeline,
            onLoadMoreTimeline: onLoadMoreTimeline,
            presentation: nil
          )
          .frame(maxWidth: .infinity)
          .padding(.horizontal, 20)
          .padding(.top, 24)
          .padding(.bottom, 28)
        }
      }
    } else {
      ContentUnavailableView(
        "Select a conversation",
        systemImage: SFSymbol.bubbleLeftAndBubbleRight.rawValue,
        description: Text("Pick an eligible conversation to inspect its messages here.")
      )
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Conversation Preview")
            .font(.headline)

          Text(headerSubtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        Spacer(minLength: 0)

        if canUseMessageTranslations || showTranslations || translationErrorMessage != nil {
          Toggle(isOn: Binding(
            get: { showTranslations },
            set: { isEnabled in
              Task {
                await onSetShowTranslations(isEnabled)
              }
            }
          )) {
            Image(systemSymbol: .translate)
              .font(.caption.weight(.medium))
              .foregroundStyle(isTranslatingMessages ? .primary : .secondary)
          }
          .toggleStyle(.switch)
          .controlSize(.small)
          .help(isTranslatingMessages ? "Translating messages" : "Show translations")
        }
      }

      if let translationErrorMessage, !translationErrorMessage.isEmpty {
        Label(translationErrorMessage, systemSymbol: .exclamationmarkTriangle)
          .font(.caption)
          .foregroundStyle(.orange)
      }

      if let conversation {
        HStack(spacing: 8) {
          WorkspaceMetadataPill(
            title: conversation.status.label,
            systemImage: .circleFill,
            tint: conversation.status.tint
          )

          WorkspaceMetadataPill(
            title: conversation.priority.label,
            systemImage: .flagFill,
            tint: conversation.priority.tint
          )

          if conversation.needsHumanIntervention {
            WorkspaceMetadataPill(
              title: "Escalated",
              systemImage: .personFillBadgePlus,
              tint: .orange
            )
          } else if conversation.needsClarification {
            WorkspaceMetadataPill(
              title: "Clarification",
              systemImage: .questionmarkBubbleFill,
              tint: .indigo
            )
          }
        }

        actionButtons(for: conversation)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
  }

  private func actionButtons(for conversation: DashboardConversation) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 8) {
        inspectorButtons(for: conversation)
      }

      VStack(alignment: .leading, spacing: 8) {
        inspectorButtons(for: conversation)
      }
    }
    .controlSize(.small)
  }

  @ViewBuilder
  private func inspectorButtons(for conversation: DashboardConversation) -> some View {
    Button {
      onOpenConversation(conversation.id)
    } label: {
      Label("Open Conversation", systemSymbol: .arrowUpRightSquare)
    }

    if conversation.hasUnreadActivity {
      Button {
        Task {
          await onMarkSeen(conversation.id)
        }
      } label: {
        Label("Set Seen", systemSymbol: .checkmarkCircle)
      }
    } else {
      Button {
        Task {
          await onMarkUnseen(conversation.id)
        }
      } label: {
        Label("Set Unseen", systemSymbol: .eyeSlash)
      }
    }

    if conversation.status == .open {
      Button {
        Task {
          await onResolveConversation(conversation.id)
        }
      } label: {
        Label("Resolve", systemSymbol: .checkmark)
      }
    } else if conversation.status == .resolved {
      Button {
        Task {
          await onReopenConversation(conversation.id)
        }
      } label: {
        Label("Re-open", systemSymbol: .arrowCounterclockwise)
      }
    }
  }

  private var headerSubtitle: String {
    guard let conversation else {
      return "Messages only"
    }

    switch loadState {
    case .loading where messageTimelineItems.isEmpty:
      return "Loading messages for \(conversation.visitorDisplayName)"
    case .failed(let message) where messageTimelineItems.isEmpty:
      return message
    default:
      return conversation.displayTitle(showBackendTranslatedSubjects: showBackendTranslatedSubjects)
    }
  }
}
