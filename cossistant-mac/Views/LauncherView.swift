import SwiftUI
import SFSafeSymbols

struct LauncherView: View {
  @Bindable var model: AppModel
  @Environment(\.openWindow) private var openWindow
  @State private var selectedProfileID: DashboardProfile.ID?
  @State private var isPresentingProfileEditor = false

  private var selectedProfile: DashboardProfile? {
    guard let selectedProfileID else { return nil }
    return model.profiles.first { $0.id == selectedProfileID }
  }

  var body: some View {
    NavigationSplitView {
      sidebar
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 340)
    } detail: {
      detail
    }
    .navigationSplitViewStyle(.balanced)
    .sheet(isPresented: $isPresentingProfileEditor) {
      LauncherProfileEditorSheet(
        model: model,
        isPresented: $isPresentingProfileEditor,
        onSaved: { profileID in
          selectedProfileID = profileID
        }
      )
    }
    .task {
      syncSelection(with: model.profiles)
    }
    .onChange(of: model.profiles) { _, profiles in
      syncSelection(with: profiles)
    }
    .toolbar {
      ToolbarItemGroup {
        SettingsLink {
          Label("Settings", systemSymbol: .gearshape)
        }

        Button {
          presentNewProfileEditor()
        } label: {
          Label("New Profile", systemSymbol: .plus)
        }
      }
    }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      LauncherSidebarHeader(profileCount: model.profiles.count)
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)

      if model.profiles.isEmpty {
        LauncherSidebarEmptyState {
          presentNewProfileEditor()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(selection: $selectedProfileID) {
          ForEach(model.profiles) { profile in
            LauncherSidebarRow(profile: profile)
              .tag(profile.id)
              .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
              .listRowSeparator(.hidden)
              .listRowBackground(Color.clear)
              .onTapGesture(count: 2) {
                openProfile(profile)
              }
              .contextMenu {
                Button {
                  openProfile(profile)
                } label: {
                  Label("Open Workspace", systemSymbol: .arrowUpForwardApp)
                }

                Button {
                  presentEditor(for: profile)
                } label: {
                  Label("Edit Profile", systemSymbol: .sliderHorizontal3)
                }

                Divider()

                Button(role: .destructive) {
                  model.deleteProfile(profile)
                } label: {
                  Label("Delete Profile", systemSymbol: .trash)
                }
              }
          }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder
  private var detail: some View {
    if let selectedProfile {
      LauncherProfileDetail(
        profile: selectedProfile,
        onOpen: {
          openProfile(selectedProfile)
        },
        onEdit: {
          presentEditor(for: selectedProfile)
        },
        onDelete: {
          model.deleteProfile(selectedProfile)
        }
      )
    } else if model.profiles.isEmpty {
      LauncherWelcomeState {
        presentNewProfileEditor()
      }
    } else {
      LauncherSelectionState()
    }
  }

  private func presentNewProfileEditor() {
    model.beginCreatingProfile()
    isPresentingProfileEditor = true
  }

  private func presentEditor(for profile: DashboardProfile) {
    model.editProfile(profile)
    isPresentingProfileEditor = true
  }

  private func openProfile(_ profile: DashboardProfile) {
    selectedProfileID = profile.id
    openWindow(value: profile.id)
  }

  private func syncSelection(with profiles: [DashboardProfile]) {
    guard !profiles.isEmpty else {
      selectedProfileID = nil
      return
    }

    if let selectedProfileID,
       profiles.contains(where: { $0.id == selectedProfileID }) {
      return
    }

    selectedProfileID = profiles.first?.id
  }
}

private struct LauncherSidebarHeader: View {
  let profileCount: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Cossistant")
        .font(.title2.weight(.semibold))

      Text(profileCount == 1 ? "1 profile" : "\(profileCount) profiles")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

private struct LauncherSidebarEmptyState: View {
  let onCreateProfile: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("No Profiles", systemSymbol: .personCropRectangleStack)
    } description: {
      Text("Create a profile to open a workspace.")
    } actions: {
      Button {
        onCreateProfile()
      } label: {
        Label("New Profile", systemSymbol: .plus)
      }
      .buttonStyle(.borderedProminent)
    }
  }
}

private struct LauncherSidebarRow: View {
  let profile: DashboardProfile

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(profile.name)
        .font(.headline.weight(.medium))
        .lineLimit(1)

      Text(profile.hostLabel)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(.rect(cornerRadius: 10))
  }
}

private struct LauncherProfileDetail: View {
  let profile: DashboardProfile
  let onOpen: () -> Void
  let onEdit: () -> Void
  let onDelete: () -> Void

