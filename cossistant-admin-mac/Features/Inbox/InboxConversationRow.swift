import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct InboxConversationRow: View {
  @Bindable var model: WorkspaceModel
  let conversation: DashboardConversation
  let visitorPresence: DashboardVisitorPresence?
  let showsMetadataSummaryPreviews: Bool
  let showBackendTranslatedSubjects: Bool

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
      avatar

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

            HStack(alignment: .firstTextBaseline, spacing: 3) {
              if conversation.hasUpdatesSinceLastSeen {
                Image(systemSymbol: .clockArrowTriangleheadCounterclockwiseRotate90)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
                  .help("New messages since you last viewed this conversation")
              }

              Text(titleOrSummaryText)
                .font(.subheadline.weight(hasUnreadActivity ? .medium : .regular))
                .foregroundStyle(hasUnreadActivity ? .primary : .secondary)
                .lineLimit(summaryPreviewText == nil ? 1 : nil)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
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

        if summaryPreviewText == nil || livePreview != nil {
          previewLine
        }

        if let teamActionNeededPreviewText {
          Text("Needs team: \(teamActionNeededPreviewText)")
            .font(.caption.weight(.medium))
            .foregroundStyle(.red)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }

        HStack(spacing: 6) {
          InboxPriorityChip(priority: conversation.priority)

          if conversation.needsHumanIntervention {
            RowTag(title: "Human intervention", systemSymbol: .personFillBadgePlus, tint: .orange)
          }

          if let waitingLabel = conversation.visitorWaitingLabel {
            RowTag(
              title: waitingLabel,
              systemSymbol: .clock,
              tint: conversation.visitorWaitingTint
            )
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

  private var summaryPreviewText: String? {
    guard showsMetadataSummaryPreviews else { return nil }
    return conversation.inboxMetadataSummaryPreviewText
  }

  private var teamActionNeededPreviewText: String? {
    conversation.teamActionNeededPreviewText
  }

  private var titleOrSummaryText: String {
    summaryPreviewText ?? conversation.displayTitle(showBackendTranslatedSubjects: showBackendTranslatedSubjects)
  }

  private var avatar: some View {
    VStack(spacing: 6) {
      AvatarView(
        name: conversation.visitorDisplayName,
        imageURL: conversation.visitorAvatarURL,
        seed: conversation.visitorAvatarSeed,
        size: 44,
        showsActivePresence: visitorPresence?.isActive == true
      )
      .overlay {
        if let statusOutlineTint {
          Circle()
            .strokeBorder(statusOutlineTint, lineWidth: 2)
        }
      }

      if let platformIndicatorSymbol = conversation.platformIndicatorSymbol,
         let platformIndicatorLabel = conversation.platformIndicatorLabel {
        InboxPlatformChip(
          systemSymbol: platformIndicatorSymbol,
          version: conversation.appVersionIndicatorText,
          tint: conversation.platformIndicatorTint,
          accessibilityLabel: platformIndicatorLabel
        )
      }
    }
    .frame(width: 48)
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

private struct InboxPlatformChip: View {
  let systemSymbol: SFSymbol
  let version: String?
  let tint: Color
  let accessibilityLabel: String

  var body: some View {
    HStack(spacing: 2) {
      Image(systemSymbol: systemSymbol)
        .font(.system(size: 7, weight: .bold))

      if let version {
        Text(version)
          .font(.system(size: 8, weight: .semibold, design: .rounded).monospacedDigit())
          .fixedSize(horizontal: true, vertical: true)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal, version == nil ? 4 : 5)
    .padding(.vertical, 2)
    .background(tint.opacity(0.10), in: .capsule)
    .foregroundStyle(tint.opacity(0.86))
    .opacity(0.86)
    .fixedSize(horizontal: true, vertical: true)
    .accessibilityLabel(platformAccessibilityLabel)
    .help(platformAccessibilityLabel)
  }

  private var platformAccessibilityLabel: String {
    if let version {
      return "\(accessibilityLabel) \(version)"
    }

    return accessibilityLabel
  }
}

private struct InboxPriorityChip: View {
  let priority: DashboardConversation.Priority

  private let barCount = 4

  var body: some View {
    HStack(alignment: .bottom, spacing: 2) {
      ForEach(1...barCount, id: \.self) { index in
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
          .fill(index <= priorityVisualRank ? priority.tint : Color.secondary.opacity(0.2))
          .frame(width: 3, height: CGFloat(index * 2 + 4))
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(priority.tint.opacity(0.12), in: .capsule)
    .accessibilityLabel("Priority \(priority.label)")
    .help("Priority \(priority.label)")
  }

  private var priorityVisualRank: Int {
    switch priority {
    case .low:
      return 1
    case .normal:
      return 2
    case .high:
      return 3
    case .urgent:
      return 4
    }
  }
}
