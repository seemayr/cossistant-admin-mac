import AppKit
import SwiftUI
import SFSafeSymbols
import UniformTypeIdentifiers

private enum ConversationWorkspaceLayout {
  static let threadMinWidth: CGFloat = 540
  static let threadMaxWidth: CGFloat = 860
  static let inspectorMinWidth: CGFloat = 240
  static let inspectorIdealWidth: CGFloat = 320
  static let inspectorMaxWidth: CGFloat = 360
  static let panePadding: CGFloat = 24
  static let cardCornerRadius: CGFloat = 20
}

struct ConversationWorkspaceView: View {
  let website: DashboardWebsite?
  let conversation: DashboardConversation
  let detail: DashboardConversationDetail?
  let visitor: DashboardVisitor?
  let visitorPresence: DashboardVisitorPresence?
  let seenData: [DashboardConversationSeen]
  let timelineItems: [DashboardTimelineItem]
  let typingEvent: DashboardRealtimeConversationTypingPayload?
  let aiProcessingState: DashboardRealtimeAIProcessingState?
  let realtimeConnectionState: DashboardRealtimeConnectionState
  let showDeveloperLogs: Bool
  let onToggleDeveloperLogs: (Bool) -> Void
  let canUseMessageTranslations: Bool
  let showTranslations: Bool
  let onToggleTranslations: (Bool) -> Void
  let translatedMessagesByID: [String: DashboardMessageTranslation]
  let isTranslatingMessages: Bool
  let translationErrorMessage: String?
  let showInspector: Bool
  let onToggleInspector: (Bool) -> Void
  let onSendMessage: @MainActor (String, DashboardTimelineItemVisibility, [DashboardComposerAttachment]) async -> Void
  let canUseOpenAIReplyDrafts: Bool
  let isGeneratingReplyDraft: Bool
  let replyDraftErrorMessage: String?
  let onGenerateReplyDraft: @MainActor (String) async -> String?
  let isCopyingConversationMessages: Bool
  let onCopyConversationMessages: () -> Void
  let onCopyConversationFullLog: () -> Void
  let onMarkConversationSeen: @MainActor () async -> Void
  let onMarkConversationUnread: @MainActor () async -> Void
  let onArchiveConversation: @MainActor () async -> Void
  let onUnarchiveConversation: @MainActor () async -> Void
  let onResolveConversation: @MainActor () async -> Void
  let onReopenConversation: @MainActor () async -> Void
  let onMarkConversationSpam: @MainActor () async -> Void
  let onMarkConversationNotSpam: @MainActor () async -> Void
  let onUpdateConversationTitle: @MainActor (String?) async -> Void
  let onJoinConversationEscalation: @MainActor () async -> Void
  let onPauseConversationAI: @MainActor (Int) async -> Void
  let onResumeConversationAI: @MainActor () async -> Void
  let loadState: ConversationSelectionLoadState
  let canLoadMoreTimeline: Bool
  let isLoadingMoreTimeline: Bool
  let onLoadMoreTimeline: () -> Void

