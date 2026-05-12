import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct WorkspaceSidebarView: View {
  @Bindable var model: WorkspaceModel
  @Bindable var inboxStore: InboxStore
  @Binding var selection: WorkspaceRoute?
  let onRefresh: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      List(selection: $selection) {
        if let website = model.website {
          Section {
            VStack(alignment: .leading, spacing: 6) {
              Text(website.name)
                .font(.headline)

              if let domain = website.domain, !domain.isEmpty {
                Text(domain)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 4)
          }
        }

        Section("Inboxes") {
          ForEach(InboxScope.allCases) { scope in
            Label(scope.title, systemSymbol: scope.systemSymbol)
              .lineLimit(1)
              .badge(inboxStore.sidebarConversationCount(for: scope))
            .tag(WorkspaceRoute.inbox(scope))
          }
        }

        Section("Workspace") {
          Label("Statistics", systemSymbol: .chartBar)
            .tag(WorkspaceRoute.statistics)
          Label("Contacts", systemSymbol: .person2)
            .tag(WorkspaceRoute.contacts)
          Label("Knowledge", systemSymbol: .booksVertical)
            .tag(WorkspaceRoute.knowledge)
          Label("FAQ", systemSymbol: .questionmarkBubble)
            .tag(WorkspaceRoute.faq)
          Label("Settings", systemSymbol: .gearshape)
            .tag(WorkspaceRoute.settings)
        }

        Section("AI Tools") {
          Label("AI Agents", systemSymbol: .sparkles)
            .tag(WorkspaceRoute.aiAgents)
          Label("Summarize", systemSymbol: .chartXyaxisLine)
            .tag(WorkspaceRoute.aiSummarize)
          Label("Auto-Resolve", systemSymbol: .sparkles)
            .tag(WorkspaceRoute.aiAutoResolve)
          Label("FAQ Resolver", systemSymbol: .questionmarkBubble)
            .tag(WorkspaceRoute.aiFAQResolver)
        }
      }
      .listStyle(.sidebar)

      WorkspaceSidebarFooter(
        errorMessage: model.errorMessage,
        realtimeConnectionState: model.realtimeConnectionState,
        onRefresh: onRefresh,
        onDismissError: model.clearErrorMessage
      )
    }
    .navigationTitle("Cossistant")
  }
}

private struct WorkspaceSidebarFooter: View {
  let errorMessage: String?
  let realtimeConnectionState: DashboardRealtimeConnectionState
  let onRefresh: () -> Void
  let onDismissError: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: compactMessage == nil ? 0 : 6) {
      Divider()

      HStack(spacing: 10) {
        Label(title, systemSymbol: symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(tint)
          .lineLimit(1)

        Spacer(minLength: 8)

        Button {
          onRefresh()
        } label: {
          Image(systemSymbol: .arrowClockwise)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help("Refresh")

        if errorMessage != nil {
          Button {
            onDismissError()
          } label: {
            Image(systemSymbol: .xmark)
          }
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
          .help("Dismiss error")
        }
      }

      if let compactMessage {
        Text(compactMessage)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(.bar)
    .controlSize(.small)
  }

  private var title: String {
    if errorMessage != nil {
      return "Workspace Issue"
    }

    switch realtimeConnectionState {
    case .connected:
      return "Realtime Active"
    case .connecting:
      return "Connecting"
    case .disconnected:
      return "Using Polling"
    case .failed:
      return "Realtime Unavailable"
    }
  }

  private var compactMessage: String? {
    if let errorMessage, !errorMessage.isEmpty {
      return errorMessage
    }

    switch realtimeConnectionState {
    case .connected:
      return nil
    case .connecting:
      return nil
    case .disconnected:
      return nil
    case .failed(let message):
      return message
    }
  }

  private var symbol: SFSymbol {
    if errorMessage != nil {
      return .xmarkOctagon
    }

    switch realtimeConnectionState {
    case .connected:
      return .boltHorizontalCircleFill
    case .connecting:
      return .boltHorizontalCircle
    case .disconnected:
      return .clockArrowTriangleheadCounterclockwiseRotate90
    case .failed:
      return .exclamationmarkTriangle
    }
  }

  private var tint: Color {
    if errorMessage != nil {
      return .red
    }

    switch realtimeConnectionState {
    case .connected:
      return .green
    case .connecting:
      return .blue
    case .disconnected:
      return .secondary
    case .failed:
      return .orange
    }
  }
}
