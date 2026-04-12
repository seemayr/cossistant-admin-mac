import SwiftUI

struct WorkspaceSceneView: View {
  let profileID: String
  @State private var model: WorkspaceModel
  @State private var workspaceStore = WorkspaceStore()
  @SceneStorage("showConversationInspector") private var showConversationInspector = false

  init(profileID: String) {
    self.profileID = profileID
    _model = State(
      initialValue: WorkspaceModel(
        initialProfileID: profileID,
        restoreLastUsedSession: false
      )
    )
  }

  var body: some View {
    WorkspaceRootView(
      model: model,
      workspaceStore: workspaceStore,
      showConversationInspector: $showConversationInspector
    )
      .toolbar(removing: .title)
  }
}