  var body: some View {
    Group {
      if showInspector {
        HSplitView {
          threadColumn
          inspectorColumn
        }
      } else {
        threadColumn
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.clear)
  }

  private var threadColumn: some View {
    ConversationThreadWorkspaceColumn(
      website: website,
      conversation: conversation,
      detail: detail,
      visitor: visitor,
      visitorPresence: visitorPresence,
      seenData: seenData,
      timelineItems: timelineItems,
      typingEvent: typingEvent,
      aiProcessingState: aiProcessingState,
      realtimeConnectionState: realtimeConnectionState,
      showDeveloperLogs: showDeveloperLogs,
      onToggleDeveloperLogs: onToggleDeveloperLogs,
      canUseMessageTranslations: canUseMessageTranslations,
      showInspector: showInspector,
      onToggleInspector: onToggleInspector,
      showTranslations: showTranslations,
      onToggleTranslations: onToggleTranslations,
      isTranslatingMessages: isTranslatingMessages,
      translationErrorMessage: translationErrorMessage,
      isCopyingConversationMessages: isCopyingConversationMessages,
      onCopyConversationMessages: onCopyConversationMessages,
      onCopyConversationFullLog: onCopyConversationFullLog,
      onMarkConversationSeen: onMarkConversationSeen,
      onMarkConversationUnread: onMarkConversationUnread,
      onArchiveConversation: onArchiveConversation,
      onUnarchiveConversation: onUnarchiveConversation,
      onResolveConversation: onResolveConversation,
      onReopenConversation: onReopenConversation,
      onMarkConversationSpam: onMarkConversationSpam,
      onMarkConversationNotSpam: onMarkConversationNotSpam,
      onUpdateConversationTitle: onUpdateConversationTitle,
      onJoinConversationEscalation: onJoinConversationEscalation,
      onPauseConversationAI: onPauseConversationAI,
      onResumeConversationAI: onResumeConversationAI,
      onSendMessage: onSendMessage,
      canUseOpenAIReplyDrafts: canUseOpenAIReplyDrafts,
      isGeneratingReplyDraft: isGeneratingReplyDraft,
      replyDraftErrorMessage: replyDraftErrorMessage,
      onGenerateReplyDraft: onGenerateReplyDraft,
      loadState: loadState,
      translatedMessagesByID: translatedMessagesByID,
      canLoadMoreTimeline: canLoadMoreTimeline,
      isLoadingMoreTimeline: isLoadingMoreTimeline,
      onLoadMoreTimeline: onLoadMoreTimeline
    )
    .frame(
      minWidth: ConversationWorkspaceLayout.threadMinWidth,
      maxWidth: .infinity,
      maxHeight: .infinity
    )
  }

  private var inspectorColumn: some View {
    ConversationInspectorView(
      conversation: conversation,
      detail: detail,
      visitor: visitor,
      visitorPresence: visitorPresence,
      seenData: seenData,
      realtimeConnectionState: realtimeConnectionState
    )
    .frame(
      minWidth: ConversationWorkspaceLayout.inspectorMinWidth,
      idealWidth: ConversationWorkspaceLayout.inspectorIdealWidth,
      maxWidth: ConversationWorkspaceLayout.inspectorMaxWidth,
      maxHeight: .infinity
    )
  }
}

private struct ConversationThreadWorkspaceColumn: View {
  let website: DashboardWebsite?
  let conversation: DashboardConversation
  let detail: DashboardConversationDetail?
  let visitor: DashboardVisitor?
  let visitorPresence: DashboardVisitorPresence?
  let seenData: [DashboardConversationSeen]
  let timelineItems: [DashboardTimelineItem]
  let typingEvent: DashboardRealtimeConversationTypingPayload?
  let aiProcessingState: DashboardRealtimeAIProcessingState?
  let realtimeConnectionState: DashboardRealtimeConnectionState
  let showDeveloperLogs: Bool
  let onToggleDeveloperLogs: (Bool) -> Void
  let canUseMessageTranslations: Bool
  let showInspector: Bool
  let onToggleInspector: (Bool) -> Void
  let showTranslations: Bool
  let onToggleTranslations: (Bool) -> Void
  let isTranslatingMessages: Bool
  let translationErrorMessage: String?
  let isCopyingConversationMessages: Bool
  let onCopyConversationMessages: () -> Void
  let onCopyConversationFullLog: () -> Void
  let onMarkConversationSeen: @MainActor () async -> Void
  let onMarkConversationUnread: @MainActor () async -> Void
  let onArchiveConversation: @MainActor () async -> Void
  let onUnarchiveConversation: @MainActor () async -> Void
  let onResolveConversation: @MainActor () async -> Void
  let onReopenConversation: @MainActor () async -> Void
  let onMarkConversationSpam: @MainActor () async -> Void
  let onMarkConversationNotSpam: @MainActor () async -> Void
  let onUpdateConversationTitle: @MainActor (String?) async -> Void
  let onJoinConversationEscalation: @MainActor () async -> Void
  let onPauseConversationAI: @MainActor (Int) async -> Void
  let onResumeConversationAI: @MainActor () async -> Void
  let onSendMessage: @MainActor (String, DashboardTimelineItemVisibility, [DashboardComposerAttachment]) async -> Void
  let canUseOpenAIReplyDrafts: Bool
  let isGeneratingReplyDraft: Bool
  let replyDraftErrorMessage: String?
  let onGenerateReplyDraft: @MainActor (String) async -> String?
  let loadState: ConversationSelectionLoadState
  let translatedMessagesByID: [String: DashboardMessageTranslation]
  let canLoadMoreTimeline: Bool
  let isLoadingMoreTimeline: Bool
  let onLoadMoreTimeline: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      ConversationThreadHeaderView(
        conversation: conversation,
        detail: detail,
        visitor: visitor,
        visitorPresence: visitorPresence,
        realtimeConnectionState: realtimeConnectionState,
        showDeveloperLogs: showDeveloperLogs,
        onToggleDeveloperLogs: onToggleDeveloperLogs,
        canUseMessageTranslations: canUseMessageTranslations,
        showTranslations: showTranslations,
        onToggleTranslations: onToggleTranslations,
        isTranslatingMessages: isTranslatingMessages,
        translationErrorMessage: translationErrorMessage,
        showInspector: showInspector,
        onToggleInspector: onToggleInspector,
        isCopyingConversationMessages: isCopyingConversationMessages,
        onCopyConversationMessages: onCopyConversationMessages,
        onCopyConversationFullLog: onCopyConversationFullLog,
        onMarkConversationSeen: onMarkConversationSeen,
        onMarkConversationUnread: onMarkConversationUnread,
        onArchiveConversation: onArchiveConversation,
        onUnarchiveConversation: onUnarchiveConversation,
        onResolveConversation: onResolveConversation,
        onReopenConversation: onReopenConversation,
        onMarkConversationSpam: onMarkConversationSpam,
        onMarkConversationNotSpam: onMarkConversationNotSpam,
        onUpdateConversationTitle: onUpdateConversationTitle,
        onJoinConversationEscalation: onJoinConversationEscalation,
        onPauseConversationAI: onPauseConversationAI,
        onResumeConversationAI: onResumeConversationAI
      )

      Divider()

