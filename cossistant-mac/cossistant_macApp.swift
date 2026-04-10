//
//  cossistant_macApp.swift
//  cossistant-mac
//
//  Created by Dominik Seemayr on 09.04.26.
//

import SwiftUI
import SFSafeSymbols

@main
struct cossistant_macApp: App {
  var body: some Scene {
    WindowGroup(id: "launcher") {
      LauncherSceneView()
        .frame(minWidth: 860, minHeight: 580)
        .containerBackground(.thinMaterial, for: .window)
    }
    .defaultSize(width: 980, height: 640)

    WindowGroup(for: String.self) { profileID in
      if let profileID = profileID.wrappedValue {
        WorkspaceSceneView(profileID: profileID)
          .frame(minWidth: 980, minHeight: 760)
      } else {
        ContentUnavailableView(
          "No profile selected",
          systemImage: SFSymbol.personCropRectangleStack.rawValue,
          description: Text("Open a saved profile from the launcher window.")
        )
      }
    }
    .defaultSize(width: 1420, height: 900)

    Settings {
      GlobalSettingsSceneView()
        .frame(minWidth: 720, minHeight: 320)
    }
  }
}

private struct LauncherSceneView: View {
  @State private var model = AppModel(restoreLastUsedSession: false)

  var body: some View {
    LauncherView(model: model)
      .toolbar(removing: .title)
      .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
  }
}

private struct WorkspaceSceneView: View {
  let profileID: String
  @State private var model: AppModel

  init(profileID: String) {
    self.profileID = profileID
    _model = State(
      initialValue: AppModel(
        initialProfileID: profileID,
        restoreLastUsedSession: false
      )
    )
  }

  var body: some View {
    ContentView(model: model)
      .toolbar(removing: .title)
  }
}

private struct GlobalSettingsSceneView: View {
  @State private var model = AppModel(restoreLastUsedSession: false)

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Settings")
          .font(.title2.weight(.semibold))

        GlobalServiceSettingsCard(model: model)
      }
      .padding(24)
    }
    .task {
      model.reloadGlobalSettings()
    }
  }
}
