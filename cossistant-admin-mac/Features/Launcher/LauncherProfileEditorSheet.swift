import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct LauncherProfileEditorSheet: View {
  @Bindable var store: LauncherStore
  @Binding var isPresented: Bool
  let onSaved: (DashboardProfile.ID) -> Void
  @State private var showsPrivateAPIKey = false

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text(store.draftTitle)
            .font(.title2.weight(.semibold))

          Text(store.draftProfileID == nil ? "Create a saved workspace profile." : "Update this saved workspace profile.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button("Cancel") {
          isPresented = false
        }
      }

      VStack(alignment: .leading, spacing: 14) {
        TextField("Profile name", text: $store.draftProfileName)
          .textFieldStyle(.roundedBorder)

        TextField("https://api.cossistant.com/v1", text: $store.configuration.apiBaseURLString)
          .textFieldStyle(.roundedBorder)

        ProfileAPIKeyField(
          placeholder: "sk_live_...",
          text: $store.configuration.privateAPIKey,
          isVisible: $showsPrivateAPIKey
        )
      }

      if let errorMessage = store.errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }

      HStack {
        Spacer()

        Button {
          store.beginCreatingProfile()
        } label: {
          Text("Reset")
        }
        .disabled(store.draftProfileID == nil && store.draftProfileName.isEmpty && store.configuration == .production)

        Button {
          store.saveDraftProfile()

          guard store.errorMessage == nil,
                let profileID = store.draftProfileID else {
            return
          }

          onSaved(profileID)
          isPresented = false
        } label: {
          Text(store.draftProfileID == nil ? "Save Profile" : "Update Profile")
        }
        .buttonStyle(.borderedProminent)
        .disabled(!store.canSaveDraft)
      }
    }
    .padding(24)
    .frame(minWidth: 460, idealWidth: 520)
    .background(.regularMaterial)
  }
}

private struct ProfileAPIKeyField: View {
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
