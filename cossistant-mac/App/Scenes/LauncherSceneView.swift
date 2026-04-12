import SwiftUI

struct LauncherSceneView: View {
  @State private var store = LauncherStore()

  var body: some View {
    LauncherView(store: store)
      .toolbar(removing: .title)
      .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
  }
}
