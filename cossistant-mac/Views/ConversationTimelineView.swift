import AppKit
import SwiftUI
import SFSafeSymbols

private enum ConversationTimelineLayout {
  static let threadMaxWidth: CGFloat = 760
  static let messageMaxWidth: CGFloat = 620
  static let activityMaxWidth: CGFloat = 520
  static let developerLogMaxWidth: CGFloat = 320
  static let sideSpacer: CGFloat = 88
}

struct ConversationTimelineView: View {
  let website: DashboardWebsite?
  let conversation: DashboardConversation
  let visitor: DashboardVisitor?
  let items: [DashboardTimelineItem]
  let seenData: [DashboardConversationSeen]
  let translatedMessagesByID: [String: DashboardMessageTranslation]
  let showDeveloperLogs: Bool
  let canLoadMoreTimeline: Bool
  let isLoadingMoreTimeline: Bool
  let onLoadMoreTimeline: () -> Void

  private var renderables: [DashboardTimelineRenderable] {
    DashboardTimelinePresentation.build(
      items: items,
      includeDeveloperLogs: showDeveloperLogs
    )
  }

  private var latestSeenEligibleItemID: String? {
    items
      .sorted { ($0.createdAtDate ?? .distantPast) < ($1.createdAtDate ?? .distantPast) }
      .last {
        $0.type == .message
          && $0.visibility == .public
          && !$0.isPrivateNote
          && ($0.userId != nil || $0.aiAgentId != nil)
      }?
      .id
  }

  private var seenReceipts: [TimelineSeenReceiptDisplay] {
    seenData
      .compactMap { item in
        TimelineSeenReceiptDisplay(
          seen: item,
          website: website
        )
      }
      .filter { $0.role != .person || $0.actorID != conversation.visitorId }
      .sorted { $0.lastSeenDate > $1.lastSeenDate }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      ForEach(renderables) { renderable in
        switch renderable {
        case .day(let marker):
          TimelineDaySeparatorView(date: marker.date)
        case .group(let group):
          groupView(group)
        }
      }

      if canLoadMoreTimeline {
        Button(action: onLoadMoreTimeline) {
          Label(
            isLoadingMoreTimeline ? "Loading more…" : "Load older activity",
            systemSymbol: .ellipsisCircle
          )
        }
        .buttonStyle(.borderless)
        .disabled(isLoadingMoreTimeline)
        .padding(.top, 6)
      }
    }
    .frame(maxWidth: ConversationTimelineLayout.threadMaxWidth, alignment: .leading)
  }

  @ViewBuilder
  private func groupView(_ group: DashboardTimelineGroup) -> some View {
    switch group.style {
    case .message:
      TimelineMessageGroupView(
        group: group,
        sender: senderDisplay(for: group.sender),
        translatedMessagesByID: translatedMessagesByID,
        seenReceipts: group.items.last?.id == latestSeenEligibleItemID ? seenReceipts : []
      )
    case .publicActivity:
      TimelineActivityGroupView(
        group: group,
        sender: senderDisplay(for: group.sender),
        website: website,
        conversation: conversation,
        visitor: visitor
      )
    case .developerLog:
      TimelineDeveloperLogGroupView(
        group: group,
        sender: senderDisplay(for: group.sender)
      )
    }
  }

  private func senderDisplay(for sender: DashboardTimelineSender) -> DashboardTimelineSenderDisplay {
    DashboardTimelinePresentation.senderDisplay(
      for: sender,
      website: website,
      conversation: conversation,
      visitor: visitor
    )
  }
}

private struct TimelineDaySeparatorView: View {
  let date: Date

  var body: some View {
    HStack(spacing: 12) {
      Rectangle()
        .fill(.separator.opacity(0.5))
        .frame(height: 1)

      Text(labelText)
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)

      Rectangle()
        .fill(.separator.opacity(0.5))
        .frame(height: 1)
    }
    .padding(.vertical, 4)
  }

  private var labelText: String {
    let calendar = Calendar.current

    if calendar.isDateInToday(date) {
      return "Today"
    }

    if calendar.isDateInYesterday(date) {
      return "Yesterday"
    }

    return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
  }
}

