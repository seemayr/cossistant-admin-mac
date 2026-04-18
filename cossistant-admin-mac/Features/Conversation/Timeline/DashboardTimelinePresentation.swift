import Foundation
import SFSafeSymbols
import CossistantAdmin

enum DashboardTimelineSenderKind: String, Hashable, Sendable {
  case visitor
  case human
  case ai
  case system
}

struct DashboardTimelineSender: Hashable, Sendable {
  let id: String
  let kind: DashboardTimelineSenderKind
}

struct DashboardTimelineSenderDisplay: Hashable, Sendable {
  let name: String
  let imageURL: URL?
  let seed: String
  let kind: DashboardTimelineSenderKind

  var symbol: SFSymbol {
    switch kind {
    case .visitor:
      .personFill
    case .human:
      .personCropCircleFill
    case .ai:
      .sparkles
    case .system:
      .gearshape2Fill
    }
  }
}

enum DashboardTimelineGroupStyle: Hashable, Sendable {
  case message
  case publicActivity
  case developerLog
}

struct DashboardTimelineDayMarker: Identifiable, Hashable, Sendable {
  let date: Date

  var id: Date {
    date
  }
}

struct DashboardTimelineGroup: Identifiable, Hashable, Sendable {
  let style: DashboardTimelineGroupStyle
  let sender: DashboardTimelineSender
  var items: [DashboardTimelineItem]

  var id: String {
    "\(style)-\(sender.kind.rawValue)-\(sender.id)-\(firstItemID)"
  }

  var firstItemID: String {
    items.first?.id ?? UUID().uuidString
  }

  var lastItemDate: Date {
    items.last?.createdAtDate ?? .distantPast
  }

  var firstItemDate: Date {
    items.first?.createdAtDate ?? .distantPast
  }
}

struct DashboardTimelinePresentationBundle: Hashable, Sendable {
  let renderables: [DashboardTimelineRenderable]
  let latestSeenEligibleItemID: String?

  static let empty = DashboardTimelinePresentationBundle(
    renderables: [],
    latestSeenEligibleItemID: nil
  )
}

enum DashboardTimelineRenderable: Identifiable, Hashable, Sendable {
  case day(DashboardTimelineDayMarker)
  case group(DashboardTimelineGroup)

  var id: String {
    switch self {
    case .day(let marker):
      "day-\(marker.date.timeIntervalSince1970)"
    case .group(let group):
      "group-\(group.id)"
    }
  }
}

enum DashboardTimelinePresentation {
  private static let groupWindow: TimeInterval = 5 * 60

  static func buildBundle(
    items: [DashboardTimelineItem],
    includeDeveloperLogs: Bool
  ) -> DashboardTimelinePresentationBundle {
    let orderedItems = items.sorted {
      ($0.createdAtDate ?? .distantPast) < ($1.createdAtDate ?? .distantPast)
    }

    var renderables: [DashboardTimelineRenderable] = []
    var currentGroup: DashboardTimelineGroup?
    var currentDay: Date?
    var latestSeenEligibleItemID: String?
    let calendar = Calendar.current

    for item in orderedItems {
      if isSeenEligible(item) {
        latestSeenEligibleItemID = item.id
      }

      guard let itemDate = item.createdAtDate else { continue }
      let itemStyle = style(for: item)
      if itemStyle == .developerLog, !includeDeveloperLogs {
        continue
      }
      let itemDay = calendar.startOfDay(for: itemDate)

      if currentDay != itemDay {
        if let currentGroup {
          renderables.append(.group(currentGroup))
        }
        currentGroup = nil
        currentDay = itemDay
        renderables.append(.day(DashboardTimelineDayMarker(date: itemDay)))
      }

      let candidateGroup = DashboardTimelineGroup(
        style: itemStyle,
        sender: sender(for: item),
        items: [item]
      )

      guard let existingGroup = currentGroup else {
        currentGroup = candidateGroup
        continue
      }

      if canMerge(item: item, into: existingGroup) {
        currentGroup?.items.append(item)
      } else {
        renderables.append(.group(existingGroup))
        currentGroup = candidateGroup
      }
    }

    if let currentGroup {
      renderables.append(.group(currentGroup))
    }

    return DashboardTimelinePresentationBundle(
      renderables: renderables,
      latestSeenEligibleItemID: latestSeenEligibleItemID
    )
  }

