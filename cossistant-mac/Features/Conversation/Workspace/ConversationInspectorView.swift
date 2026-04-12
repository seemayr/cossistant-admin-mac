import AppKit
import SwiftUI
import SFSafeSymbols

struct ConversationInspectorView: View {
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
              AvatarPreviewButton(
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