private struct TimelineMessageGroupView: View {
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
        DashboardAvatarView(
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
      .frame(maxWidth: ConversationTimelineLayout.messageMaxWidth, alignment: alignsTrailing ? .trailing : .leading)

      if !alignsTrailing {
        Spacer(minLength: ConversationTimelineLayout.sideSpacer)
      } else {
        DashboardAvatarView(
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

private struct TimelineMessageBubbleView: View {
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

private struct TimelineSeenReceiptDisplay: Identifiable, Hashable {
  let id: String
  let actorID: String
  let name: String
  let imageURL: URL?
  let role: DashboardAvatarRole
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

private struct TimelineSeenIndicatorView: View {
  let receipts: [TimelineSeenReceiptDisplay]

  var body: some View {
    HStack(spacing: 4) {
      HStack(spacing: -4) {
        ForEach(receipts.prefix(3)) { receipt in
          DashboardAvatarView(
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

private struct TimelineActivityGroupView: View {
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

private struct TimelineDeveloperLogGroupView: View {
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

private struct TimelineEventRowView: View {
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

private struct TimelineToolActivityRowView: View {
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

private struct TimelineDeveloperLogDisclosureRow: View {
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

private struct TimelineImageStripView: View {
  let images: [DashboardTimelineImagePart]
  @State private var selectedImage: TimelineImagePreviewItem?

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(Array(images.enumerated()), id: \.offset) { _, image in
          TimelineImageThumbnailButton(image: image) {
            selectedImage = TimelineImagePreviewItem(image: image)
          }
        }
      }
    }
    .sheet(item: $selectedImage) { preview in
      TimelineImagePreviewSheet(preview: preview)
    }
  }
}

private struct TimelineFileStripView: View {
  let files: [DashboardTimelineFilePart]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(files.enumerated()), id: \.offset) { _, file in
        TimelineFileAttachmentCard(file: file)
      }
    }
  }
}

private struct TimelineImageThumbnailButton: View {
  let image: DashboardTimelineImagePart
  let onPreview: () -> Void

  var body: some View {
    Button(action: onPreview) {
      ZStack(alignment: .bottomTrailing) {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(.quaternary.opacity(0.18))

        AsyncImage(url: image.remoteURL) { phase in
          switch phase {
          case .success(let loadedImage):
            loadedImage
              .resizable()
              .scaledToFit()
              .padding(6)
          default:
            Image(systemSymbol: .photo)
              .foregroundStyle(.secondary)
          }
        }

        Image(systemSymbol: .arrowUpLeftAndArrowDownRight)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.white)
          .padding(6)
          .background(.black.opacity(0.5), in: Circle())
          .padding(6)
      }
      .frame(width: 132, height: 92)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .contextMenu {
      if let url = image.remoteURL {
        Link(destination: url) {
          Label("Open Original", systemSymbol: .arrowUpForwardSquare)
        }

        Button {
          Task {
            await TimelineAttachmentSaveCoordinator.save(
              from: url,
              suggestedFilename: image.filename
            )
          }
        } label: {
          Label("Save As…", systemSymbol: .arrowDownCircle)
        }
      }
    }
    .help("View full image")
  }
}

private struct TimelineFileAttachmentCard: View {
  let file: DashboardTimelineFilePart
  @Environment(\.openURL) private var openURL

  var body: some View {
    HStack(spacing: 10) {
      Image(systemSymbol: icon)
        .font(.body)
        .foregroundStyle(Color.accentColor)
        .frame(width: 18, height: 18)

      VStack(alignment: .leading, spacing: 2) {
        Text(file.filename ?? "Attachment")
          .font(.caption.weight(.medium))
          .lineLimit(1)
          .truncationMode(.middle)

        HStack(spacing: 6) {
          Text(file.mediaType)
            .font(.caption2)
            .foregroundStyle(.secondary)

          if let sizeLabel = file.formattedSize {
            Text("•")
              .font(.caption2)
              .foregroundStyle(.tertiary)

            Text(sizeLabel)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }

      Spacer(minLength: 0)

      if let url = file.remoteURL {
        Button {
          openURL(url)
        } label: {
          Label("Open", systemSymbol: .arrowUpForwardSquare)
            .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)

        Button {
          Task {
            await TimelineAttachmentSaveCoordinator.save(
              from: url,
              suggestedFilename: file.filename
            )
          }
        } label: {
          Image(systemSymbol: .arrowDownCircle)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .help("Save attachment")
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(.separator.opacity(0.18), lineWidth: 1)
    }
    .contextMenu {
      if let url = file.remoteURL {
        Link(destination: url) {
          Label("Open Original", systemSymbol: .arrowUpForwardSquare)
        }

        Button {
          Task {
            await TimelineAttachmentSaveCoordinator.save(
              from: url,
              suggestedFilename: file.filename
            )
          }
        } label: {
          Label("Save As…", systemSymbol: .arrowDownCircle)
        }
      }
    }
    .help(file.remoteURL == nil ? "Attachment URL unavailable" : "Open the original attachment")
  }

  private var icon: SFSymbol {
    let mediaType = file.mediaType.lowercased()

    if mediaType.contains("pdf") {
      return .richtextPage
    }

    if mediaType.hasPrefix("image") {
      return .photo
    }

    if mediaType.hasPrefix("video") {
      return .film
    }

    if mediaType.hasPrefix("audio") {
      return .waveform
    }

    if mediaType.contains("zip") || mediaType.contains("compressed") {
      return .archivebox
    }

    return .paperclip
  }
}

private struct TimelineImagePreviewItem: Identifiable {
  let id: String
  let url: URL
  let filename: String?
  let width: Int?
  let height: Int?

  init?(image: DashboardTimelineImagePart) {
    guard let url = image.remoteURL else { return nil }
    self.id = image.url
    self.url = url
    self.filename = image.filename
    self.width = image.width
    self.height = image.height
  }
}

private struct TimelineImagePreviewSheet: View {
  let preview: TimelineImagePreviewItem
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(preview.filename ?? "Image")
            .font(.headline)
            .lineLimit(1)

          if let metadataText {
            Text(metadataText)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer(minLength: 12)

        Button {
          openURL(preview.url)
        } label: {
          Label("Open Original", systemSymbol: .arrowUpForwardSquare)
        }

        Button {
          Task {
            await TimelineAttachmentSaveCoordinator.save(
              from: preview.url,
              suggestedFilename: preview.suggestedFilename
            )
          }
        } label: {
          Label("Save As…", systemSymbol: .arrowDownCircle)
        }

        Button("Done") {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .background(.bar)

      Divider()

      ZStack {
        Color.black.opacity(0.92)
          .ignoresSafeArea()

        AsyncImage(url: preview.url) { phase in
          switch phase {
          case .success(let loadedImage):
            loadedImage
              .resizable()
              .scaledToFit()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .padding(24)
          case .failure:
            ContentUnavailableView(
              "Image unavailable",
              systemImage: SFSymbol.photo.rawValue,
              description: Text("The original image could not be loaded.")
            )
            .foregroundStyle(.white.opacity(0.8))
          default:
            ProgressView()
              .controlSize(.large)
              .tint(.white)
          }
        }
      }
    }
    .frame(minWidth: 760, minHeight: 520)
    .background(.black)
  }

  private var metadataText: String? {
    var components: [String] = []

    if let width = preview.width, let height = preview.height {
      components.append("\(width) × \(height)")
    }

    let pathExtension = preview.url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
    if !pathExtension.isEmpty {
      components.append(pathExtension.uppercased())
    }

    return components.isEmpty ? nil : components.joined(separator: " • ")
  }
}

@MainActor
private enum TimelineAttachmentSaveCoordinator {
  static func save(from remoteURL: URL, suggestedFilename: String?) async {
    let panel = NSSavePanel()
    panel.canCreateDirectories = true
    panel.isExtensionHidden = false
    panel.nameFieldStringValue = resolvedFilename(
      remoteURL: remoteURL,
      suggestedFilename: suggestedFilename
    )

    guard panel.runModal() == .OK, let destinationURL = panel.url else {
      return
    }

    do {
      let (temporaryURL, _) = try await URLSession.shared.download(from: remoteURL)
      let fileManager = FileManager.default

      if fileManager.fileExists(atPath: destinationURL.path()) {
        try fileManager.removeItem(at: destinationURL)
      }

      try fileManager.copyItem(at: temporaryURL, to: destinationURL)
    } catch {
      NSAlert(error: error).runModal()
    }
  }

  private static func resolvedFilename(remoteURL: URL, suggestedFilename: String?) -> String {
    let trimmedSuggestion = suggestedFilename?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmedSuggestion.isEmpty {
      return trimmedSuggestion
    }

    let remoteName = remoteURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
    if !remoteName.isEmpty && remoteName != "/" {
      return remoteName
    }

    return "Attachment"
  }
}

private extension DashboardTimelineFilePart {
  var remoteURL: URL? {
    URL(string: url)
  }

  var formattedSize: String? {
    guard let size else { return nil }
    return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
  }
}

private extension DashboardTimelineImagePart {
  var remoteURL: URL? {
    URL(string: url)
  }
}

private extension TimelineImagePreviewItem {
  var suggestedFilename: String? {
    let trimmedFilename = filename?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmedFilename.isEmpty {
      return trimmedFilename
    }

    let remoteName = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
    return remoteName.isEmpty || remoteName == "/" ? nil : remoteName
  }
}