  var body: some View {
    VStack(alignment: .center, spacing: 26) {
      Spacer(minLength: 56)

      ZStack {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
          .fill(.ultraThinMaterial)
          .frame(width: 104, height: 104)

        Image(systemSymbol: .bubbleLeftAndBubbleRightFill)
          .font(.system(size: 38, weight: .semibold))
          .foregroundStyle(.blue)
      }

      VStack(spacing: 6) {
        Text(profile.name)
          .font(.system(size: 34, weight: .semibold, design: .rounded))
          .multilineTextAlignment(.center)

        Text(profile.hostLabel)
          .font(.title3)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 12) {
        Button {
          onOpen()
        } label: {
          Label("Open Workspace", systemSymbol: .arrowUpForwardApp)
            .frame(minWidth: 170)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .buttonBorderShape(.capsule)

        Menu {
          Button {
            onEdit()
          } label: {
            Label("Edit Profile", systemSymbol: .sliderHorizontal3)
          }

          Divider()

          Button(role: .destructive) {
            onDelete()
          } label: {
            Label("Delete Profile", systemSymbol: .trash)
          }
        } label: {
          Image(systemSymbol: .ellipsisCircleFill)
            .font(.title2)
        }
        .menuStyle(.borderlessButton)
        .controlSize(.large)
      }

      Spacer()
    }
    .padding(.horizontal, 34)
    .padding(.bottom, 34)
  }
}

private struct LauncherWelcomeState: View {
  let onCreateProfile: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("No Workspace Profiles", systemSymbol: .bubbleLeftAndBubbleRight)
    } description: {
      Text("Create a profile to start opening workspaces.")
    } actions: {
      Button {
        onCreateProfile()
      } label: {
        Label("New Profile", systemSymbol: .plus)
      }
      .buttonStyle(.borderedProminent)
    }
  }
}

private struct LauncherSelectionState: View {
  var body: some View {
    ContentUnavailableView {
      Label("Select a Profile", systemSymbol: .bubbleLeftAndBubbleRight)
    } description: {
      Text("Choose a saved profile to open its workspace.")
    }
  }
}

private struct LauncherProfileEditorSheet: View {
  @Bindable var model: AppModel
  @Binding var isPresented: Bool
  let onSaved: (DashboardProfile.ID) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text(model.draftTitle)
            .font(.title2.weight(.semibold))

          Text(model.draftProfileID == nil ? "Create a saved workspace profile." : "Update this saved workspace profile.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button("Cancel") {
          isPresented = false
        }
      }

      VStack(alignment: .leading, spacing: 14) {
        TextField("Profile name", text: $model.draftProfileName)
          .textFieldStyle(.roundedBorder)

        TextField("https://api.cossistant.com/v1", text: $model.configuration.apiBaseURLString)
          .textFieldStyle(.roundedBorder)

        SecureField("sk_live_...", text: $model.configuration.privateAPIKey)
          .textFieldStyle(.roundedBorder)
      }

      if let errorMessage = model.errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }

      HStack {
        Spacer()

        Button {
          model.beginCreatingProfile()
        } label: {
          Text("Reset")
        }
        .disabled(model.draftProfileID == nil && model.draftProfileName.isEmpty && model.configuration == .production)

        Button {
          Task {
            await model.saveDraftProfile()

            guard model.errorMessage == nil,
                  let profileID = model.draftProfileID else {
              return
            }

            onSaved(profileID)
            isPresented = false
          }
        } label: {
          Text(model.draftProfileID == nil ? "Save Profile" : "Update Profile")
        }
        .buttonStyle(.borderedProminent)
        .disabled(!model.canSaveDraft || model.isConnecting)
      }
    }
    .padding(24)
    .frame(minWidth: 460, idealWidth: 520)
    .background(.regularMaterial)
  }
}

struct GlobalServiceSettingsCard: View {
  @Bindable var model: AppModel

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
          model.saveGlobalSettings()
        }
        .buttonStyle(.borderedProminent)
      }

      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Google Cloud Translate")
            .font(.subheadline.weight(.semibold))

          SecureField("AIza...", text: $model.globalSettings.googleCloudTranslateAPIKey)
            .textFieldStyle(.roundedBorder)
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("OpenAI")
            .font(.subheadline.weight(.semibold))

          SecureField("sk-...", text: $model.globalSettings.openAIAPIKey)
            .textFieldStyle(.roundedBorder)
        }

        Toggle(
          isOn: Binding(
            get: { model.globalSettings.autoMarkSeenOnOpen },
            set: { model.setAutoMarkSeenOnOpen($0) }
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

      if let status = model.globalSettingsStatusMessage {
        Text(status)
          .font(.caption)
          .foregroundStyle(.secondary)
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
