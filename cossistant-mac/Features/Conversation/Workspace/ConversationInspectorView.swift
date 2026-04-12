import SwiftUI
import SFSafeSymbols

struct ConversationInspectorView: View {
  let conversation: DashboardConversation
  let listSnapshotConversation: DashboardConversation?
  let detail: DashboardConversationDetail?
  let visitor: DashboardVisitor?
  let visitorPresence: DashboardVisitorPresence?
  let seenData: [DashboardConversationSeen]
  let realtimeConnectionState: DashboardRealtimeConnectionState
  let showDeveloperLogs: Bool
  let seenDebugState: ConversationSeenDebugState
  let onUpdateConversationMetadata: @MainActor (DashboardMetadata) async throws -> Void

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

          InspectorCard {
            ConversationMetadataSection(
              metadata: detail?.metadata ?? conversation.metadata ?? [:],
              onSave: { metadata in
                try await onUpdateConversationMetadata(metadata)
              }
            )
          }

          if showDeveloperLogs {
            InspectorCard(title: "Seen Debug") {
            ConversationSeenDebugSection(
              conversation: conversation,
              listSnapshotConversation: listSnapshotConversation,
              detail: detail,
              seenData: seenData,
              debugState: seenDebugState
              )
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

private struct ConversationMetadataSection: View {
  let metadata: DashboardMetadata
  let onSave: @MainActor (DashboardMetadata) async throws -> Void

  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .center, spacing: 12) {
        Text("Conversation Metadata")
          .font(.headline)

        Spacer(minLength: 0)

        Button {
          isEditing.toggle()
        } label: {
          Label(
            isEditing ? "Done" : "Edit",
            systemSymbol: isEditing ? .xmark : .pencil
          )
          .labelStyle(.iconOnly)
          .font(.caption.weight(.medium))
        }
        .buttonStyle(.borderless)
        .help(isEditing ? "Close editor" : "Edit conversation metadata")
      }

      if isEditing {
        ConversationMetadataEditor(
          metadata: metadata,
          onSave: { metadata in
            try await onSave(metadata)
          },
          onSaveSuccess: {
            isEditing = false
          }
        )
      } else if metadata.isEmpty {
        Text("No metadata fields yet.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        InspectorMetadataList(metadata: metadata)
      }
    }
  }
}

private struct ConversationMetadataEditor: View {
  let metadata: DashboardMetadata
  let onSave: @MainActor (DashboardMetadata) async throws -> Void
  let onSaveSuccess: @MainActor () -> Void

  @State private var fields: [ConversationMetadataFieldDraft] = []
  @State private var baselineValuesByKey: [String: String] = [:]
  @State private var baselineFingerprint = ""
  @State private var isSaving = false
  @State private var saveErrorMessage: String?
  @State private var saveSuccessMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if fields.isEmpty {
        Text("No metadata fields yet.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        VStack(alignment: .leading, spacing: 10) {
          ForEach($fields) { $field in
            ConversationMetadataFieldRow(
              field: $field,
              isSaving: isSaving,
              onRemove: {
                removeField(field.id)
              }
            )
          }
        }
      }

      HStack(spacing: 12) {
        Button {
          addField()
        } label: {
          Label("Add Field", systemSymbol: .plus)
        }
        .disabled(isSaving)

        Spacer(minLength: 0)

        Button("Reset") {
          resetFields()
        }
        .disabled(isSaving || !canReset)

        Button(isSaving ? "Saving…" : "Save Metadata") {
          Task {
            await saveMetadata()
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSaving || !canSave)
      }

      Text("Metadata is edited as a simple key/value map. Values are saved as strings.")
        .font(.caption)
        .foregroundStyle(.secondary)

      statusView
    }
    .task(id: sourceFingerprint) {
      syncFieldsFromServer()
    }
  }

