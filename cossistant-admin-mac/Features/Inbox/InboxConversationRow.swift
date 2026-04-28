import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct InboxConversationRow: View {
  @Bindable var model: WorkspaceModel
  let conversation: DashboardConversation
  let visitorPresence: DashboardVisitorPresence?

  private enum LivePreview {
    case visitorTyping(String?)
    case humanTyping(String)
    case aiProcessing(String)

    var text: String {
      switch self {
      case .visitorTyping(let preview):
        if let preview, !preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          return preview
        }
        return "Visitor is typing…"
      case .humanTyping(let text), .aiProcessing(let text):
        return text
      }
    }

    var tint: Color {
      switch self {
      case .visitorTyping:
        return .accentColor
      case .humanTyping:
        return .secondary
      case .aiProcessing:
        return .indigo
      }
    }

    var animationStyle: AnimatedDotsView.Style {
      switch self {
      case .visitorTyping:
        return .bounce
      case .humanTyping:
        return .subtle
      case .aiProcessing:
        return .pulse
      }
    }
  }

  var body: some View {
    let hasUnreadActivity = model.conversationHasUnreadActivity(conversation)

    HStack(alignment: .top, spacing: 12) {
      AvatarView(
        name: conversation.visitorDisplayName,
        imageURL: conversation.visitorAvatarURL,
        seed: conversation.visitorAvatarSeed,
        showsActivePresence: visitorPresence?.isActive == true
      )
      .overlay {
        if let statusOutlineTint {
          Circle()
            .strokeBorder(statusOutlineTint, lineWidth: 2)
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top, spacing: 8) {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
              if hasUnreadActivity {
                Circle()
                  .fill(Color.accentColor)
                  .frame(width: 8, height: 8)
              }

              Text(conversation.visitorDisplayName)
                .font(.headline.weight(hasUnreadActivity ? .semibold : .regular))
                .lineLimit(1)
            }

            HStack(spacing: 6) {
              Text(conversation.displayTitle)
                .font(.subheadline.weight(hasUnreadActivity ? .medium : .regular))
                .foregroundStyle(hasUnreadActivity ? .primary : .secondary)
                .lineLimit(1)

              if conversation.hasUpdatesSinceLastSeen {
                Image(systemSymbol: .clockArrowTriangleheadCounterclockwiseRotate90)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
                  .help("New messages since you last viewed this conversation")
              }

              if let priorityIndicatorSymbol = conversation.priorityIndicatorSymbol {
                Image(systemSymbol: priorityIndicatorSymbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(conversation.priorityIndicatorTint)
              }

              if let platformIndicatorSymbol = conversation.platformIndicatorSymbol,
                 let platformIndicatorLabel = conversation.platformIndicatorLabel {
                Image(systemSymbol: platformIndicatorSymbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(conversation.platformIndicatorTint)
                  .accessibilityLabel(platformIndicatorLabel)
                  .help(platformIndicatorLabel)
              }
            }
          }

          Spacer(minLength: 0)

          VStack(alignment: .trailing, spacing: 3) {
            rowTimestamp(
              title: "Last",
              value: conversation.lastActivityRelativeText,
              emphasized: true
            )

            rowTimestamp(
              title: "Created",
              value: conversation.createdRelativeText,
              emphasized: false
            )
          }
        }

        previewLine

        if conversation.needsHumanIntervention
          || conversation.needsClarification
          || conversation.showsAttentionWaitingBadge
          || conversation.sentimentCategory != .unknown {
          HStack(spacing: 6) {
            if conversation.needsHumanIntervention {
              RowTag(title: "Human intervention", systemSymbol: .personFillBadgePlus, tint: .orange)
            } else if conversation.needsClarification {
              RowTag(title: "Clarification", systemSymbol: .questionmarkBubbleFill, tint: .indigo)
            }

            if let waitingLabel = conversation.attentionWaitingLabel {
              RowTag(
                title: waitingLabel,
                systemSymbol: .clock,
                tint: conversation.attentionWaitingTint
              )
            }

            if conversation.sentimentCategory != .unknown {
              RowTag(title: conversation.sentimentCategory.label, tint: sentimentTint)
            }
          }
        }
      }
    }
    .padding(.vertical, 6)
    .task(id: unreadDebugFingerprint) {
      guard DashboardReadDebug.isTargetConversation(conversation.id) else { return }
      DashboardReadDebug.log("InboxRow.render", unreadDebugFingerprint)
    }
    .contextMenu {
      if hasUnreadActivity {
        Button {
          Task {
            await model.markConversationRead(conversation.id)
          }
        } label: {
          Label("Mark Read", systemSymbol: .checkmarkCircle)
        }
      } else {
        Button {
          Task {
            await model.markConversationUnread(conversation.id)
          }
        } label: {
          Label("Mark Unread", systemSymbol: .eyeSlash)
        }
      }

      Divider()

      if conversation.status == .open {
        Button {
          Task {
            await model.resolveConversation(conversation.id)
          }
        } label: {
          Label("Resolve", systemSymbol: .checkmark)
        }

        Button {
          Task {
            await model.markConversationSpam(conversation.id)
          }
        } label: {
          Label("Mark Spam", systemSymbol: .nosign)
        }
      } else if conversation.status == .resolved {
        Button {
          Task {
            await model.reopenConversation(conversation.id)
          }
        } label: {
          Label("Reopen", systemSymbol: .arrowCounterclockwise)
        }
      } else if conversation.status == .spam {
        Button {
          Task {
            await model.markConversationNotSpam(conversation.id)
          }
        } label: {
          Label("Not Spam", systemSymbol: .arrowUturnBackward)
        }
      }

      Divider()

      if conversation.needsHumanIntervention {
        Button {
          Task {
            await model.joinConversationEscalation(conversation.id)
          }
        } label: {
          Label("Join Escalation", systemSymbol: .personCropCircleBadgePlus)
        }
      }

      if conversation.isArchived {
        Button {
          Task {
            await model.unarchiveConversation(conversation.id)
          }
        } label: {
          Label("Unarchive", systemSymbol: .trayAndArrowUp)
        }
      } else {
        Button {
          Task {
            await model.archiveConversation(conversation.id)
          }
        } label: {
          Label("Archive", systemSymbol: .archivebox)
        }
      }

      Divider()

      if conversation.aiPausedUntil == nil {
        Button("Pause AI for 10-min") {
          Task {
            await model.pauseConversationAI(conversation.id, durationMinutes: 10)
          }
        }

        Button("Pause AI for 1-hour") {
          Task {
            await model.pauseConversationAI(conversation.id, durationMinutes: 60)
          }
        }
      } else {
        Button("Resume AI Answers") {
          Task {
            await model.resumeConversationAI(conversation.id)
          }
        }
      }
    }
  }

  private var unreadDebugFingerprint: String {
    [
      "hasUnread=\(model.conversationHasUnreadActivity(conversation))",
      "manualUnread=\(model.isConversationManuallyMarkedUnread(conversation.id))",
      "lastSeenAt=\(conversation.lastSeenAt ?? "nil")",
      "lastMessageAt=\(conversation.lastMessageAt ?? "nil")",
      "updatedAt=\(conversation.updatedAt)",
      "hasContent=\(conversation.hasContent)",
      "selected=\(model.selectedConversationID == conversation.id)",
      "hideSeen=\(model.inboxHideSeenConversations)",
      "scopeSelectedConversation=\(model.selectedConversationID ?? "nil")",
    ]
      .joined(separator: " ")
  }

  @ViewBuilder
  private var previewLine: some View {
    if let livePreview {
      HStack(spacing: 8) {
        AnimatedDotsView(
          style: livePreview.animationStyle,
          color: livePreview.tint,
          dotSize: 4,
          spacing: 3
        )

        Text(livePreview.text)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(livePreview.tint)
          .lineLimit(2)
      }
    } else {
      Text(conversation.previewText)
        .font(.subheadline.weight(model.conversationHasUnreadActivity(conversation) ? .medium : .regular))
        .foregroundStyle(model.conversationHasUnreadActivity(conversation) ? .primary : .secondary)
        .lineLimit(2)
    }
  }

  private var livePreview: LivePreview? {
    if let typingEvent = model.typingEvent(for: conversation.id), typingEvent.isTyping {
      if let aiAgentId = typingEvent.aiAgentId {
        let agentName = model.website?.availableAIAgents.first(where: { $0.id == aiAgentId })?.displayName ?? "AI"
        return .aiProcessing("\(agentName) is thinking")
      }

      if let userId = typingEvent.userId {
        let agentName = model.website?.availableHumanAgents.first(where: { $0.id == userId })?.displayName ?? "Team member"
        return .humanTyping("\(agentName) is replying")
      }

      return .visitorTyping(typingEvent.visitorPreview)
    }

    if let aiProcessingState = model.aiProcessingState(for: conversation.id) {
      return .aiProcessing(aiProcessingState.statusText)
    }

    return nil
  }

  private var statusOutlineTint: Color? {
    if conversation.isArchived {
      return .secondary
    }

    switch conversation.status {
    case .open:
      return nil
    case .resolved:
      return .green
    case .spam:
      return .red
    }
  }

  private var sentimentTint: Color {
    switch conversation.sentimentCategory {
    case .positive:
      .green
    case .neutral:
      .secondary
    case .negative:
      .red
    case .unknown:
      .secondary
    }
  }

  private func rowTimestamp(title: String, value: String, emphasized: Bool) -> some View {
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
