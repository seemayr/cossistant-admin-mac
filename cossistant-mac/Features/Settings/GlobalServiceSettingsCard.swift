import SwiftUI

struct GlobalServiceSettingsCard: View {
  @Bindable var store: SettingsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Services")
            .font(.headline)

          Text("Shared across all workspaces.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button("Save") {
          store.save()
        }
        .buttonStyle(.borderedProminent)
      }

      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Google Cloud Translate")
            .font(.subheadline.weight(.semibold))

          SecureField("AIza...", text: $store.globalSettings.googleCloudTranslateAPIKey)
            .textFieldStyle(.roundedBorder)
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("OpenAI")
            .font(.subheadline.weight(.semibold))

          SecureField("sk-...", text: $store.globalSettings.openAIAPIKey)
            .textFieldStyle(.roundedBorder)
        }

        Toggle(
          isOn: Binding(
            get: { store.globalSettings.autoMarkSeenOnOpen },
            set: { store.setAutoMarkSeenOnOpen($0) }
          )
        ) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Auto mark read on open")
              .font(.subheadline.weight(.semibold))

            Text("When enabled, opening an unread conversation marks it as read for the current teammate.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .toggleStyle(.switch)
      }

      if let status = store.statusMessage {
        Text(status)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let errorMessage = store.errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
    .padding(22)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .strokeBorder(.quaternary, lineWidth: 1)
    }
  }
}