      ConversationThreadCanvasView(
        website: website,
        conversation: conversation,
        visitor: visitor,
        visitorPresence: visitorPresence,
        timelineItems: timelineItems,
        seenData: seenData,
        typingEvent: typingEvent,
        aiProcessingState: aiProcessingState,
        realtimeConnectionState: realtimeConnectionState,
        loadState: loadState,
        showDeveloperLogs: showDeveloperLogs,
        translatedMessagesByID: translatedMessagesByID,
        canLoadMoreTimeline: canLoadMoreTimeline,
        isLoadingMoreTimeline: isLoadingMoreTimeline,
        onLoadMoreTimeline: onLoadMoreTimeline
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Divider()

      ConversationComposerView(
        canUseOpenAIReplyDrafts: canUseOpenAIReplyDrafts,
        isGeneratingReplyDraft: isGeneratingReplyDraft,
        replyDraftErrorMessage: replyDraftErrorMessage,
        onGenerateReplyDraft: onGenerateReplyDraft,
        onSendMessage: onSendMessage
      )
        .padding(.horizontal, ConversationWorkspaceLayout.panePadding)
        .padding(.vertical, 18)
        .background(.bar)
    }
    .background(Color.clear)
  }
}

private struct ConversationThreadHeaderView: View {
  let conversation: DashboardConversation
  let detail: DashboardConversationDetail?
  let visitor: DashboardVisitor?
  let visitorPresence: DashboardVisitorPresence?
  let realtimeConnectionState: DashboardRealtimeConnectionState
  let showDeveloperLogs: Bool
  let onToggleDeveloperLogs: (Bool) -> Void
  let canUseMessageTranslations: Bool
  let showTranslations: Bool
  let onToggleTranslations: (Bool) -> Void
  let isTranslatingMessages: Bool
  let translationErrorMessage: String?
  let showInspector: Bool
  let onToggleInspector: (Bool) -> Void
  let isCopyingConversationMessages: Bool
  let onCopyConversationMessages: () -> Void
  let onCopyConversationFullLog: () -> Void
  let onMarkConversationSeen: @MainActor () async -> Void
  let onMarkConversationUnread: @MainActor () async -> Void
  let onArchiveConversation: @MainActor () async -> Void
  let onUnarchiveConversation: @MainActor () async -> Void
  let onResolveConversation: @MainActor () async -> Void
  let onReopenConversation: @MainActor () async -> Void
  let onMarkConversationSpam: @MainActor () async -> Void
  let onMarkConversationNotSpam: @MainActor () async -> Void
  let onUpdateConversationTitle: @MainActor (String?) async -> Void
  let onJoinConversationEscalation: @MainActor () async -> Void
  let onPauseConversationAI: @MainActor (Int) async -> Void
  let onResumeConversationAI: @MainActor () async -> Void

