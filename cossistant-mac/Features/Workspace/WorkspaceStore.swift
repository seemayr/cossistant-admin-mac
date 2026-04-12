import Foundation
import Observation

@Observable @MainActor
final class WorkspaceStore {
  var selectedRoute: WorkspaceRoute? = .inbox(.open)
  var selectedContactID: String?
  var selectedKnowledgeID: String?
  var knowledgeEditorDraft: DashboardKnowledgeEditorDraft?
  var autoSeenConversationIDInFlight: String?

  var activeRoute: WorkspaceRoute {
    selectedRoute ?? .inbox(.open)
  }
}