  @ViewBuilder
  private var statusView: some View {
    if isSaving {
      HStack(spacing: 8) {
        ProgressView()
          .controlSize(.small)
        Text("Saving metadata…")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    } else if let saveErrorMessage {
      Label(saveErrorMessage, systemSymbol: .exclamationmarkTriangleFill)
        .font(.caption)
        .foregroundStyle(.red)
    } else if let validationErrorMessage {
      Label(validationErrorMessage, systemSymbol: .exclamationmarkTriangleFill)
        .font(.caption)
        .foregroundStyle(.orange)
    } else if hasUnsavedChanges {
      Label("Unsaved changes", systemSymbol: .pencilCircle)
        .font(.caption)
        .foregroundStyle(.secondary)
    } else if let saveSuccessMessage {
      Label(saveSuccessMessage, systemSymbol: .checkmarkCircleFill)
        .font(.caption)
        .foregroundStyle(.green)
    } else {
      Label("Metadata is up to date", systemSymbol: .checkmarkCircle)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var sourceValuesByKey: [String: String] {
    metadata.reduce(into: [String: String]()) { result, entry in
      result[entry.key] = entry.value.dashboardDisplayText
    }
  }

  private var sourceFingerprint: String {
    fingerprint(for: rows(from: sourceValuesByKey))
  }

  private var currentFingerprint: String {
    fingerprint(for: fields)
  }

  private var validationErrorMessage: String? {
    do {
      _ = try normalizedFields()
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  private var hasUnsavedChanges: Bool {
    if let normalizedValuesByKey = try? normalizedFields() {
      return normalizedValuesByKey != baselineValuesByKey
    }

    return currentFingerprint != baselineFingerprint
  }

  private var canSave: Bool {
    validationErrorMessage == nil && hasUnsavedChanges
  }

  private var canReset: Bool {
    hasUnsavedChanges || currentFingerprint != baselineFingerprint
  }

  private func syncFieldsFromServer() {
    guard !isSaving else { return }
    guard !hasUnsavedChanges || baselineValuesByKey != sourceValuesByKey else { return }

    baselineValuesByKey = sourceValuesByKey
    fields = rows(from: sourceValuesByKey)
    baselineFingerprint = fingerprint(for: fields)
    saveErrorMessage = nil
    saveSuccessMessage = nil
  }

  private func addField() {
    fields.append(ConversationMetadataFieldDraft())
  }

  private func removeField(_ id: UUID) {
    fields.removeAll { $0.id == id }
  }

  private func resetFields() {
    let rows = rows(from: sourceValuesByKey)
    baselineValuesByKey = sourceValuesByKey
    fields = rows
    baselineFingerprint = fingerprint(for: rows)
    saveErrorMessage = nil
    saveSuccessMessage = nil
  }

  private func saveMetadata() async {
    let valuesByKey: [String: String]

    do {
      valuesByKey = try normalizedFields()
    } catch {
      saveErrorMessage = error.localizedDescription
      saveSuccessMessage = nil
      return
    }

    isSaving = true
    saveErrorMessage = nil
    saveSuccessMessage = nil

    do {
      try await onSave(metadataPayload(for: valuesByKey))
      let rows = rows(from: valuesByKey)
      baselineValuesByKey = valuesByKey
      fields = rows
      baselineFingerprint = fingerprint(for: rows)
      saveSuccessMessage = valuesByKey.isEmpty ? "Metadata cleared." : "Metadata saved."
      onSaveSuccess()
    } catch {
      saveErrorMessage = error.localizedDescription
    }

    isSaving = false
  }

  private func normalizedFields() throws -> [String: String] {
    var valuesByKey: [String: String] = [:]

    for field in fields {
      let key = field.key.trimmingCharacters(in: .whitespacesAndNewlines)

      if key.isEmpty {
        if field.value.isEmpty {
          continue
        }

        throw ConversationMetadataEditorError.missingKey
      }

      guard valuesByKey[key] == nil else {
        throw ConversationMetadataEditorError.duplicateKey(key)
      }

      valuesByKey[key] = field.value
    }

    return valuesByKey
  }

  private func metadataPayload(for valuesByKey: [String: String]) -> DashboardMetadata {
    var payload = valuesByKey.reduce(into: DashboardMetadata()) { result, entry in
      result[entry.key] = .string(entry.value)
    }

    for key in baselineValuesByKey.keys where valuesByKey[key] == nil {
      payload[key] = .null
    }

    return payload
  }

  private func rows(from valuesByKey: [String: String]) -> [ConversationMetadataFieldDraft] {
    valuesByKey
      .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
      .map { ConversationMetadataFieldDraft(key: $0.key, value: $0.value) }
  }

  private func fingerprint(for rows: [ConversationMetadataFieldDraft]) -> String {
    rows
      .map {
        let key = $0.key.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(key)=\($0.value)"
      }
      .joined(separator: "\n")
  }
}

private enum ConversationMetadataEditorError: LocalizedError {
  case missingKey
  case duplicateKey(String)

  var errorDescription: String? {
    switch self {
    case .missingKey:
      "Each metadata row needs a field name."
    case .duplicateKey(let key):
      "Metadata field `\(key)` appears more than once."
    }
  }
}

private struct ConversationMetadataFieldDraft: Identifiable, Equatable {
  let id: UUID
  var key: String
  var value: String

  init(
    id: UUID = UUID(),
    key: String = "",
    value: String = ""
  ) {
    self.id = id
    self.key = key
    self.value = value
  }
}

private struct ConversationMetadataFieldRow: View {
  @Binding var field: ConversationMetadataFieldDraft
  let isSaving: Bool
  let onRemove: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      TextField("Field", text: $field.key)
        .textFieldStyle(.roundedBorder)
        .disabled(isSaving)

      TextField("Value", text: $field.value)
        .textFieldStyle(.roundedBorder)
        .disabled(isSaving)

      Button(role: .destructive) {
        onRemove()
      } label: {
        Image(systemSymbol: .trash)
      }
      .buttonStyle(.borderless)
      .disabled(isSaving)
    }
  }
}

private struct ConversationSeenDebugSection: View {
  let conversation: DashboardConversation
  let listSnapshotConversation: DashboardConversation?
  let detail: DashboardConversationDetail?
  let seenData: [DashboardConversationSeen]
  let debugState: ConversationSeenDebugState

  @State private var didCopyDebugJSON = false
  @State private var copyErrorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .center, spacing: 12) {
        Text("Copy the current debug payload as JSON for inspection outside the app.")
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer(minLength: 0)

        Button {
          copyDebugJSON()
        } label: {
          Label(
            didCopyDebugJSON ? "Copied" : "Copy JSON",
            systemSymbol: didCopyDebugJSON ? .checkmark : .documentOnDocument
          )
        }
        .buttonStyle(.bordered)
      }

      if let copyErrorMessage {
        Label(copyErrorMessage, systemSymbol: .exclamationmarkTriangleFill)
          .font(.caption)
          .foregroundStyle(.red)
      } else if didCopyDebugJSON {
        Label("Seen debug JSON copied to the clipboard.", systemSymbol: .checkmarkCircleFill)
          .font(.caption)
          .foregroundStyle(.green)
      }

      InspectorDebugGroup(
        title: "Unread Resolution",
        note: "Local model state used by the queue and auto-seen logic."
      ) {
        InspectorFieldList(rows: unreadResolutionRows)
      }

      InspectorDebugGroup(
        title: "Inbox Snapshot",
        note: "Fields currently available on the conversation list item from `/conversations/inbox`."
      ) {
        InspectorFieldList(rows: inboxSnapshotRows)
      }

      InspectorDebugGroup(
        title: "Conversation Detail",
        note: "Fields loaded for the selected thread from `GET /conversations/{id}`."
      ) {
        if let detail {
          InspectorFieldList(rows: detailRows(detail))
        } else {
          Text("No detail payload loaded.")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
      }

      InspectorDebugGroup(
        title: "Seen Receipts",
        note: "Rows from `GET /conversations/{id}/seen`, plus realtime updates while this conversation is selected."
      ) {
        if seenData.isEmpty {
          Text("No seen receipts loaded.")
            .font(.caption)
            .foregroundStyle(.tertiary)
        } else {
          VStack(alignment: .leading, spacing: 10) {
            ForEach(seenData) { item in
              InspectorFieldList(rows: receiptRows(item))
            }
          }
        }
      }
    }
  }

  private var unreadResolutionRows: [(String, String)] {
    [
      ("Conversation List Rendering (Current)", debugState.effectiveHasUnreadActivity ? "Unread" : "Read"),
      ("Why (Current)", unreadReasonText(for: conversation, isManuallyMarkedUnread: debugState.isManuallyMarkedUnread)),
      ("Conversation List Rendering (List-Only)", listOnlyRenderingText),
      ("Why (List-Only)", listOnlyReasonText),
      ("Computed Has Unread", yesNo(debugState.effectiveHasUnreadActivity)),
      ("Raw List Has Unread", yesNo(debugState.rawHasUnreadActivity)),
      ("Manual Unread Override", yesNo(debugState.isManuallyMarkedUnread)),
      ("Auto-Mark Seen On Open", yesNo(debugState.shouldAutoMarkSeenOnOpen)),
      ("Auto-Seen Eligible Right Now", yesNo(debugState.autoSeenShouldAttempt)),
      ("Current Actor User ID", debugState.currentActorUserID ?? "nil"),
      ("Current Actor Seen From Receipts", absoluteTime(for: currentActorSeenAt) ?? currentActorSeenAt ?? "nil"),
      ("Team Seen From Receipts", absoluteTime(for: currentTeamSeenAt) ?? currentTeamSeenAt ?? "nil"),
      ("Route", debugState.routeTitle),
      ("Load State", debugState.loadStateDescription),
      ("Selected Conversation ID", debugState.selectedConversationID ?? "nil"),
      ("Selected Detail ID", debugState.selectedConversationDetailID ?? "nil"),
      ("Scene Phase", debugState.scenePhaseDescription),
      ("Control Active State", debugState.controlActiveStateDescription),
      ("Realtime Connection", debugState.realtimeConnectionDescription),
      ("Last Realtime Event", absoluteTime(for: debugState.lastRealtimeEventAt) ?? debugState.lastRealtimeEventAt ?? "nil"),
    ]
  }

  private var listOnlyRenderingText: String {
    guard let listSnapshotConversation else {
      return "Unavailable"
    }

    return renderingText(
      for: listSnapshotConversation,
      isManuallyMarkedUnread: debugState.isManuallyMarkedUnread
    )
  }

  private var listOnlyReasonText: String {
    guard let listSnapshotConversation else {
      return "No pre-detail inbox snapshot was captured for this selection."
    }

    return unreadReasonText(
      for: listSnapshotConversation,
      isManuallyMarkedUnread: debugState.isManuallyMarkedUnread
    )
  }

  private var inboxSnapshotRows: [(String, String)] {
    inboxSnapshotRows(for: conversation)
  }

  private func inboxSnapshotRows(
    for conversation: DashboardConversation
  ) -> [(String, String)] {
    [
      ("ID", conversation.id),
      ("Status", conversation.status.rawValue),
      ("Priority", conversation.priority.rawValue),
      ("Organization ID", conversation.organizationId),
      ("Website ID", conversation.websiteId),
      ("Visitor ID", conversation.visitorId),
      ("Channel", conversation.channel),
      ("Title", conversation.title ?? "nil"),
      ("Created At", absoluteTime(for: conversation.createdAt) ?? conversation.createdAt),
      ("Updated At", absoluteTime(for: conversation.updatedAt) ?? conversation.updatedAt),
      ("Deleted At", absoluteTime(for: conversation.deletedAt) ?? conversation.deletedAt ?? "nil"),
      ("Last Message At", absoluteTime(for: conversation.lastMessageAt) ?? conversation.lastMessageAt ?? "nil"),
      ("Last Seen At", absoluteTime(for: conversation.lastSeenAt) ?? conversation.lastSeenAt ?? "nil"),
      ("Team Last Seen At", absoluteTime(for: conversation.teamLastSeenAt) ?? conversation.teamLastSeenAt ?? "nil"),
      ("Visitor Last Seen At", absoluteTime(for: conversation.visitor.lastSeenAt) ?? conversation.visitor.lastSeenAt ?? "nil"),
      ("Effective Seen Date", conversation.effectiveSeenDate.map(absoluteTime(for:)) ?? "nil"),
      ("Latest Activity Date", absoluteTime(for: conversation.latestActivityDate)),
      ("Has Content", yesNo(conversation.hasContent)),
      ("Latest Message By Human", yesNo(conversation.latestMessageWasSentByHumanTeammate)),
      ("Archived", yesNo(conversation.isArchived)),
      ("Sentiment", conversation.sentiment ?? "nil"),
      ("Sentiment Confidence", conversation.sentimentConfidence.map(String.init(describing:)) ?? "nil"),
      ("Visitor Rating", conversation.visitorRating.map(String.init) ?? "nil"),
      ("Escalated At", absoluteTime(for: conversation.escalatedAt) ?? conversation.escalatedAt ?? "nil"),
      ("Escalation Handled At", absoluteTime(for: conversation.escalationHandledAt) ?? conversation.escalationHandledAt ?? "nil"),
      ("AI Paused Until", absoluteTime(for: conversation.aiPausedUntil) ?? conversation.aiPausedUntil ?? "nil"),
      ("Metadata Count", String(conversation.metadata?.count ?? 0)),
      ("Visitor Is Blocked", yesNo(conversation.visitor.isBlocked)),
      ("Visitor Contact ID", conversation.visitor.contact?.id ?? "nil"),
      ("Visitor Contact Name", conversation.visitor.contact?.name ?? "nil"),
      ("Visitor Contact Email", conversation.visitor.contact?.email ?? "nil"),
      ("Clarification Request ID", conversation.activeClarification?.requestId ?? "nil"),
      ("Clarification Status", conversation.activeClarification?.status ?? "nil"),
      ("Clarification Updated", absoluteTime(for: conversation.activeClarification?.updatedAt) ?? conversation.activeClarification?.updatedAt ?? "nil"),
      ("Last Message Timeline Item", timelineItemSummary(conversation.lastMessageTimelineItem)),
      ("Last Timeline Item", timelineItemSummary(conversation.lastTimelineItem)),
      ("Dashboard Locked", conversation.dashboardLocked.map(yesNo) ?? "nil"),
      ("Dashboard Lock Reason", conversation.dashboardLockReason ?? "nil"),
    ]
  }

  private func detailRows(_ detail: DashboardConversationDetail) -> [(String, String)] {
    [
      ("ID", detail.id),
      ("Title", detail.title ?? "nil"),
      ("Status", detail.status.rawValue),
      ("Website ID", detail.websiteId),
      ("Visitor ID", detail.visitorId),
      ("Created At", absoluteTime(for: detail.createdAt) ?? detail.createdAt),
      ("Updated At", absoluteTime(for: detail.updatedAt) ?? detail.updatedAt),
      ("Deleted At", absoluteTime(for: detail.deletedAt) ?? detail.deletedAt ?? "nil"),
      ("Visitor Rating", detail.visitorRating.map(String.init) ?? "nil"),
      ("Visitor Rating At", absoluteTime(for: detail.visitorRatingAt) ?? detail.visitorRatingAt ?? "nil"),
      ("Visitor Last Seen At", absoluteTime(for: detail.visitorLastSeenAt) ?? detail.visitorLastSeenAt ?? "nil"),
      ("Metadata Count", String(detail.metadata?.count ?? 0)),
      ("Last Timeline Item", timelineItemSummary(detail.lastTimelineItem)),
    ]
  }

  private func receiptRows(_ item: DashboardConversationSeen) -> [(String, String)] {
    [
      ("Receipt ID", item.id),
      ("Actor", item.actorLabel),
      ("Conversation ID", item.conversationId),
      ("User ID", item.userId ?? "nil"),
      ("Visitor ID", item.visitorId ?? "nil"),
      ("AI Agent ID", item.aiAgentId ?? "nil"),
      ("Last Seen At", absoluteTime(for: item.lastSeenAt) ?? item.lastSeenAt),
      ("Created At", absoluteTime(for: item.createdAt) ?? item.createdAt),
      ("Updated At", absoluteTime(for: item.updatedAt) ?? item.updatedAt),
      ("Deleted At", absoluteTime(for: item.deletedAt) ?? item.deletedAt ?? "nil"),
    ]
  }

  private var debugExportJSONString: String? {
    debugExportJSONValue.dashboardPrettyPrintedJSONString
  }

  private var debugExportJSONValue: JSONValue {
    .object([
      "copiedAt": .string(ISO8601DateFormatter().string(from: .now)),
      "conversationId": .string(conversation.id),
      "rendering": .object([
        "current": .object([
          "result": .string(renderingText(
            for: conversation,
            isManuallyMarkedUnread: debugState.isManuallyMarkedUnread
          )),
          "reason": .string(unreadReasonText(
            for: conversation,
            isManuallyMarkedUnread: debugState.isManuallyMarkedUnread
          )),
        ]),
        "listOnly": .object([
          "result": .string(listOnlyRenderingText),
          "reason": .string(listOnlyReasonText),
        ]),
      ]),
      "debugState": .object([
        "currentActorUserId": jsonString(debugState.currentActorUserID),
        "isManuallyMarkedUnread": .bool(debugState.isManuallyMarkedUnread),
        "effectiveHasUnreadActivity": .bool(debugState.effectiveHasUnreadActivity),
        "rawHasUnreadActivity": .bool(debugState.rawHasUnreadActivity),
        "shouldAutoMarkSeenOnOpen": .bool(debugState.shouldAutoMarkSeenOnOpen),
        "autoSeenShouldAttempt": .bool(debugState.autoSeenShouldAttempt),
        "routeTitle": .string(debugState.routeTitle),
        "selectedConversationId": jsonString(debugState.selectedConversationID),
        "selectedConversationDetailId": jsonString(debugState.selectedConversationDetailID),
        "loadStateDescription": .string(debugState.loadStateDescription),
        "scenePhaseDescription": .string(debugState.scenePhaseDescription),
        "controlActiveStateDescription": .string(debugState.controlActiveStateDescription),
        "realtimeConnectionDescription": .string(debugState.realtimeConnectionDescription),
        "lastRealtimeEventAt": jsonString(debugState.lastRealtimeEventAt),
        "currentActorSeenAt": jsonString(currentActorSeenAt),
        "teamSeenAt": jsonString(currentTeamSeenAt),
      ]),
      "displayedRows": .object([
        "unreadResolution": rowsJSONObject(unreadResolutionRows),
        "currentInboxSnapshot": rowsJSONObject(inboxSnapshotRows),
        "conversationDetail": detail.map { rowsJSONObject(detailRows($0)) } ?? .null,
        "seenReceipts": .array(seenData.map { rowsJSONObject(receiptRows($0)) }),
      ]),
      "rawData": .object([
        "currentListEntry": currentConversationJSONObject,
        "originalListSnapshot": listSnapshotConversation.map {
          conversationJSONObject($0)
        } ?? .null,
        "detail": detail.map(detailJSONObject(_:)) ?? .null,
        "seenReceipts": .array(seenData.map(seenReceiptJSONObject(_:))),
      ]),
    ])
  }

  private var currentConversationJSONObject: JSONValue {
    conversationJSONObject(conversation)
  }

  private func conversationJSONObject(_ conversation: DashboardConversation) -> JSONValue {
    .object([
      "id": .string(conversation.id),
      "status": .string(conversation.status.rawValue),
      "priority": .string(conversation.priority.rawValue),
      "organizationId": .string(conversation.organizationId),
      "websiteId": .string(conversation.websiteId),
      "visitorId": .string(conversation.visitorId),
      "channel": .string(conversation.channel),
      "title": jsonString(conversation.title),
      "createdAt": .string(conversation.createdAt),
      "updatedAt": .string(conversation.updatedAt),
      "deletedAt": jsonString(conversation.deletedAt),
      "lastMessageAt": jsonString(conversation.lastMessageAt),
      "lastSeenAt": jsonString(conversation.lastSeenAt),
      "teamLastSeenAt": jsonString(conversation.teamLastSeenAt),
      "effectiveSeenDate": jsonString(conversation.effectiveSeenDate?.ISO8601Format()),
      "latestActivityDate": .string(conversation.latestActivityDate.ISO8601Format()),
      "hasContent": .bool(conversation.hasContent),
      "latestMessageWasSentByHumanTeammate": .bool(conversation.latestMessageWasSentByHumanTeammate),
      "isArchived": .bool(conversation.isArchived),
      "hasUnreadActivity": .bool(conversation.hasUnreadActivity),
      "sentiment": jsonString(conversation.sentiment),
      "sentimentConfidence": conversation.sentimentConfidence.map(JSONValue.number) ?? .null,
      "visitorRating": conversation.visitorRating.map { .number(Double($0)) } ?? .null,
      "escalatedAt": jsonString(conversation.escalatedAt),
      "escalationHandledAt": jsonString(conversation.escalationHandledAt),
      "aiPausedUntil": jsonString(conversation.aiPausedUntil),
      "metadata": conversation.metadata.map(JSONValue.object) ?? .null,
      "visitor": .object([
        "id": .string(conversation.visitor.id),
        "lastSeenAt": jsonString(conversation.visitor.lastSeenAt),
        "isBlocked": .bool(conversation.visitor.isBlocked),
        "contact": conversation.visitor.contact.map { contact in
          .object([
            "id": .string(contact.id),
            "name": jsonString(contact.name),
            "email": jsonString(contact.email),
            "image": contact.image.map { .string($0.absoluteString) } ?? .null,
            "metadata": contact.metadata.map(JSONValue.object) ?? .null,
          ])
        } ?? .null,
      ]),
      "activeClarification": conversation.activeClarification.map { clarification in
        .object([
          "requestId": .string(clarification.requestId),
          "status": .string(clarification.status),
          "question": jsonString(clarification.question),
          "updatedAt": .string(clarification.updatedAt),
        ])
      } ?? .null,
      "lastMessageTimelineItem": conversationTimelineItemJSONObject(conversation.lastMessageTimelineItem),
      "lastTimelineItem": conversationTimelineItemJSONObject(conversation.lastTimelineItem),
      "dashboardLocked": conversation.dashboardLocked.map(JSONValue.bool) ?? .null,
      "dashboardLockReason": jsonString(conversation.dashboardLockReason),
    ])
  }

  private func detailJSONObject(_ detail: DashboardConversationDetail) -> JSONValue {
    .object([
      "id": .string(detail.id),
      "title": jsonString(detail.title),
      "metadata": detail.metadata.map(JSONValue.object) ?? .null,
      "createdAt": .string(detail.createdAt),
      "updatedAt": .string(detail.updatedAt),
      "visitorId": .string(detail.visitorId),
      "websiteId": .string(detail.websiteId),
      "status": .string(detail.status.rawValue),
      "visitorRating": detail.visitorRating.map { .number(Double($0)) } ?? .null,
      "visitorRatingAt": jsonString(detail.visitorRatingAt),
      "deletedAt": jsonString(detail.deletedAt),
      "visitorLastSeenAt": jsonString(detail.visitorLastSeenAt),
      "lastTimelineItem": dashboardTimelineItemJSONObject(detail.lastTimelineItem),
    ])
  }

  private func seenReceiptJSONObject(_ item: DashboardConversationSeen) -> JSONValue {
    .object([
      "id": .string(item.id),
      "actorLabel": .string(item.actorLabel),
      "conversationId": .string(item.conversationId),
      "userId": jsonString(item.userId),
      "visitorId": jsonString(item.visitorId),
      "aiAgentId": jsonString(item.aiAgentId),
      "lastSeenAt": .string(item.lastSeenAt),
      "createdAt": .string(item.createdAt),
      "updatedAt": .string(item.updatedAt),
      "deletedAt": jsonString(item.deletedAt),
    ])
  }

  private func conversationTimelineItemJSONObject(
    _ item: DashboardConversation.TimelineItem?
  ) -> JSONValue {
    guard let item else { return .null }

    return .object([
      "id": jsonString(item.id),
      "type": .string(item.type),
      "text": jsonString(item.text),
      "userId": jsonString(item.userId),
      "aiAgentId": jsonString(item.aiAgentId),
      "visitorId": jsonString(item.visitorId),
      "createdAt": .string(item.createdAt),
      "previewText": .string(item.previewText),
    ])
  }

  private func dashboardTimelineItemJSONObject(
    _ item: DashboardTimelineItem?
  ) -> JSONValue {
    guard let item else { return .null }

    return .object([
      "id": .string(item.id),
      "conversationId": .string(item.conversationId),
      "organizationId": .string(item.organizationId),
      "visibility": .string(item.visibility.rawValue),
      "type": .string(item.type.rawValue),
      "text": jsonString(item.text),
      "tool": jsonString(item.tool),
      "userId": jsonString(item.userId),
      "aiAgentId": jsonString(item.aiAgentId),
      "visitorId": jsonString(item.visitorId),
      "createdAt": .string(item.createdAt),
      "deletedAt": jsonString(item.deletedAt),
      "previewText": .string(item.previewText),
    ])
  }

  private func rowsJSONObject(_ rows: [(String, String)]) -> JSONValue {
    .object(
      rows.reduce(into: [String: JSONValue]()) { result, row in
        result[row.0] = .string(row.1)
      }
    )
  }

  private func jsonString(_ value: String?) -> JSONValue {
    value.map(JSONValue.string) ?? .null
  }

  private func copyDebugJSON() {
    guard let debugExportJSONString else {
      copyErrorMessage = "Could not encode the seen debug payload."
      didCopyDebugJSON = false
      return
    }

    StringClipboardWriter.copy(debugExportJSONString)
    copyErrorMessage = nil
    didCopyDebugJSON = true

    Task {
      try? await Task.sleep(for: .seconds(1.5))
      didCopyDebugJSON = false
    }
  }

  private var currentActorSeenAt: String? {
    guard let currentActorUserID = debugState.currentActorUserID else { return nil }

    return seenData
      .filter { $0.userId == currentActorUserID }
      .max { left, right in
        (left.lastSeenDate ?? .distantPast) < (right.lastSeenDate ?? .distantPast)
      }?
      .lastSeenAt
  }

  private var currentTeamSeenAt: String? {
    seenData
      .filter { $0.userId != nil }
      .max { left, right in
        (left.lastSeenDate ?? .distantPast) < (right.lastSeenDate ?? .distantPast)
      }?
      .lastSeenAt
  }

  private func yesNo(_ value: Bool) -> String {
    value ? "Yes" : "No"
  }

  private func renderingText(
    for conversation: DashboardConversation,
    isManuallyMarkedUnread: Bool
  ) -> String {
    (isManuallyMarkedUnread || conversation.hasUnreadActivity) ? "Unread" : "Read"
  }

  private func unreadReasonText(
    for conversation: DashboardConversation,
    isManuallyMarkedUnread: Bool
  ) -> String {
    if isManuallyMarkedUnread {
      return "The local manual unread override is set, so the conversation list would force this conversation to appear unread."
    }

    if !conversation.hasContent {
      return "The list would show this conversation as read because there is no last message content yet, so raw unread detection returns false."
    }

    if conversation.latestMessageWasSentByHumanTeammate {
      return "The list would show this conversation as read because the latest message was sent by a human teammate, which suppresses unread status."
    }

    guard let effectiveSeenDate = conversation.effectiveSeenDate else {
      return "The list would show this conversation as unread because there is content, the latest message was not sent by a human teammate, and there is no effective seen date."
    }

    if conversation.latestActivityDate > effectiveSeenDate {
      return "The list would show this conversation as unread because the latest activity is newer than the effective seen date."
    }

    return "The list would show this conversation as read because the effective seen date is as new as or newer than the latest activity."
  }

  private func absoluteTime(for value: String?) -> String? {
    DashboardTimestampParser.absoluteString(from: value)
  }

  private func absoluteTime(for value: Date) -> String {
    return DateFormatter.dashboardDebug.string(from: value)
  }

  private func timelineItemSummary(_ item: DashboardConversation.TimelineItem?) -> String {
    guard let item else { return "nil" }

    return [
      "id=\(item.id ?? "nil")",
      "type=\(item.type)",
      "createdAt=\(item.createdAt)",
      "userId=\(item.userId ?? "nil")",
      "aiAgentId=\(item.aiAgentId ?? "nil")",
      "visitorId=\(item.visitorId ?? "nil")",
    ]
      .joined(separator: " • ")
  }

  private func timelineItemSummary(_ item: DashboardTimelineItem?) -> String {
    guard let item else { return "nil" }

    return [
      "id=\(item.id)",
      "type=\(item.type.rawValue)",
      "createdAt=\(item.createdAt)",
      "userId=\(item.userId ?? "nil")",
      "aiAgentId=\(item.aiAgentId ?? "nil")",
      "visitorId=\(item.visitorId ?? "nil")",
    ]
      .joined(separator: " • ")
  }
}

private struct InspectorDebugGroup<Content: View>: View {
  let title: String
  let note: String
  @ViewBuilder let content: Content

  init(
    title: String,
    note: String,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.note = note
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline.weight(.semibold))

      Text(note)
        .font(.caption)
        .foregroundStyle(.secondary)

      content
    }
  }
}

private extension DateFormatter {
  static let dashboardDebug: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter
  }()
}

private struct InspectorCopyRow: View {
  let title: String
  let value: String

  @State private var copied = false

  var body: some View {
    Button {
      StringClipboardWriter.copy(value)
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
