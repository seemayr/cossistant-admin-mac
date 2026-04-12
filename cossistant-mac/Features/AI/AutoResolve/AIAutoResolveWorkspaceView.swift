import SwiftUI
import SFSafeSymbols

struct AIAutoResolveWorkspaceView: View {
  @Bindable var store: AutoResolveStore
  let canStart: Bool
  let onStart: () -> Void
  let onCancel: () -> Void
  let onClearResults: () -> Void
  let onOpenConversation: (String) -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Auto-Resolve")
          .font(.largeTitle.weight(.semibold))

        Text("Review recent conversations one by one with AI, automatically resolve safe cases, and inspect a running decision list as results come in.")
          .font(.title3)
          .foregroundStyle(.secondary)

        autoResolveControlsCard

        if let status = store.statusMessage {
          Label(
            status,
            systemSymbol: store.isRunning ? .clockArrowTriangleheadCounterclockwiseRotate90 : .sparkles
          )
          .font(.subheadline)
          .foregroundStyle(.secondary)
        }

        autoResolveResultsCard
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
      .textSelection(.enabled)
    }
  }

  private var autoResolveControlsCard: some View {
    PrototypeInfoCard(title: "Workflow") {
      Picker("Source Queue", selection: $store.sourceScope) {
        ForEach(AutoResolveSourceScope.allCases) { scope in
          Text(scope.label)
            .tag(scope)
        }
      }
      .pickerStyle(.segmented)
      .disabled(store.isRunning)

      Text("Conversations are reviewed conservatively. Empty conversations resolve immediately. Feedback and idea-only threads also resolve, while anything waiting on a person stays open.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if !store.hasOpenAIAPIKey {
        Label("Add an OpenAI API key in Settings to enable auto-resolve.", systemSymbol: .keyFill)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      HStack {
        if store.isRunning {
          Button("Cancel") {
            onCancel()
          }
        } else {
          Button("Start Auto-Resolve") {
            onStart()
          }
          .disabled(!canStart)
        }

        Button("Clear Results") {
          onClearResults()
        }
        .disabled(!store.canClearResults)

        Spacer()

        Text("\(store.results.count) reviewed")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var autoResolveResultsCard: some View {
    PrototypeInfoCard(title: "Review Results") {
      if store.results.isEmpty {
        ContentUnavailableView(
          "No review results yet",
          systemImage: SFSymbol.sparkles.rawValue,
          description: Text("Start the workflow to build a per-conversation list of AI resolve decisions.")
        )
      } else {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(store.results) { result in
            Button {
              onOpenConversation(result.conversationID)
            } label: {
              AutoResolveResultRow(result: result)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }
}

private struct AutoResolveResultRow: View {
  let result: AutoResolveResult

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(result.outcome.label)
          .font(.caption.weight(.semibold))
          .foregroundStyle(outcomeColor)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(outcomeColor.opacity(0.12), in: .capsule)

        Text(result.title)
          .font(.headline)
          .foregroundStyle(.primary)
          .multilineTextAlignment(.leading)

        Spacer(minLength: 0)
      }

      HStack(spacing: 8) {
        Text(result.category.label)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.secondary.opacity(0.12), in: .capsule)

        Spacer(minLength: 0)
      }

      if let body = result.body, !body.isEmpty {
        Text(body)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.leading)
      }

      HStack(spacing: 8) {
        Label(result.visitorID, systemSymbol: .personTextRectangle)
          .font(.caption)
          .foregroundStyle(.tertiary)

        Spacer(minLength: 0)

        Text(result.createdAt.formatted(.dateTime.hour().minute()))
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(.quinary, in: .rect(cornerRadius: 16))
  }

  private var outcomeColor: Color {
    switch result.outcome {
    case .emptyResolved:
      return .secondary
    case .resolved:
      return .green
    case .notResolved:
      return .orange
    }
  }
}
