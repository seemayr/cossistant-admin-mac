import SwiftUI
import CossistantAdmin

struct GlobalSettingsSceneView: View {
  @State private var store = SettingsStore()

  var body: some View {
    Form {
      GlobalServiceSettingsCard(store: store)
    }
    .formStyle(.grouped)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Save") {
          store.save()
        }
      }
    }
    .task {
      store.reload()
    }
  }
}
