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

              Text(model.connectionSummary)
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
          }
        }

        Section("Inboxes") {
          ForEach(InboxScope.allCases) { scope in
            Label {
              HStack {
                Text(scope.title)
                Spacer()
                Text(inboxStore.conversationCount(for: scope, isUnread: model.conversationHasUnreadActivity), format: .number)
                  .foregroundStyle(.secondary)
              }
            } icon: {
              Image(systemSymbol: scope.systemSymbol)
            }
            .tag(WorkspaceRoute.inbox(scope))
          }
        }

        Section("Workspace") {
          Label("Contacts", systemSymbol: .person2)
            .tag(WorkspaceRoute.contacts)
          Label("Knowledge", systemSymbol: .booksVertical)
            .tag(WorkspaceRoute.knowledge)
          Label("FAQ", systemSymbol: .questionmarkBubble)
            .tag(WorkspaceRoute.faq)
        }

        Section("AI Tools") {
          Label("Summarize", systemSymbol: .chartXyaxisLine)
            .tag(WorkspaceRoute.aiSummarize)
          Label("Auto-Resolve", systemSymbol: .sparkles)
            .tag(WorkspaceRoute.aiAutoResolve)
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
    VStack(spacing: 0) {
      Divider()

      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .center, spacing: 10) {
          Image(systemSymbol: symbol)
            .foregroundStyle(tint)

          Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

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

        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(.bar)
    }
  }

  private var title: String {
    if errorMessage != nil {
      return "Workspace Error"
    }

    switch realtimeConnectionState {
    case .connected:
      return "Realtime Connected"
    case .connecting:
      return "Connecting Realtime"
    case .disconnected:
      return "Polling Fallback"
    case .failed:
      return "Realtime Blocked"
    }
  }

  private var message: String {
    if let errorMessage, !errorMessage.isEmpty {
      return errorMessage
    }

    switch realtimeConnectionState {
    case .connected:
      return "Live updates are active for the workspace."
    case .connecting:
      return "The workspace is usable while the realtime connection comes up."
    case .disconnected:
      return "Realtime is unavailable right now, so the app is refreshing with polling."
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