  @State private var isEditingTitle = false
  var body: some View {
    HStack(alignment: .top, spacing: 18) {
      DashboardAvatarView(
        name: conversation.visitorDisplayName,
        imageURL: conversation.visitorAvatarURL,
        seed: conversation.visitorAvatarSeed,
        size: 38,
        showsActivePresence: visitorPresence?.isActive == true
      )

      VStack(alignment: .leading, spacing: 10) {
        Text(conversation.visitorDisplayName)
          .font(.title2.weight(.semibold))
          .lineLimit(1)

        HStack(spacing: 8) {
          Text(detail?.title ?? conversation.displayTitle)
            .font(.headline)
            .foregroundStyle(.secondary)
            .lineLimit(1)

          Button {
            isEditingTitle = true
          } label: {
            Image(systemSymbol: .pencil)
              .font(.caption.weight(.medium))
              .foregroundStyle(.tertiary)
          }
          .buttonStyle(.plain)
          .help("Edit title")
        }

        HStack(spacing: 8) {
          WorkspaceMetadataPill(
            title: detail?.status.label ?? conversation.status.label,
            systemImage: .circleFill,
            tint: detail?.status.tint ?? conversation.status.tint
          )

          WorkspaceMetadataPill(
            title: conversation.priority.label,
            systemImage: .flagFill,
            tint: conversation.priority.tint
          )

          WorkspaceMetadataPill(
            title: conversation.channelLabel,
            systemImage: .bubbleLeftAndBubbleRightFill,
            tint: .secondary
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

        headerDetails
      }

      Spacer(minLength: 20)

      VStack(alignment: .trailing, spacing: 12) {
        SyncStateBadge(state: realtimeConnectionState)

        Menu {
          if conversation.hasUnreadActivity {
            Button {
              Task {
                await onMarkConversationSeen()
              }
            } label: {
              Label("Mark Read", systemSymbol: .checkmarkCircle)
            }
          } else {
            Button {
              Task {
                await onMarkConversationUnread()
              }
            } label: {
              Label("Mark Unread", systemSymbol: .eyeSlash)
            }
          }

          Divider()

          if conversation.status == .open {
            Button {
              Task {
                await onResolveConversation()
              }
            } label: {
              Label("Resolve", systemSymbol: .checkmark)
            }

            Button {
              Task {
                await onMarkConversationSpam()
              }
            } label: {
              Label("Mark Spam", systemSymbol: .nosign)
            }
          } else if conversation.status == .resolved {
            Button {
              Task {
                await onReopenConversation()
              }
            } label: {
              Label("Reopen", systemSymbol: .arrowCounterclockwise)
            }
          } else if conversation.status == .spam {
            Button {
              Task {
                await onMarkConversationNotSpam()
              }
            } label: {
              Label("Not Spam", systemSymbol: .arrowUturnBackward)
            }
          }

          Divider()

          Button {
            onCopyConversationMessages()
          } label: {
            Label(
              messagesCopyButtonTitle,
              systemSymbol: .documentOnDocument
            )
          }

          Button {
            onCopyConversationFullLog()
          } label: {
            Label(
              fullLogCopyButtonTitle,
              systemSymbol: .textAlignleft
            )
          }

          Button {
            onToggleDeveloperLogs(!showDeveloperLogs)
          } label: {
            Label(
              showDeveloperLogs ? "Hide Dev Logs" : "Show Dev Logs",
              systemSymbol: .appleTerminal
            )
          }

          Divider()

          Button {
            isEditingTitle = true
          } label: {
            Label("Edit Title", systemSymbol: .pencil)
          }

          if conversation.needsHumanIntervention {
            Button {
              Task {
                await onJoinConversationEscalation()
              }
            } label: {
              Label("Join Escalation", systemSymbol: .personCropCircleBadgePlus)
            }
          }

          if conversation.isArchived {
            Button {
              Task {
                await onUnarchiveConversation()
              }
            } label: {
              Label("Unarchive", systemSymbol: .trayAndArrowUp)
            }
          } else {
            Button {
              Task {
                await onArchiveConversation()
              }
            } label: {
              Label("Archive", systemSymbol: .archivebox)
            }
          }

          Divider()

          if conversation.aiPausedUntil == nil {
            Button("Pause AI for 10-min") {
              Task {
                await onPauseConversationAI(10)
              }
            }

            Button("Pause AI for 1-hour") {
              Task {
                await onPauseConversationAI(60)
              }
            }

            Button("Pause AI until further notice") {
              Task {
                await onPauseConversationAI(60 * 24 * 365 * 100)
              }
            }
          } else {
            Button("Resume AI Answers") {
              Task {
                await onResumeConversationAI()
              }
            }
          }
        } label: {
          Text("More options")
            .font(.caption.weight(.medium))
        }
        .menuStyle(.borderlessButton)

        if canUseMessageTranslations || showTranslations || translationErrorMessage != nil {
          Toggle(isOn: Binding(
            get: { showTranslations },
            set: onToggleTranslations
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
      .fixedSize()
    }
    .padding(.horizontal, ConversationWorkspaceLayout.panePadding)
    .padding(.vertical, 18)
    .sheet(isPresented: $isEditingTitle) {
      ConversationTitleEditorSheetContent(
        initialTitle: detail?.title ?? conversation.title,
        onSave: onUpdateConversationTitle
      )
    }
  }

  @ViewBuilder
  private var headerDetails: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let email = visitor?.contact?.email ?? conversation.visitor.contact?.email,
         !email.isEmpty {
        HeaderDetailItem(
          systemImage: .envelope,
          value: email,
          allowsSelection: true
        )
      }

      if visitorPresence?.isActive == true {
        HeaderDetailItem(
          systemImage: .dotRadiowavesLeftAndRight,
          value: "Active now"
        )
      }

      HStack(spacing: 14) {
        HeaderDetailItem(
          systemImage: .calendar,
          value: conversation.createdRelativeText
        )

        HeaderDetailItem(
          systemImage: .clock,
          value: conversation.lastActivityRelativeText
        )
      }
    }
  }

  private var messagesCopyButtonTitle: String {
    if isCopyingConversationMessages {
      return "Copying Messages…"
    }

    return "Copy Messages"
  }

  private var fullLogCopyButtonTitle: String {
    if isCopyingConversationMessages {
      return "Copying Full Log…"
    }

    return "Copy Full Log"
  }
}

private struct ConversationTitleEditorSheetContent: View {
  let initialTitle: String?
  let onSave: @MainActor (String?) async -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var titleText = ""
  @State private var isSaving = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Conversation Title")
        .font(.title3.weight(.semibold))

      TextField("Untitled conversation", text: $titleText)
        .textFieldStyle(.roundedBorder)

      Text("Leave the field empty to remove the custom title.")
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack {
        Spacer()

        Button("Cancel") {
          dismiss()
        }

        Button(isSaving ? "Saving…" : "Save") {
          Task {
            isSaving = true
            await onSave(titleText.nilIfEmpty)
            isSaving = false
            dismiss()
          }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(isSaving)
      }
    }
    .padding(20)
    .frame(width: 420)
    .task {
      titleText = initialTitle ?? ""
    }
  }
}

private struct HeaderDetailItem: View {
  let systemImage: SFSymbol
  let value: String
  var allowsSelection = false

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(systemSymbol: systemImage)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tertiary)

      valueText
    }
  }

  @ViewBuilder
  private var valueText: some View {
    if allowsSelection {
      Text(value)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    } else {
      Text(value)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }
}

private struct ConversationThreadCanvasView: View {
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
  let canLoadMoreTimeline: Bool
  let isLoadingMoreTimeline: Bool
  let onLoadMoreTimeline: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      if conversation.activeClarification != nil {
        ConversationClarificationPanel(conversation: conversation)
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

          WorkspaceInlineBadge(
            title: clarification.status.replacingOccurrences(of: "_", with: " ").capitalized,
            systemImage: .sparklesRectangleStack,
            tint: .indigo
          )
        }

        if let question = clarification.question?.trimmingCharacters(in: .whitespacesAndNewlines),
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
}

private struct ConversationInspectorView: View {
  let conversation: DashboardConversation
  let detail: DashboardConversationDetail?
  let visitor: DashboardVisitor?
  let visitorPresence: DashboardVisitorPresence?
  let seenData: [DashboardConversationSeen]
  let realtimeConnectionState: DashboardRealtimeConnectionState

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Inspector")
          .font(.headline)

