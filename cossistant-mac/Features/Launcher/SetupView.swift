import SwiftUI
import SFSafeSymbols

struct SetupView: View {
  @Bindable var store: LauncherStore
  let title: String

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      header

      HStack(alignment: .top, spacing: 24) {
        profilesPanel
          .frame(minWidth: 340, maxWidth: 380)

        editorPanel
      }

      if let errorMessage = store.errorMessage {
        ContentUnavailableView {
          Label("Action Failed", systemSymbol: .exclamationmarkTriangle)
        } description: {
          Text(errorMessage)
        }
      }
    }
    .padding(28)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(.background)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.largeTitle.weight(.semibold))

      Text("Choose a saved profile to open its dashboard, or create another private-key profile for a separate Cossistant account or environment.")
        .font(.title3)
        .foregroundStyle(.secondary)
    }
  }

  private var profilesPanel: some View {
    GroupBox("Profiles") {
      VStack(alignment: .leading, spacing: 16) {
        if store.profiles.isEmpty {
          ContentUnavailableView(
            "No profiles yet",
            systemImage: SFSymbol.personCropRectangleStack.rawValue,
            description: Text("Create your first private-key profile to start loading inbox conversations.")
          )
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 12) {
              ForEach(store.profiles) { profile in
                ProfileRowView(
                  profile: profile,
                  isActive: false,
                  isConnecting: false
                ) {
                  store.editProfile(profile)
                } onEdit: {
                  store.editProfile(profile)
                } onDelete: {
                  store.deleteProfile(profile)
                }
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }

        Button {
          store.beginCreatingProfile()
        } label: {
          Label("New Profile", systemSymbol: .plus)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 4)
    }
  }

  private var editorPanel: some View {
    GroupBox(store.draftTitle) {
      VStack(alignment: .leading, spacing: 18) {
        TextField("Profile name", text: $store.draftProfileName)
          .textFieldStyle(.roundedBorder)

        TextField("https://api.cossistant.com/v1", text: $store.configuration.apiBaseURLString)
          .textFieldStyle(.roundedBorder)

        SecureField("sk_live_...", text: $store.configuration.privateAPIKey)
          .textFieldStyle(.roundedBorder)

        Text("Expected auth header: `Authorization: Bearer sk_[live|test]_...`")
          .font(.caption)
          .foregroundStyle(.secondary)

        GroupBox("Baseline Scope") {
          VStack(alignment: .leading, spacing: 8) {
            Label("Fetch website context from `/v1/websites`", systemSymbol: .globe)
            Label("Resolve organization info from `/v1/organizations/{id}`", systemSymbol: .building2)
            Label("Load inbox conversations from `/v1/conversations/inbox`", systemSymbol: .bubbleLeftAndBubbleRight)
          }
          .font(.subheadline)
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        HStack {
          Button("Reset") {
            store.beginCreatingProfile()
          }

          Spacer()

          Button {
            store.saveDraftProfile()
          } label: {
            Text(store.draftProfileID == nil ? "Save Profile" : "Update Profile")
          }
          .buttonStyle(.borderedProminent)
          .disabled(!store.canSaveDraft)
        }
      }
      .padding(.top, 4)
    }
  }
}

private struct ProfileRowView: View {
  let profile: DashboardProfile
  let isActive: Bool
  let isConnecting: Bool
  let onOpen: () -> Void
  let onEdit: () -> Void
  let onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(profile.name)
          .font(.headline)

        Spacer()

        if isActive {
          Text("Active")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.green, in: .capsule)
        }
      }

      Text(profile.hostLabel)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      HStack {
        Button("Open", action: onOpen)
          .buttonStyle(.borderedProminent)
          .disabled(isConnecting)

        Button("Edit", action: onEdit)
          .buttonStyle(.bordered)

        Button("Delete", role: .destructive, action: onDelete)
          .buttonStyle(.bordered)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 14))
  }
}
