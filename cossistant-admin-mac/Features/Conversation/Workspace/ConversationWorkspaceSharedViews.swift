import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct InspectorCard<Content: View>: View {
  let title: String?
  @ViewBuilder let content: Content

  init(
    title: String? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      if let title {
        Text(title)
          .font(.headline)
      }

      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: ConversationWorkspaceLayout.cardCornerRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: ConversationWorkspaceLayout.cardCornerRadius, style: .continuous)
        .strokeBorder(.separator.opacity(0.18), lineWidth: 1)
    }
  }
}

struct WorkspaceMetadataPill: View {
  let title: String
  let systemImage: SFSymbol
  let tint: Color

  var body: some View {
    Label(title, systemSymbol: systemImage)
      .font(.caption.weight(.medium))
      .foregroundStyle(tint)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.quaternary.opacity(0.28), in: Capsule())
  }
}

struct WorkspaceInlineBadge: View {
  let title: String
  let systemImage: SFSymbol
  let tint: Color

  var body: some View {
    Label(title, systemSymbol: systemImage)
      .font(.caption.weight(.medium))
      .foregroundStyle(tint)
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(tint.opacity(0.08), in: Capsule())
  }
}

struct SyncStateBadge: View {
  let state: DashboardRealtimeConnectionState

  var body: some View {
    WorkspaceInlineBadge(
      title: label,
      systemImage: symbol,
      tint: tint
    )
  }

  private var label: String {
    switch state {
    case .connected:
      "Realtime"
    case .connecting:
      "Connecting"
    case .disconnected:
      "Polling"
    case .failed:
      "Blocked"
    }
  }

  private var symbol: SFSymbol {
    switch state {
    case .connected:
      .boltHorizontalCircleFill
    case .connecting:
      .boltHorizontalCircle
    case .disconnected:
      .clockArrowTriangleheadCounterclockwiseRotate90
    case .failed:
      .exclamationmarkTriangleFill
    }
  }

  private var tint: Color {
    switch state {
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
}