        Text("Visitor context and conversation state")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.vertical, 16)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          InspectorCard {
            HStack(alignment: .top, spacing: 14) {
              DashboardAvatarPreviewButton(
                name: conversation.visitorDisplayName,
                imageURL: visitor?.contact?.image ?? conversation.visitorAvatarURL,
                seed: visitor?.contact?.avatarSeed ?? conversation.visitorAvatarSeed,
                size: 46,
                showsActivePresence: visitorPresence?.isActive == true
              )

              VStack(alignment: .leading, spacing: 6) {
                Text(conversation.visitorDisplayName)
                  .font(.headline)

                if let email = visitor?.contact?.email ?? conversation.visitor.contact?.email {
                  Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                }

                Text("Visitor \(conversation.visitorId)")
                  .font(.caption)
                  .foregroundStyle(.tertiary)
                  .textSelection(.enabled)
              }

              Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
              WorkspaceInlineBadge(
                title: visitor?.isBlocked == true || conversation.visitor.isBlocked
                  ? "Blocked"
                  : visitorPresence?.isActive == true ? "Active now" : "Inactive",
                systemImage: visitor?.isBlocked == true || conversation.visitor.isBlocked
                  ? .handRaisedFill
                  : visitorPresence?.isActive == true ? .dotRadiowavesLeftAndRight : .personCropCircleBadgeCheckmark,
                tint: visitor?.isBlocked == true || conversation.visitor.isBlocked
                  ? .red
                  : visitorPresence?.isActive == true ? .green : .secondary
              )

              if let location = visitorLocation {
                WorkspaceInlineBadge(
                  title: location,
                  systemImage: .location,
                  tint: .secondary
                )
              }
            }
          }

          if let conversationMetadata = detail?.metadata ?? conversation.metadata,
             !conversationMetadata.isEmpty {
            InspectorCard(title: "Conversation Metadata") {
              InspectorMetadataList(metadata: conversationMetadata)
            }
          }

          if let clarification = conversation.activeClarification {
            InspectorCard(title: "Clarification") {
              InspectorFieldList(rows: [
                ("Status", clarification.status.replacingOccurrences(of: "_", with: " ").capitalized),
                ("Question", clarification.question?.nilIfEmpty ?? "No question text"),
                ("Updated", absoluteTime(for: clarification.updatedAt) ?? clarification.updatedAt),
                ("Request ID", clarification.requestId),
              ])
            }
          }

          if let visitor, let metadata = visitor.contact?.metadata, !metadata.isEmpty {
            InspectorCard(title: "Metadata") {
              InspectorMetadataList(metadata: metadata)
            }
          }

          InspectorCard(title: "Presence") {
            VStack(alignment: .leading, spacing: 12) {
              WorkspaceInlineBadge(
                title: syncText,
                systemImage: syncSymbol,
                tint: syncTint
              )

              if visitorPresence?.isActive == true {
                WorkspaceInlineBadge(
                  title: "Visitor active now",
                  systemImage: .dotRadiowavesLeftAndRight,
                  tint: .green
                )
              }

              if seenData.isEmpty {
                Text("No read receipts available yet.")
                  .font(.caption)
                  .foregroundStyle(.tertiary)
              } else {
                InspectorFieldList(rows: seenData.prefix(4).map {
                  ($0.actorLabel, relativeTime(for: $0.lastSeenAt))
                })
              }
            }
          }

          InspectorCard(title: "Conversation") {
            InspectorFieldList(rows: [
              ("Status", detail?.status.label ?? conversation.status.label),
              ("Archived", conversation.isArchived ? "Yes" : "No"),
              ("Priority", conversation.priority.label),
              ("Channel", conversation.channelLabel),
              ("Created", conversation.createdRelativeText),
              ("Last activity", conversation.lastActivityRelativeText),
              ("Sentiment", conversation.sentimentSummary),
              ("Rating", ratingText),
              ("Conversation ID", conversation.id),
              ("Visitor ID", conversation.visitorId),
            ])
          }

          if let visitor {
            InspectorCard(title: "Visitor") {
              InspectorFieldList(rows: [
                ("Created", absoluteTime(for: visitor.createdAt) ?? visitor.createdAt),
                ("Updated", absoluteTime(for: visitor.updatedAt) ?? visitor.updatedAt),
                ("Last Seen", absoluteTime(for: visitor.lastSeenAt) ?? "Not seen yet"),
              ])
            }

            InspectorCard(title: "Device") {
              InspectorFieldList(rows: [
                ("Device", [visitor.device, visitor.deviceType].compactMap { $0 }.joined(separator: " • ").nilIfEmpty ?? "Unknown"),
                ("OS", [visitor.os, visitor.osVersion].compactMap { $0 }.joined(separator: " ").nilIfEmpty ?? "Unknown"),
                ("Browser", [visitor.browser, visitor.browserVersion].compactMap { $0 }.joined(separator: " ").nilIfEmpty ?? "Unknown"),
                ("Language", visitor.language ?? "Unknown"),
                ("Timezone", visitor.timezone ?? "Unknown"),
              ])
            }
          }
        }
        .padding(20)
      }
    }
    .background(.thinMaterial)
  }

  private var visitorLocation: String? {
    [
      visitor?.city,
      visitor?.region,
      visitor?.country,
    ]
      .compactMap { $0?.nilIfEmpty }
      .joined(separator: ", ")
      .nilIfEmpty
  }

  private var ratingText: String {
    if let rating = detail?.visitorRating ?? conversation.visitorRating {
      return "\(rating) / 5"
    }

    return "Not rated yet"
  }

  private var syncText: String {
    switch realtimeConnectionState {
    case .connected:
      "Realtime connected"
    case .connecting:
      "Connecting realtime"
    case .disconnected:
      "Polling fallback"
    case .failed:
      "Realtime blocked"
    }
  }

  private var syncSymbol: SFSymbol {
    switch realtimeConnectionState {
    case .connected:
      .boltHorizontalCircleFill
    case .connecting:
      .boltHorizontalCircle
    case .disconnected:
      .clockArrowTriangleheadCounterclockwiseRotate90
    case .failed:
      .exclamationmarkTriangle
    }
  }

  private var syncTint: Color {
    switch realtimeConnectionState {
    case .connected:
      .green
    case .connecting:
      .blue
    case .disconnected:
      .secondary
    case .failed:
      .orange
    }
  }

  private func relativeTime(for value: String) -> String {
    guard let date = DashboardTimestampParser.date(from: value) else {
      return value
    }

    return RelativeDateTimeFormatter.dashboard.localizedString(for: date, relativeTo: .now)
  }

  private func absoluteTime(for value: String?) -> String? {
    DashboardTimestampParser.absoluteString(from: value)
  }
}

