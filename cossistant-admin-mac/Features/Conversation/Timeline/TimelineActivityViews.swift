import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct TimelineActivityGroupView: View {
  let group: DashboardTimelineGroup
  let sender: DashboardTimelineSenderDisplay
  let website: DashboardWebsite?
  let conversation: DashboardConversation
  let visitor: DashboardVisitor?

  var body: some View {
    HStack {
      Spacer(minLength: ConversationTimelineLayout.sideSpacer)

      VStack(alignment: .center, spacing: 8) {
        ForEach(group.items) { item in
          if item.type == .event || item.type == .identification {
            TimelineEventRowView(
              item: item,
              senderName: sender.name,
              summary: DashboardTimelinePresentation.eventSummary(
                for: item,
                website: website,
                conversation: conversation,
                visitor: visitor
              )
            )
          } else {
            TimelineToolActivityRowView(
              item: item,
              senderName: sender.name
            )
          }
        }
      }
      .frame(maxWidth: ConversationTimelineLayout.activityMaxWidth)

      Spacer(minLength: ConversationTimelineLayout.sideSpacer)
    }
  }
}

struct TimelineDeveloperLogGroupView: View {
  let group: DashboardTimelineGroup
  let sender: DashboardTimelineSenderDisplay

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Spacer(minLength: ConversationTimelineLayout.sideSpacer)

      VStack(alignment: .trailing, spacing: 8) {
        Text("Dev logs")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.tertiary)

        VStack(alignment: .trailing, spacing: 6) {
          ForEach(group.items) { item in
            TimelineDeveloperLogDisclosureRow(
              item: item,
              senderName: sender.name
            )
          }
        }
      }
      .frame(maxWidth: ConversationTimelineLayout.developerLogMaxWidth, alignment: .trailing)
    }
  }
}

struct TimelineEventRowView: View {
  let item: DashboardTimelineItem
  let senderName: String
  let summary: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemSymbol: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: 16, height: 16)
        .padding(.top, 2)

      VStack(alignment: .leading, spacing: 4) {
        Text(summary)
          .font(.subheadline)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 8) {
          Text(senderName)
            .font(.caption2)
            .foregroundStyle(.tertiary)

          Text(item.createdTimeText)
            .font(.caption2)
            .foregroundStyle(.secondary)

          if item.visibility == .private {
            Text("Private")
              .font(.caption2.weight(.medium))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(.quaternary.opacity(0.35), in: .capsule)
          }
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.quaternary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .frame(maxWidth: .infinity, alignment: .center)
  }

  private var symbol: SFSymbol {
    switch item.eventPart?.eventType {
    case "participant_requested":
      .personCropCircleBadgeQuestionmark
    case "participant_joined":
      .personCropCircleBadgePlus
    case "resolved":
      .checkmarkCircle
    case "reopened":
      .arrowUturnLeftCircle
    case "priority_changed":
      .flag
    case "status_changed":
      .circleLefthalfFilled
    case "visitor_identified":
      .personTextRectangle
    default:
      .sparklesRectangleStack
    }
  }
}

struct TimelineToolActivityRowView: View {
  let item: DashboardTimelineItem
  let senderName: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      stateIcon
        .frame(width: 16, height: 16)
        .padding(.top, 2)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(item.toolSummary ?? item.previewText)
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)

          if isPartial {
            AnimatedDotsView(
              style: .subtle,
              color: stateTint,
              dotSize: 4,
              spacing: 3
            )
          }
        }

        HStack(spacing: 8) {
          Text(senderName)
            .font(.caption2)
            .foregroundStyle(.tertiary)

          if let toolDisplayName = item.toolDisplayName {
            Text(toolDisplayName)
              .font(.caption2.weight(.medium))
              .foregroundStyle(.secondary)
          }

          if let stateLabel {
            Text(stateLabel)
              .font(.caption2.weight(.medium))
              .foregroundStyle(stateTint)
          }

          Text(item.createdTimeText)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(backgroundFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(stateTint.opacity(0.12), lineWidth: 1)
    }
    .frame(maxWidth: .infinity, alignment: .center)
  }

  private var isPartial: Bool {
    item.toolPart?.state == "partial"
  }

  private var isError: Bool {
    item.toolPart?.state == "error"
  }

  private var stateLabel: String? {
    guard let state = item.toolPart?.state else { return nil }

    switch state {
    case "partial":
      return "Running"
    case "error":
      return "Failed"
    case "result":
      return "Done"
    default:
      return state.capitalized
    }
  }

  @ViewBuilder
  private var stateIcon: some View {
    if isPartial {
      Image(systemSymbol: .ellipsisCircleFill)
        .font(.caption.weight(.semibold))
        .foregroundStyle(stateTint)
    } else if isError {
      Image(systemSymbol: .xmarkCircleFill)
        .font(.caption.weight(.semibold))
        .foregroundStyle(stateTint)
    } else {
      Image(systemSymbol: .checkmarkCircleFill)
        .font(.caption.weight(.semibold))
        .foregroundStyle(stateTint)
    }
  }

  private var stateTint: Color {
    if isError {
      return .red
    }

    if isPartial {
      return .indigo
    }

    return .secondary
  }

  private var backgroundFill: some ShapeStyle {
    if isError {
      return AnyShapeStyle(.red.opacity(0.06))
    }

    if isPartial {
      return AnyShapeStyle(.indigo.opacity(0.08))
    }

    return AnyShapeStyle(.quaternary.opacity(0.08))
  }
}

struct TimelineDeveloperLogDisclosureRow: View {
  let item: DashboardTimelineItem
  let senderName: String
  @State private var isExpanded = false
  @State private var isHovered = false

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      VStack(alignment: .leading, spacing: 8) {
        if let summary = item.toolSummary {
          Text(summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        if let errorText = item.toolPart?.errorText, !errorText.isEmpty {
          Text(errorText)
            .font(.caption)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
        }

        if let progressMessage = item.toolPart?.progressMessage, !progressMessage.isEmpty {
          Text(progressMessage)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
        }

        HStack(spacing: 8) {
          Text(senderName)

          if let state = item.toolPart?.state, !state.isEmpty {
            Text(state.capitalized)
          }

          if let logType = item.toolPart?.toolTimelineMetadata?.logType {
            Text(logType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
          }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 6)
    } label: {
      HStack(spacing: 8) {
        Image(systemSymbol: .appleTerminal)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.tertiary)

        Text(item.toolDisplayName ?? "Tool")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)

        Spacer(minLength: 4)

        Text(item.createdTimeText)
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
    }
    .disclosureGroupStyle(.automatic)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(maxWidth: ConversationTimelineLayout.developerLogMaxWidth, alignment: .leading)
    .background(rowBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(.separator.opacity(isExpanded || isHovered ? 0.45 : 0.18), lineWidth: 1)
    }
    .onHover { hovered in
      isHovered = hovered
    }
  }

  private var rowBackground: some ShapeStyle {
    if isExpanded || isHovered {
      return AnyShapeStyle(.quaternary.opacity(0.16))
    }

    return AnyShapeStyle(.quaternary.opacity(0.06))
  }
}
