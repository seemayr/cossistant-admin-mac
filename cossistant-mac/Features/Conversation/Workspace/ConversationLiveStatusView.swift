import SwiftUI

struct ConversationLiveStatusSection: View {
  let website: DashboardWebsite?
  let conversation: DashboardConversation
  let visitor: DashboardVisitor?
  let visitorPresence: DashboardVisitorPresence?
  let typingEvent: DashboardRealtimeConversationTypingPayload?
  let aiProcessingState: DashboardRealtimeAIProcessingState?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let visitorTypingStatus {
        ConversationLiveStatusCard(status: visitorTypingStatus)
      }

      if let humanTypingStatus {
        ConversationLiveStatusCard(status: humanTypingStatus)
      }

      if let aiProcessingStatus {
        ConversationLiveStatusCard(status: aiProcessingStatus)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var visitorTypingStatus: ConversationLiveStatus? {
    guard let typingEvent, typingEvent.isTyping else { return nil }
    guard typingEvent.userId == nil, typingEvent.aiAgentId == nil else { return nil }

    return ConversationLiveStatus(
      title: "\(visitor?.contact?.displayName ?? conversation.visitorDisplayName) is typing",
      subtitle: typingEvent.visitorPreview?.nilIfEmpty ?? "Drafting a message…",
      name: visitor?.contact?.displayName ?? conversation.visitorDisplayName,
      imageURL: visitor?.contact?.image ?? conversation.visitorAvatarURL,
      seed: conversation.visitorId,
      role: .person,
      showsActivePresence: visitorPresence?.isActive == true,
      accent: .accentColor,
      animationStyle: .bounce
    )
  }

  private var humanTypingStatus: ConversationLiveStatus? {
    guard let typingEvent, typingEvent.isTyping, let userId = typingEvent.userId else { return nil }
    let agent = website?.availableHumanAgents.first { $0.id == userId }

    return ConversationLiveStatus(
      title: "\(agent?.displayName ?? "Team member") is replying",
      subtitle: "Preparing a response",
      name: agent?.displayName ?? "Team member",
      imageURL: agent?.image,
      seed: userId,
      role: .person,
      showsActivePresence: false,
      accent: .secondary,
      animationStyle: .subtle
    )
  }

  private var aiProcessingStatus: ConversationLiveStatus? {
    if let aiProcessingState {
      let agent = website?.availableAIAgents.first { $0.id == aiProcessingState.aiAgentId }
      return ConversationLiveStatus(
        title: "\(agent?.displayName ?? "AI agent") is \(aiProcessingState.phaseDisplayTitle.lowercased())",
        subtitle: aiProcessingState.statusText,
        name: agent?.displayName ?? "AI agent",
        imageURL: agent?.image,
        seed: aiProcessingState.aiAgentId,
        role: .ai,
        showsActivePresence: false,
        accent: .indigo,
        animationStyle: .pulse
      )
    }

    guard let typingEvent, typingEvent.isTyping, let aiAgentId = typingEvent.aiAgentId else {
      return nil
    }
    let agent = website?.availableAIAgents.first { $0.id == aiAgentId }

    return ConversationLiveStatus(
      title: "\(agent?.displayName ?? "AI agent") is thinking",
      subtitle: "Preparing the next reply",
      name: agent?.displayName ?? "AI agent",
      imageURL: agent?.image,
      seed: aiAgentId,
      role: .ai,
      showsActivePresence: false,
      accent: .indigo,
      animationStyle: .pulse
    )
  }
}

private struct ConversationLiveStatus {
  let title: String
  let subtitle: String
  let name: String
  let imageURL: URL?
  let seed: String
  let role: AvatarRole
  let showsActivePresence: Bool
  let accent: Color
  let animationStyle: AnimatedDotsView.Style
}

private struct ConversationLiveStatusCard: View {
  let status: ConversationLiveStatus

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      AvatarView(
        name: status.name,
        imageURL: status.imageURL,
        seed: status.seed,
        size: 28,
        showsActivePresence: status.showsActivePresence,
        role: status.role
      )

      VStack(alignment: .leading, spacing: 3) {
        Text(status.title)
          .font(.subheadline.weight(.medium))

        Text(status.subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      Spacer(minLength: 0)

      AnimatedDotsView(
        style: status.animationStyle,
        color: status.accent,
        dotSize: 5,
        spacing: 4
      )
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(status.accent.opacity(0.16), lineWidth: 1)
    }
  }
}

struct AnimatedDotsView: View {
  enum Style {
    case bounce
    case pulse
    case subtle
  }

  let style: Style
  var color: Color = .secondary
  var dotSize: CGFloat = 6
  var spacing: CGFloat = 4

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isAnimating = false

  var body: some View {
    HStack(spacing: spacing) {
      ForEach(0..<3, id: \.self) { index in
        Circle()
          .fill(color)
          .frame(width: dotSize, height: dotSize)
          .modifier(
            AnimatedDotStyleModifier(
              style: style,
              isAnimating: isAnimating
            )
          )
          .animation(
            reduceMotion ? nil : animation(for: index),
            value: isAnimating
          )
      }
    }
    .task(id: reduceMotion) {
      isAnimating = !reduceMotion
    }
  }

  private func animation(for index: Int) -> Animation {
    let delay = Double(index) * 0.14

    switch style {
    case .bounce:
      return .easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(delay)
    case .pulse:
      return .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(delay)
    case .subtle:
      return .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay)
    }
  }
}

private struct AnimatedDotStyleModifier: ViewModifier {
  let style: AnimatedDotsView.Style
  let isAnimating: Bool

  func body(content: Content) -> some View {
    switch style {
    case .bounce:
      content
        .offset(y: isAnimating ? -3.5 : 0)
    case .pulse:
      content
        .scaleEffect(isAnimating ? 1.2 : 0.65)
        .opacity(isAnimating ? 1 : 0.35)
    case .subtle:
      content
        .opacity(isAnimating ? 1 : 0.35)
    }
  }
}
