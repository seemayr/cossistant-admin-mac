import SwiftUI
import SFSafeSymbols

struct WorkspaceLoadingView: View {
  let profileName: String?
  let isConnecting: Bool
  let errorMessage: String?
  let onOpenLauncher: () -> Void

  var body: some View {
    VStack(spacing: 18) {
      if let errorMessage {
        ContentUnavailableView {
          Label("Workspace Unavailable", systemSymbol: .exclamationmarkTriangle)
        } description: {
          Text(errorMessage)
        } actions: {
          Button("Open Launcher", action: onOpenLauncher)
            .buttonStyle(.borderedProminent)
        }
      } else {
        ProgressView()
          .controlSize(.large)

        Text(isConnecting ? "Opening \(profileName ?? "workspace")…" : "Preparing workspace…")
          .font(.title3)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.regularMaterial)
  }
}