private struct InspectorMetadataList: View {
  let metadata: DashboardMetadata

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(metadata.dashboardSortedEntries, id: \.0) { key, value in
        InspectorCopyRow(
          title: key,
          value: value.dashboardDisplayText
        )
      }
    }
  }
}

private struct InspectorCopyRow: View {
  let title: String
  let value: String

  @State private var copied = false

  var body: some View {
    Button {
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(value, forType: .string)
      copied = true

      Task {
        try? await Task.sleep(for: .seconds(1))
        copied = false
      }
    } label: {
      HStack(alignment: .top, spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

          Text(value)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .textSelection(.enabled)
        }

        Image(systemSymbol: copied ? .checkmark : .documentOnDocument)
          .font(.caption)
          .foregroundStyle(copied ? AnyShapeStyle(Color.green) : AnyShapeStyle(.tertiary))
          .padding(.top, 2)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 9)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.quaternary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .help("Click to copy")
  }
}

private struct InspectorFieldList: View {
  let rows: [(String, String)]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        InspectorCopyRow(title: row.0, value: row.1)
      }
    }
  }
}

private struct ConversationComposerView: View {
  let canUseOpenAIReplyDrafts: Bool
  let isGeneratingReplyDraft: Bool
  let replyDraftErrorMessage: String?
  let onGenerateReplyDraft: @MainActor (String) async -> String?
  let onSendMessage: @MainActor (String, DashboardTimelineItemVisibility, [DashboardComposerAttachment]) async -> Void

  @State private var draftText = ""
  @State private var visibility: DashboardTimelineItemVisibility = .public
  @State private var isSending = false
  @State private var attachments: [DashboardComposerAttachment] = []
  @State private var attachmentErrorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        Picker("", selection: $visibility) {
          Text("Reply")
            .tag(DashboardTimelineItemVisibility.public)
          Text("Private Note")
            .tag(DashboardTimelineItemVisibility.private)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 230)

        if visibility == .public, canUseOpenAIReplyDrafts {
          Button {
            Task {
              await generateReplyDraft()
            }
          } label: {
            Label(
              isGeneratingReplyDraft ? "Drafting…" : "Draft with AI",
              systemSymbol: .sparklesRectangleStack
            )
          }
          .buttonStyle(.bordered)
          .disabled(isGeneratingReplyDraft || draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        Button {
          importAttachments()
        } label: {
          Label("Attach", systemSymbol: .paperclip)
        }
        .buttonStyle(.bordered)
        .disabled(isSending || isGeneratingReplyDraft || attachments.count >= DashboardUploadConstants.maxFilesPerMessage)

        Spacer(minLength: 12)

        Button {
          Task {
            await send()
          }
        } label: {
          Label(isSending ? "Sending…" : sendButtonTitle, systemSymbol: sendButtonSymbol)
        }
        .buttonStyle(.borderedProminent)
        .disabled(
          isSending
            || isGeneratingReplyDraft
            || (draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty)
        )
      }

      if !attachments.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(attachments) { attachment in
              ConversationComposerAttachmentChip(
                attachment: attachment,
                onRemove: {
                  removeAttachment(attachment.id)
                }
              )
            }
          }
        }
      }

      TextEditor(text: $draftText)
        .font(.body)
        .frame(minHeight: 96, maxHeight: 140)
        .scrollContentBackground(.hidden)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topLeading) {
          if draftText.isEmpty {
            Text(placeholder)
              .foregroundStyle(.tertiary)
              .padding(.horizontal, 18)
              .padding(.vertical, 20)
            .allowsHitTesting(false)
          }
        }

      if let replyDraftErrorMessage, visibility == .public {
        Text(replyDraftErrorMessage)
          .font(.caption)
          .foregroundStyle(.orange)
      }

      if let attachmentErrorMessage {
        Text(attachmentErrorMessage)
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
  }

  private var sendButtonTitle: String {
    visibility == .public ? "Send Reply" : "Save Note"
  }

  private var sendButtonSymbol: SFSymbol {
    visibility == .public ? .paperplaneFill : .textPadHeaderBadgePlus
  }

  private var placeholder: String {
    visibility == .public
      ? "Reply to the visitor…"
      : "Write an internal note…"
  }

  @MainActor
  private func send() async {
    let message = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    let currentAttachments = attachments

    guard !message.isEmpty || !currentAttachments.isEmpty else {
      return
    }

    isSending = true
    draftText = ""
    attachments = []
    attachmentErrorMessage = nil
    await onSendMessage(message, visibility, currentAttachments)
    isSending = false
  }

  @MainActor
  private func generateReplyDraft() async {
    let currentText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !currentText.isEmpty else { return }
    guard let generatedDraft = await onGenerateReplyDraft(currentText) else { return }
    draftText = generatedDraft
  }

  private func removeAttachment(_ id: DashboardComposerAttachment.ID) {
    attachments.removeAll { $0.id == id }
  }

  private func importAttachments() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = DashboardUploadConstants.importableTypes
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.canChooseFiles = true

    guard panel.runModal() == .OK else { return }

    do {
      let remainingSlots = DashboardUploadConstants.maxFilesPerMessage - attachments.count
      guard remainingSlots > 0 else {
        throw DashboardAttachmentValidationError.tooManyFiles(max: DashboardUploadConstants.maxFilesPerMessage)
      }

      if panel.urls.count > remainingSlots {
        throw DashboardAttachmentValidationError.tooManyFiles(max: DashboardUploadConstants.maxFilesPerMessage)
      }

      let newAttachments = try panel.urls.map(Self.loadAttachment(from:))
      attachments.append(contentsOf: newAttachments)
      attachmentErrorMessage = nil
    } catch {
      attachmentErrorMessage = error.localizedDescription
    }
  }

  private static func loadAttachment(from url: URL) throws -> DashboardComposerAttachment {
    let data = try Data(contentsOf: url)
    guard let contentType = contentType(for: url) else {
      throw DashboardAttachmentValidationError.unsupportedType(fileName: url.lastPathComponent)
    }

    let attachment = DashboardComposerAttachment(
      data: data,
      fileName: url.lastPathComponent,
      contentType: contentType
    )

    if let error = DashboardUploadConstants.validate(attachment) {
      throw error
    }

    return attachment
  }

  private static func contentType(for url: URL) -> String? {
    if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
       let mimeType = contentType.preferredMIMEType {
      return mimeType
    }

    return UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
  }
}

