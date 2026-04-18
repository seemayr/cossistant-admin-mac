import SwiftUI
import CossistantAdmin

struct GlobalServiceSettingsCard: View {
  @Bindable var store: SettingsStore

  var body: some View {
    Group {
      Section {
        LabeledContent("Google Cloud Translate") {
          SecureField("AIza...", text: $store.globalSettings.googleCloudTranslateAPIKey)
            .textFieldStyle(.roundedBorder)
        }

        LabeledContent("OpenAI") {
          SecureField("sk-...", text: $store.globalSettings.openAIAPIKey)
            .textFieldStyle(.roundedBorder)
        }
      } header: {
        Text("API Keys")
      } footer: {
        Text("These keys are shared across all workspaces on this Mac.")
      }

      Section {
        Toggle(
          isOn: Binding(
            get: { store.globalSettings.autoMarkSeenOnOpen },
            set: { store.setAutoMarkSeenOnOpen($0) }
          )
        ) {
          Text("Auto mark read on open")
        }
        .toggleStyle(.switch)
      } header: {
        Text("Workspace Behavior")
      } footer: {
        Text("Opening an unread conversation marks it as read for the current teammate.")
      }

      if let status = store.statusMessage {
        Section {
          Text(status)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      if let errorMessage = store.errorMessage {
        Section {
          Text(errorMessage)
            .font(.caption)
            .foregroundStyle(.red)
        }
      }
    }
  }
}
