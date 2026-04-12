import SwiftUI
import SFSafeSymbols

@main
struct CossistantMacApp: App {
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