private struct ConversationComposerAttachmentChip: View {
  let attachment: DashboardComposerAttachment
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      thumbnail

      VStack(alignment: .leading, spacing: 2) {
        Text(attachment.fileName)
          .font(.subheadline.weight(.medium))
          .lineLimit(1)

        Text(attachment.formattedSize)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Button(action: onRemove) {
        Image(systemSymbol: .xmarkCircleFill)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  @ViewBuilder
  private var thumbnail: some View {
    if let image = attachment.thumbnailImage {
      Image(nsImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    } else {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(.quaternary.opacity(0.35))
        .frame(width: 34, height: 34)
        .overlay {
          Image(systemSymbol: attachment.isImage ? .photo : .doc)
            .foregroundStyle(.secondary)
        }
    }
  }
}

private struct ConversationLiveStatusSection: View {
  let website: DashboardWebsite?
  let conversation: DashboardConversation
  let visitor: DashboardVisitor?
  let visitorPresence: DashboardVisitorPresence?
  let typingEvent: DashboardRealtimeConversationTypingPayload?
  let aiProcessingState: DashboardRealtimeAIProcessingState?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let visitorTypingStatus {
        ConversationLiveStatusCard(status: visitorTypingStatus)
      }

      if let humanTypingStatus {
        ConversationLiveStatusCard(status: humanTypingStatus)
      }

      if let aiProcessingStatus {
        ConversationLiveStatusCard(status: aiProcessingStatus)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var visitorTypingStatus: ConversationLiveStatus? {
    guard let typingEvent, typingEvent.isTyping else { return nil }
    guard typingEvent.userId == nil, typingEvent.aiAgentId == nil else { return nil }

    return ConversationLiveStatus(
      title: "\(visitor?.contact?.displayName ?? conversation.visitorDisplayName) is typing",
      subtitle: typingEvent.visitorPreview?.nilIfEmpty ?? "Drafting a message…",
      name: visitor?.contact?.displayName ?? conversation.visitorDisplayName,
      imageURL: visitor?.contact?.image ?? conversation.visitorAvatarURL,
      seed: conversation.visitorId,
      role: .person,
      showsActivePresence: visitorPresence?.isActive == true,
      accent: .accentColor,
      animationStyle: .bounce
    )
  }

  private var humanTypingStatus: ConversationLiveStatus? {
    guard let typingEvent, typingEvent.isTyping, let userId = typingEvent.userId else { return nil }
    let agent = website?.availableHumanAgents.first { $0.id == userId }

    return ConversationLiveStatus(
      title: "\(agent?.displayName ?? "Team member") is replying",
      subtitle: "Preparing a response",
      name: agent?.displayName ?? "Team member",
      imageURL: agent?.image,
      seed: userId,
      role: .person,
      showsActivePresence: false,
      accent: .secondary,
      animationStyle: .subtle
    )
  }

  private var aiProcessingStatus: ConversationLiveStatus? {
    if let aiProcessingState {
      let agent = website?.availableAIAgents.first { $0.id == aiProcessingState.aiAgentId }
      return ConversationLiveStatus(
        title: "\(agent?.displayName ?? "AI agent") is \(aiProcessingState.phaseDisplayTitle.lowercased())",
        subtitle: aiProcessingState.statusText,
        name: agent?.displayName ?? "AI agent",
        imageURL: agent?.image,
        seed: aiProcessingState.aiAgentId,
        role: .ai,
        showsActivePresence: false,
        accent: .indigo,
        animationStyle: .pulse
      )
    }

    guard let typingEvent, typingEvent.isTyping, let aiAgentId = typingEvent.aiAgentId else {
      return nil
    }
    let agent = website?.availableAIAgents.first { $0.id == aiAgentId }

    return ConversationLiveStatus(
      title: "\(agent?.displayName ?? "AI agent") is thinking",
      subtitle: "Preparing the next reply",
      name: agent?.displayName ?? "AI agent",
      imageURL: agent?.image,
      seed: aiAgentId,
      role: .ai,
      showsActivePresence: false,
      accent: .indigo,
      animationStyle: .pulse
    )
  }
}

private struct ConversationLiveStatus {
  let title: String
  let subtitle: String
  let name: String
  let imageURL: URL?
  let seed: String
  let role: DashboardAvatarRole
  let showsActivePresence: Bool
  let accent: Color
  let animationStyle: AnimatedDotsView.Style
}

private struct ConversationLiveStatusCard: View {
  let status: ConversationLiveStatus

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      DashboardAvatarView(
        name: status.name,
        imageURL: status.imageURL,
        seed: status.seed,
        size: 28,
        showsActivePresence: status.showsActivePresence,
        role: status.role
      )

      VStack(alignment: .leading, spacing: 3) {
        Text(status.title)
          .font(.subheadline.weight(.medium))

        Text(status.subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      Spacer(minLength: 0)

      AnimatedDotsView(
        style: status.animationStyle,
        color: status.accent,
        dotSize: 5,
        spacing: 4
      )
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(status.accent.opacity(0.16), lineWidth: 1)
    }
  }
}

struct AnimatedDotsView: View {
  enum Style {
    case bounce
    case pulse
    case subtle
  }

  let style: Style
  var color: Color = .secondary
  var dotSize: CGFloat = 6
  var spacing: CGFloat = 4

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isAnimating = false

  var body: some View {
    HStack(spacing: spacing) {
      ForEach(0..<3, id: \.self) { index in
        Circle()
          .fill(color)
          .frame(width: dotSize, height: dotSize)
          .modifier(
            AnimatedDotStyleModifier(
              style: style,
              isAnimating: isAnimating
            )
          )
          .animation(
            reduceMotion ? nil : animation(for: index),
            value: isAnimating
          )
      }
    }
    .task(id: reduceMotion) {
      isAnimating = !reduceMotion
    }
  }

  private func animation(for index: Int) -> Animation {
    let delay = Double(index) * 0.14

    switch style {
    case .bounce:
      return .easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(delay)
    case .pulse:
      return .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(delay)
    case .subtle:
      return .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay)
    }
  }
}

private struct AnimatedDotStyleModifier: ViewModifier {
  let style: AnimatedDotsView.Style
  let isAnimating: Bool

  func body(content: Content) -> some View {
    switch style {
    case .bounce:
      content
        .offset(y: isAnimating ? -3.5 : 0)
    case .pulse:
      content
        .scaleEffect(isAnimating ? 1.2 : 0.65)
        .opacity(isAnimating ? 1 : 0.35)
    case .subtle:
      content
        .opacity(isAnimating ? 1 : 0.35)
    }
  }
}

private struct InspectorCard<Content: View>: View {
  let title: String?
  @ViewBuilder let content: Content

  init(
    title: String? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      if let title {
        Text(title)
          .font(.headline)
      }

      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: ConversationWorkspaceLayout.cardCornerRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: ConversationWorkspaceLayout.cardCornerRadius, style: .continuous)
        .strokeBorder(.separator.opacity(0.18), lineWidth: 1)
    }
  }
}

private struct WorkspaceMetadataPill: View {
  let title: String
  let systemImage: SFSymbol
  let tint: Color

