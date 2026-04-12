import SwiftUI

struct GlobalSettingsSceneView: View {
  @State private var store = SettingsStore()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Settings")
          .font(.title2.weight(.semibold))

        GlobalServiceSettingsCard(store: store)
      }
      .padding(24)
    }
    .task {
      store.reload()
    }
  }
}
