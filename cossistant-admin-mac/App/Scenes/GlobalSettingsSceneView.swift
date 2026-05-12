import SwiftUI
import CossistantAdmin

struct GlobalSettingsSceneView: View {
  @State private var store = SettingsStore()

  var body: some View {
    ScrollView {
      Form {
        GlobalServiceSettingsCard(store: store)
      }
      .formStyle(.grouped)
      .padding(24)
      .frame(width: 560)
    }
    .navigationTitle("Settings")
    .task {
      store.reload()
    }
  }
}
