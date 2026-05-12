import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct GlobalServiceSettingsCard: View {
  @Bindable var store: SettingsStore
  @State private var showsGoogleCloudTranslateAPIKey = false
  @State private var showsOpenAIAPIKey = false

  var body: some View {
    Group {
      Section {
        LabeledContent("Google Cloud Translate") {
          APIKeyField(
            placeholder: "AIza...",
            text: $store.globalSettings.googleCloudTranslateAPIKey,
            isVisible: $showsGoogleCloudTranslateAPIKey
          )
        }

        LabeledContent("OpenAI") {
          APIKeyField(
            placeholder: "sk-...",
            text: $store.globalSettings.openAIAPIKey,
            isVisible: $showsOpenAIAPIKey
          )
        }
      } header: {
        Text("API Keys")
      } footer: {
        Text("These keys are shared across all workspaces on this Mac.")
      }

      Section {
        Button("Save API Keys") {
          store.save()
        }
        .keyboardShortcut(.defaultAction)
      }

      if let status = store.statusMessage {
        Section {
          Label(status, systemSymbol: .checkmarkCircle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      if let errorMessage = store.errorMessage {
        Section {
          Label(errorMessage, systemSymbol: .exclamationmarkTriangleFill)
            .font(.caption)
            .foregroundStyle(.red)
        }
      }
    }
  }
}

private struct APIKeyField: View {
  let placeholder: String
  @Binding var text: String
  @Binding var isVisible: Bool

  var body: some View {
    HStack(spacing: 8) {
      Group {
        if isVisible {
          TextField(placeholder, text: $text)
        } else {
          SecureField(placeholder, text: $text)
        }
      }
      .textFieldStyle(.roundedBorder)
      .frame(minWidth: 280)

      Button {
        isVisible.toggle()
      } label: {
        Image(systemSymbol: isVisible ? .eyeSlash : .eye)
      }
      .buttonStyle(.borderless)
      .help(isVisible ? "Hide key" : "Show key")
      .accessibilityLabel(isVisible ? "Hide key" : "Show key")
    }
  }
}