  static func senderDisplay(
    for sender: DashboardTimelineSender,
    website: DashboardWebsite?,
    conversation: DashboardConversation?,
    visitor: DashboardVisitor?
  ) -> DashboardTimelineSenderDisplay {
    switch sender.kind {
    case .visitor:
      let name = visitor?.contact?.displayName
        ?? conversation?.visitorDisplayName
        ?? "Visitor"
      let imageURL = visitor?.contact?.image ?? conversation?.visitor.contact?.image
      let seed = visitor?.contact?.avatarSeed
        ?? conversation?.visitor.contact?.email
        ?? sender.id
      return DashboardTimelineSenderDisplay(
        name: name,
        imageURL: imageURL,
        seed: seed,
        kind: .visitor
      )
    case .human:
      let agent = website?.availableHumanAgents.first { $0.id == sender.id }
      let name = agent?.displayName ?? "Team member"
      return DashboardTimelineSenderDisplay(
        name: name,
        imageURL: agent?.image,
        seed: sender.id,
        kind: .human
      )
    case .ai:
      let agent = website?.availableAIAgents.first { $0.id == sender.id }
      let name = agent?.displayName ?? "AI agent"
      return DashboardTimelineSenderDisplay(
        name: name,
        imageURL: agent?.image,
        seed: sender.id,
        kind: .ai
      )
    case .system:
      return DashboardTimelineSenderDisplay(
        name: "System",
        imageURL: nil,
        seed: sender.id,
        kind: .system
      )
    }
  }

  static func eventSummary(
    for item: DashboardTimelineItem,
    website: DashboardWebsite?,
    conversation: DashboardConversation?,
    visitor: DashboardVisitor?
  ) -> String {
    if let message = item.eventPart?.message, !message.isEmpty {
      return message
    }

    if let text = item.text, !text.isEmpty {
      return text
    }

    guard let eventPart = item.eventPart else {
      return item.previewText
    }

    let actorSender = eventActor(for: eventPart)
    let actorName = actorSender.map {
      senderDisplay(
        for: $0,
        website: website,
        conversation: conversation,
        visitor: visitor
      ).name
    } ?? "System"

    return "\(actorName) \(DashboardTimelineItem.defaultEventText(for: eventPart.eventType).lowercased())"
  }

  private static func style(for item: DashboardTimelineItem) -> DashboardTimelineGroupStyle {
    switch item.type {
    case .message:
      .message
    case .tool:
      item.isCustomerFacingTool ? .publicActivity : .developerLog
    case .event, .identification:
      .publicActivity
    }
  }

  private static func sender(for item: DashboardTimelineItem) -> DashboardTimelineSender {
    if let userId = item.userId {
      return DashboardTimelineSender(id: userId, kind: .human)
    }

    if let aiAgentId = item.aiAgentId {
      return DashboardTimelineSender(id: aiAgentId, kind: .ai)
    }

    if let visitorId = item.visitorId {
      return DashboardTimelineSender(id: visitorId, kind: .visitor)
    }

    if let eventPart = item.eventPart,
       let eventActor = eventActor(for: eventPart) {
      return eventActor
    }

    return DashboardTimelineSender(id: item.id, kind: .system)
  }

  private static func eventActor(for event: DashboardTimelineEventPart) -> DashboardTimelineSender? {
    if let actorUserId = event.actorUserId {
      return DashboardTimelineSender(id: actorUserId, kind: .human)
    }

    if let actorAiAgentId = event.actorAiAgentId {
      return DashboardTimelineSender(id: actorAiAgentId, kind: .ai)
    }

    return nil
  }

  private static func canMerge(item: DashboardTimelineItem, into group: DashboardTimelineGroup) -> Bool {
    guard style(for: item) == group.style else { return false }
    guard sender(for: item) == group.sender else { return false }
    guard let itemDate = item.createdAtDate else { return false }

    let lastDate = group.items.last?.createdAtDate ?? .distantPast
    guard itemDate.timeIntervalSince(lastDate) <= groupWindow else { return false }

    switch group.style {
    case .message:
      return group.items.last?.visibility == item.visibility
    case .publicActivity, .developerLog:
      return true
    }
  }

  private static func isSeenEligible(_ item: DashboardTimelineItem) -> Bool {
    item.type == .message
      && item.visibility == .public
      && !item.isPrivateNote
      && (item.userId != nil || item.aiAgentId != nil)
  }
}