  var body: some View {
    Label(title, systemSymbol: systemImage)
      .font(.caption.weight(.medium))
      .foregroundStyle(tint)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.quaternary.opacity(0.28), in: Capsule())
  }
}

private struct WorkspaceInlineBadge: View {
  let title: String
  let systemImage: SFSymbol
  let tint: Color

  var body: some View {
    Label(title, systemSymbol: systemImage)
      .font(.caption.weight(.medium))
      .foregroundStyle(tint)
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(tint.opacity(0.08), in: Capsule())
  }
}

private struct SyncStateBadge: View {
  let state: DashboardRealtimeConnectionState

  var body: some View {
    WorkspaceInlineBadge(
      title: label,
      systemImage: symbol,
      tint: tint
    )
  }

  private var label: String {
    switch state {
    case .connected:
      "Realtime"
    case .connecting:
      "Connecting"
    case .disconnected:
      "Polling"
    case .failed:
      "Blocked"
    }
  }

  private var symbol: SFSymbol {
    switch state {
    case .connected:
      .boltHorizontalCircleFill
    case .connecting:
      .boltHorizontalCircle
    case .disconnected:
      .clockArrowTriangleheadCounterclockwiseRotate90
    case .failed:
      .exclamationmarkTriangleFill
    }
  }

  private var tint: Color {
    switch state {
    case .connected:
      .green
    case .connecting:
      .blue
    case .disconnected:
      .secondary
    case .failed:
      .orange
    }
  }
}

private extension String {
  var nilIfEmpty: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
