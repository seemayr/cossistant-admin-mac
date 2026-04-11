import SwiftUI
import SFSafeSymbols

struct InboxQueueView: View {
  @Bindable var model: AppModel
  let scope: InboxScope
  @Binding var selection: DashboardConversation.ID?

  var body: some View {
    VStack(spacing: 0) {
      header

      List(displayedConversations, selection: $selection) { conversation in
        InboxConversationRow(
          model: model,
          conversation: conversation,
          visitorPresence: model.visitorPresence(for: conversation.visitorId)
        )
          .tag(conversation.id)
      }
      .listStyle(.inset(alternatesRowBackgrounds: false))
      .overlay {
        if displayedConversations.isEmpty {
          if model.searchText.isEmpty, !model.hasActiveConversationFilters {
            ContentUnavailableView(
              "No conversations yet",
              systemImage: scope.systemSymbol.rawValue,
              description: Text("This queue is empty right now.")
            )
          } else {
            ContentUnavailableView.search(text: model.searchText)
          }
        }
      }

      if model.canLoadMore {
        HStack {
          Spacer()

          Button {
            Task {
              await model.loadMoreConversations()
            }
          } label: {
            Label(model.isLoadingMore ? "Loading…" : "Load More", systemSymbol: .ellipsisCircle)
          }
          .disabled(model.isLoadingMore)
        }
        .padding(14)
        .background(.bar)
      }
    }
    .searchable(text: $model.searchText, prompt: "Search conversations")
  }

  private var displayedConversations: [DashboardConversation] {
    let filteredConversations = scopedConversations

    guard let selection,
          let selectedConversation = model.selectedConversation,
          selectedConversation.id == selection,
          !filteredConversations.contains(where: { $0.id == selectedConversation.id }) else {
      return filteredConversations
    }

    return [selectedConversation] + filteredConversations
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(scope.title)
        .font(.title2.weight(.semibold))

      Text(queueSummary)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      HStack(spacing: 10) {
        Menu {
          Picker("Sort by", selection: $model.inboxSortMode) {
            ForEach(InboxSortMode.allCases) { mode in
              Text(mode.label)
                .tag(mode)
            }
          }
        } label: {
          HeaderControlLabel(
            title: "Sort",
            value: model.inboxSortMode.label,
            systemImage: .arrowUpArrowDown
          )
        }

        Menu {
          Picker("Priority", selection: $model.inboxPriorityFilter) {
            ForEach(InboxPriorityFilter.allCases) { filter in
              Text(filter.label)
                .tag(filter)
            }
          }

          Picker("Sentiment", selection: $model.inboxSentimentFilter) {
            ForEach(InboxSentimentFilter.allCases) { filter in
              Text(filter.label)
                .tag(filter)
            }
          }

          Divider()

          Toggle("Hide seen conversations", isOn: $model.inboxHideSeenConversations)
          Toggle("Hide empty conversations", isOn: $model.inboxHideEmptyConversations)

          if model.hasActiveConversationFilters {
            Divider()

            Button("Clear Filters") {
              model.clearConversationFilters()
            }
          }
        } label: {
          HeaderControlLabel(
            title: "Filter",
            value: filterSummary,
            systemImage: .line3HorizontalDecreaseCircle
          )
        }
      }
      .padding(.top, 4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
    .background(.bar)
  }

  private var queueSummary: String {
    let shown = scopedConversations.count
    let total = model.conversationCount(for: scope)

    if total == 0 {
      return "No conversations match this queue right now."
    }

    if shown == total {
      return "\(total) conversations in this queue"
    }

    return "\(shown) of \(total) conversations shown"
  }

  private var filterSummary: String {
    let values = [
      model.inboxPriorityFilter == .all ? nil : model.inboxPriorityFilter.label,
      model.inboxSentimentFilter == .all ? nil : model.inboxSentimentFilter.label,
      model.inboxHideSeenConversations ? "Hide Seen" : nil,
      model.inboxHideEmptyConversations ? "Has Content" : nil,
    ]
      .compactMap { $0 }

    if values.isEmpty {
      return "All"
    }

    return values.joined(separator: " • ")
  }

  private var scopedConversations: [DashboardConversation] {
    model.conversations(in: scope)
  }
}

private struct InboxConversationRow: View {
  @Bindable var model: AppModel
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
    HStack(alignment: .top, spacing: 12) {
      DashboardAvatarView(
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
              if conversation.hasUnreadActivity {
                Circle()
                  .fill(Color.accentColor)
                  .frame(width: 8, height: 8)
              }

              Text(conversation.visitorDisplayName)
                .font(.headline.weight(conversation.hasUnreadActivity ? .semibold : .regular))
                .lineLimit(1)
            }

            HStack(spacing: 6) {
              Text(conversation.displayTitle)
                .font(.subheadline.weight(conversation.hasUnreadActivity ? .medium : .regular))
                .foregroundStyle(conversation.hasUnreadActivity ? .primary : .secondary)
                .lineLimit(1)

              if let priorityIndicatorSymbol = conversation.priorityIndicatorSymbol {
                Image(systemSymbol: priorityIndicatorSymbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(conversation.priorityIndicatorTint)
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
    .contextMenu {
      if conversation.hasUnreadActivity {
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

      Button {
        Task {
          await model.archiveConversation(conversation.id)
        }
      } label: {
        Label("Archive", systemSymbol: .archivebox)
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
        .font(.subheadline.weight(conversation.hasUnreadActivity ? .medium : .regular))
        .foregroundStyle(conversation.hasUnreadActivity ? .primary : .secondary)
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
    switch conversation.status {
    case .open:
      nil
    case .resolved:
      .green
    case .spam:
      .red
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

private struct HeaderControlLabel: View {
  let title: String
  let value: String
  let systemImage: SFSymbol

  var body: some View {
    Label {
      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)

        Text(value)
          .font(.subheadline.weight(.medium))
          .lineLimit(1)
      }
    } icon: {
      Image(systemSymbol: systemImage)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(.quinary, in: .rect(cornerRadius: 12))
  }
}

private struct RowTag: View {
  let title: String
  var systemSymbol: SFSymbol? = nil
  let tint: Color

  var body: some View {
    Label {
      Text(title)
    } icon: {
      if let systemSymbol {
        Image(systemSymbol: systemSymbol)
      }
    }
    .labelStyle(.titleAndIcon)
    .font(.caption2.weight(.semibold))
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(tint.opacity(0.12), in: .capsule)
    .foregroundStyle(tint)
  }
}
