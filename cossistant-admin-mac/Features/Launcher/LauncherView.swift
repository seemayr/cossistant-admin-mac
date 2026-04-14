import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct LauncherView: View {
  @Bindable var store: LauncherStore
  @Environment(\.openWindow) private var openWindow
  @State private var selectedProfileID: DashboardProfile.ID?
  @State private var isPresentingProfileEditor = false

  private var selectedProfile: DashboardProfile? {
    guard let selectedProfileID else { return nil }
    return store.profiles.first { $0.id == selectedProfileID }
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
        store: store,
        isPresented: $isPresentingProfileEditor,
        onSaved: { profileID in
          selectedProfileID = profileID
        }
      )
    }
    .task {
      syncSelection(with: store.profiles)
    }
    .onChange(of: store.profiles) { _, profiles in
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
      LauncherSidebarHeader(profileCount: store.profiles.count)
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)

      if store.profiles.isEmpty {
        LauncherSidebarEmptyState {
          presentNewProfileEditor()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(selection: $selectedProfileID) {
          ForEach(store.profiles) { profile in
            LauncherSidebarRow(
              profile: profile,
              onOpen: {
                openProfile(profile)
              },
              onEdit: {
                presentEditor(for: profile)
              },
              onDelete: {
                store.deleteProfile(profile)
              }
            )
            .tag(profile.id)
            .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
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
          store.deleteProfile(selectedProfile)
        }
      )
    } else if store.profiles.isEmpty {
      LauncherWelcomeState {
        presentNewProfileEditor()
      }
    } else {
      LauncherSelectionState()
    }
  }

  private func presentNewProfileEditor() {
    store.beginCreatingProfile()
    isPresentingProfileEditor = true
  }

  private func presentEditor(for profile: DashboardProfile) {
    store.editProfile(profile)
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
