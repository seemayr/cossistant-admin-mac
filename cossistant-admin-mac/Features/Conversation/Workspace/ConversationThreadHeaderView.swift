import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct ConversationThreadHeaderView: View {
  let conversation: DashboardConversation
  let detail: DashboardConversationDetail?
  let visitor: DashboardVisitor?
  let visitorPresence: DashboardVisitorPresence?
  let realtimeConnectionState: DashboardRealtimeConnectionState
  let showDeveloperLogs: Bool
  let onToggleDeveloperLogs: (Bool) -> Void
  let canUseMessageTranslations: Bool
  let showTranslations: Bool
  let showBackendTranslatedSubjects: Bool
  let onToggleTranslations: (Bool) -> Void
  let isTranslatingMessages: Bool
  let translationErrorMessage: String?
  let translatedClarification: DashboardMessageTranslation?
  let showInspector: Bool
  let onToggleInspector: (Bool) -> Void
  let isCopyingConversationMessages: Bool
  let onCopyConversationMessages: () -> Void
  let onCopyConversationFullLog: () -> Void
  let hasUnreadActivity: Bool
  let onMarkConversationSeen: @MainActor @Sendable () async -> Void
  let onMarkConversationUnread: @MainActor @Sendable () async -> Void
  let onArchiveConversation: @MainActor @Sendable () async -> Void
  let onUnarchiveConversation: @MainActor @Sendable () async -> Void
  let onResolveConversation: @MainActor @Sendable () async -> Void
  let onResolveFromFAQ: () -> Void
  let onReopenConversation: @MainActor @Sendable () async -> Void
  let onMarkConversationSpam: @MainActor @Sendable () async -> Void
  let onMarkConversationNotSpam: @MainActor @Sendable () async -> Void
  let onUpdateConversationTitle: @MainActor @Sendable (String?) async -> Void
  let onJoinConversationEscalation: @MainActor @Sendable () async -> Void
  let onPauseConversationAI: @MainActor @Sendable (Int) async -> Void
  let onResumeConversationAI: @MainActor @Sendable () async -> Void
  let canUseOpenAIReplyDrafts: Bool
  let onDismissClarification: @MainActor @Sendable () async -> Void
  let onBuildFAQFromConversation: () -> Void

  private static let pauseUntilFurtherNoticeDurationMinutes = 60 * 24 * 365 * 100

  @State private var isEditingTitle = false

  var body: some View {
    HStack(alignment: .top, spacing: 18) {
      AvatarView(
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
          Text(displayedConversationTitle)
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
          } else if let clarification = conversation.activeClarification,
                    conversation.needsClarification {
            ConversationClarificationHintButton(
              clarification: clarification,
              translatedQuestion: translatedClarification?.text,
              onDismiss: {
                await onDismissClarification()
              }
            )
          }
        }

        headerDetails
      }

      Spacer(minLength: 20)

      VStack(alignment: .trailing, spacing: 12) {
        SyncStateBadge(state: realtimeConnectionState)

        HStack(spacing: 10) {
          Button {
            Task {
              if hasUnreadActivity {
                await onMarkConversationSeen()
              } else {
                await onMarkConversationUnread()
              }
            }
          } label: {
            Image(systemSymbol: hasUnreadActivity ? .eye : .eyeSlash)
              .font(.body.weight(.semibold))
          }
          .buttonStyle(.borderless)
          .accessibilityLabel(seenActionHint)
          .help(seenActionHint)

          Button {
            Task {
              if conversation.aiPausedUntil == nil {
                await onPauseConversationAI(Self.pauseUntilFurtherNoticeDurationMinutes)
              } else {
                await onResumeConversationAI()
              }
            }
          } label: {
            Image(systemSymbol: conversation.aiPausedUntil == nil ? .lightbulbSlashFill : .lightbulbFill)
              .font(.body.weight(.semibold))
          }
          .buttonStyle(.borderless)
          .accessibilityLabel(aiPauseActionHint)
          .help(aiPauseActionHint)

          if conversation.status != .spam, !conversation.isArchived {
            Button {
              Task {
                if conversation.status == .resolved {
                  await onReopenConversation()
                } else {
                  await onResolveConversation()
                }
              }
            } label: {
              Image(systemSymbol: conversation.status == .resolved ? .arrowCounterclockwise : .checkmarkCircle)
                .font(.body.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(resolveActionHint)
            .help(resolveActionHint)
          }

          Menu {
            if hasUnreadActivity {
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

              Button(action: onResolveFromFAQ) {
                Label("Resolve from FAQ", systemSymbol: .questionmarkBubble)
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
              Label(messagesCopyButtonTitle, systemSymbol: .documentOnDocument)
            }

            Button {
              onCopyConversationFullLog()
            } label: {
              Label(fullLogCopyButtonTitle, systemSymbol: .textAlignleft)
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
              onBuildFAQFromConversation()
            } label: {
              Label("Build FAQ", systemSymbol: .questionmarkBubble)
            }
            .disabled(!canUseOpenAIReplyDrafts)

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

            Button {
              if conversation.isArchived {
                Task {
                  await onUnarchiveConversation()
                }
              } else {
                Task {
                  await onArchiveConversation()
                }
              }
            } label: {
              Label(
                conversation.isArchived ? "Unarchive" : "Archive",
                systemSymbol: conversation.isArchived ? .trayAndArrowUp : .archivebox
              )
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
                  await onPauseConversationAI(Self.pauseUntilFurtherNoticeDurationMinutes)
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
          .help("More conversation actions")
        }

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
          .help(translationActionHint)
        }
      }
      .fixedSize()
    }
    .padding(.horizontal, ConversationWorkspaceLayout.panePadding)
    .padding(.vertical, 18)
    .sheet(isPresented: $isEditingTitle) {
      ConversationTitleEditorSheetContent(
        initialTitle: detail?.title ?? conversation.title,
        onSave: { title in
          await onUpdateConversationTitle(title)
        }
      )
    }
  }

  private var seenActionHint: String {
    hasUnreadActivity ? "Mark this conversation as seen" : "Mark this conversation as unseen"
  }

  private var aiPauseActionHint: String {
    conversation.aiPausedUntil == nil
      ? "Pause AI replies for this conversation"
      : "Resume AI replies for this conversation"
  }

  private var resolveActionHint: String {
    conversation.status == .resolved
      ? "Reopen this conversation"
      : "Resolve this conversation"
  }

  private var translationActionHint: String {
    if isTranslatingMessages {
      return "Translating conversation messages"
    }

    return showTranslations ? "Hide translations" : "Show translations"
  }

  private var displayedConversationTitle: String {
    detail?.displayTitle(
      fallback: conversation,
      showBackendTranslatedSubjects: showBackendTranslatedSubjects
    ) ?? conversation.displayTitle(showBackendTranslatedSubjects: showBackendTranslatedSubjects)
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

private struct ConversationClarificationHintButton: View {
  let clarification: DashboardConversation.Clarification
  let translatedQuestion: String?
  let onDismiss: @MainActor () async -> Void

  @State private var isShowingPopover = false
  @State private var isDismissing = false

  var body: some View {
    Button {
      isShowingPopover.toggle()
    } label: {
      Image(systemSymbol: .questionmarkBubbleFill)
        .font(.body.weight(.semibold))
        .foregroundStyle(.indigo)
        .frame(width: 26, height: 26)
        .background(.indigo.opacity(0.11), in: Circle())
        .overlay {
          Circle()
            .strokeBorder(.indigo.opacity(0.18), lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
    .help(helpText)
    .accessibilityLabel("Show clarification")
    .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
      popoverContent
    }
  }

  private var popoverContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .center, spacing: 10) {
        Image(systemSymbol: .questionmarkBubbleFill)
          .font(.title3)
          .foregroundStyle(.indigo)

        Text("Clarification Needed")
          .font(.headline)

        Spacer(minLength: 12)

        WorkspaceInlineBadge(
          title: clarification.status.replacingOccurrences(of: "_", with: " ").capitalized,
          systemImage: .sparklesRectangleStack,
          tint: .indigo
        )
      }

      Text(questionText)
        .font(.body)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)

      HStack(alignment: .center) {
        Text(clarificationStatusSummary)
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer(minLength: 12)

        Button {
          Task {
            isDismissing = true
            await onDismiss()
            isDismissing = false
            isShowingPopover = false
          }
        } label: {
          if isDismissing {
            ProgressView()
              .controlSize(.small)
          } else {
            Label("Hide", systemSymbol: .xmark)
          }
        }
        .buttonStyle(.borderless)
        .disabled(isDismissing)
      }
    }
    .padding(16)
    .frame(width: 360, alignment: .leading)
  }

  private var questionText: String {
    displayedQuestion?.nilIfEmpty ?? "No clarification question text available."
  }

  private var helpText: String {
    "Clarification needed: \(questionText)"
  }

  private var clarificationStatusSummary: String {
    let updatedText = DashboardTimestampParser.relativeString(from: clarification.updatedAt) ?? clarification.updatedAt
    return "Updated \(updatedText)"
  }

  private var displayedQuestion: String? {
    let originalQuestion = clarification.question?.trimmingCharacters(in: .whitespacesAndNewlines)
    let translatedQuestion = translatedQuestion?.trimmingCharacters(in: .whitespacesAndNewlines)

    if let translatedQuestion, !translatedQuestion.isEmpty, translatedQuestion != originalQuestion {
      return translatedQuestion
    }

    return originalQuestion
  }
}

private struct ConversationTitleEditorSheetContent: View {
  let initialTitle: String?
  let onSave: @MainActor @Sendable (String?) async -> Void

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
