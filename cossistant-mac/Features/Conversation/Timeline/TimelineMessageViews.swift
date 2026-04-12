import AppKit
import SwiftUI
import SFSafeSymbols

struct TimelineMessageGroupView: View {
  let group: DashboardTimelineGroup
  let sender: DashboardTimelineSenderDisplay
  let translatedMessagesByID: [String: DashboardMessageTranslation]
  let seenReceipts: [TimelineSeenReceiptDisplay]

  private var alignsTrailing: Bool {
    sender.kind == .human || sender.kind == .ai
  }

  var body: some View {
    HStack(alignment: .bottom, spacing: 12) {
      if alignsTrailing {
        Spacer(minLength: ConversationTimelineLayout.sideSpacer)
      } else {
        AvatarView(
          name: sender.name,
          imageURL: sender.imageURL,
          seed: sender.seed,
          size: 28,
          role: sender.kind == .ai ? .ai : .person
        )
        .padding(.bottom, 2)
      }

      VStack(alignment: alignsTrailing ? .trailing : .leading, spacing: 8) {
        Text(sender.name)
          .font(.caption)
          .foregroundStyle(.secondary)

        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
          TimelineMessageBubbleView(
            item: item,
            sender: sender,
            translatedMessage: translatedMessagesByID[item.id],
            isTrailing: alignsTrailing,
            isLastInGroup: index == group.items.count - 1,
            seenReceipts: index == group.items.count - 1 ? seenReceipts : []
          )
        }
      }
      .frame(
        maxWidth: ConversationTimelineLayout.messageMaxWidth,
        alignment: alignsTrailing ? .trailing : .leading
      )

      if !alignsTrailing {
        Spacer(minLength: ConversationTimelineLayout.sideSpacer)
      } else {
        AvatarView(
          name: sender.name,
          imageURL: sender.imageURL,
          seed: sender.seed,
          size: 28,
          role: sender.kind == .ai ? .ai : .person
        )
        .padding(.bottom, 2)
      }
    }
  }
}

struct TimelineMessageBubbleView: View {
  let item: DashboardTimelineItem
  let sender: DashboardTimelineSenderDisplay
  let translatedMessage: DashboardMessageTranslation?
  let isTrailing: Bool
  let isLastInGroup: Bool
  let seenReceipts: [TimelineSeenReceiptDisplay]

  private var bubbleFill: AnyShapeStyle {
    if item.isPrivateNote {
      return AnyShapeStyle(.yellow.opacity(0.08))
    }

    switch sender.kind {
    case .visitor:
      return AnyShapeStyle(.background)
    case .human:
      return AnyShapeStyle(Color.accentColor.opacity(0.12))
    case .ai:
      return AnyShapeStyle(Color.indigo.opacity(0.12))
    case .system:
      return AnyShapeStyle(.quaternary.opacity(0.3))
    }
  }

  var body: some View {
    VStack(alignment: isTrailing ? .trailing : .leading, spacing: 6) {
      VStack(alignment: .leading, spacing: 10) {
        if item.isPrivateNote {
          Label("Private note", systemSymbol: .eyeSlash)
            .font(.caption.weight(.medium))
            .foregroundStyle(.yellow)
        }

        if let renderedText = item.renderedText {
          Text(renderedText)
            .font(.body)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }

        if let translatedText {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
              Text("Translation")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

              if let sourceLanguage = translatedMessage?.detectedSourceLanguage?.uppercased() {
                Text(sourceLanguage)
                  .font(.caption2.weight(.medium))
                  .foregroundStyle(.tertiary)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(.quaternary.opacity(0.25), in: Capsule())
              }
            }

            Text(translatedText)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(.top, 2)
        }

        if !item.imageParts.isEmpty {
          TimelineImageStripView(images: item.imageParts)
        }

        if !item.fileParts.isEmpty {
          TimelineFileStripView(files: item.fileParts)
        }

        if let sourceLabel = item.sourceLabel {
          Label(sourceLabel, systemSymbol: .arrowTriangleheadBranch)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .frame(maxWidth: ConversationTimelineLayout.messageMaxWidth, alignment: .leading)
      .background(bubbleFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .strokeBorder(borderColor, style: borderStyle)
      }

      if isLastInGroup {
        Text(timestampLabel)
          .font(.caption2)
          .foregroundStyle(.secondary)

        if isTrailing, !seenReceipts.isEmpty {
          TimelineSeenIndicatorView(receipts: seenReceipts)
        }
      }
    }
  }

  private var timestampLabel: String {
    var components = [item.createdTimeText]

    if sender.kind == .ai {
      components.append("AI")
    }

    if item.isPrivateNote {
      components.append("Internal")
    }

    return components.joined(separator: " • ")
  }

  private var translatedText: String? {
    guard let translatedMessage else { return nil }
    let original = item.renderedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let translated = translatedMessage.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !translated.isEmpty, translated != original else { return nil }
    return translated
  }

  private var borderColor: Color {
    if item.isPrivateNote {
      return .yellow.opacity(0.4)
    }

    let separatorColor = Color(nsColor: .separatorColor)

    switch sender.kind {
    case .visitor:
      return separatorColor.opacity(0.5)
    case .human:
      return Color.accentColor.opacity(0.2)
    case .ai:
      return .indigo.opacity(0.2)
    case .system:
      return separatorColor.opacity(0.4)
    }
  }

  private var borderStyle: StrokeStyle {
    item.isPrivateNote
      ? StrokeStyle(lineWidth: 1, dash: [5, 4])
      : StrokeStyle(lineWidth: 1)
  }
}

struct TimelineSeenReceiptDisplay: Identifiable, Hashable {
  let id: String
  let actorID: String
  let name: String
  let imageURL: URL?
  let role: AvatarRole
  let lastSeenDate: Date

  init?(seen: DashboardConversationSeen, website: DashboardWebsite?) {
    if let aiAgentId = seen.aiAgentId {
      let agent = website?.availableAIAgents.first { $0.id == aiAgentId }
      self.id = seen.id
      self.actorID = aiAgentId
      self.name = agent?.displayName ?? "AI agent"
      self.imageURL = agent?.image
      self.role = .ai
      self.lastSeenDate = seen.lastSeenDate ?? .distantPast
      return
    }

    if let userId = seen.userId {
      let agent = website?.availableHumanAgents.first { $0.id == userId }
      self.id = seen.id
      self.actorID = userId
      self.name = agent?.displayName ?? "Team member"
      self.imageURL = agent?.image
      self.role = .person
      self.lastSeenDate = seen.lastSeenDate ?? .distantPast
      return
    }

    return nil
  }
}

struct TimelineSeenIndicatorView: View {
  let receipts: [TimelineSeenReceiptDisplay]

  var body: some View {
    HStack(spacing: 4) {
      HStack(spacing: -4) {
        ForEach(receipts.prefix(3)) { receipt in
          AvatarView(
            name: receipt.name,
            imageURL: receipt.imageURL,
            seed: receipt.actorID,
            size: 18,
            role: receipt.role
          )
          .overlay {
            Circle()
              .strokeBorder(.background, lineWidth: 1.5)
          }
        }

        if receipts.count > 3 {
          Text("+\(receipts.count - 3)")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }

      Text("Seen")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }
}
