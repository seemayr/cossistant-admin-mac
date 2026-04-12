import Foundation

@MainActor
extension WorkspaceModel {
  func startAutoResolve() {
    makeAutoResolveCoordinator().start()
  }

  func cancelAutoResolve() {
    makeAutoResolveCoordinator().cancel()
  }

  func clearAutoResolveResults() {
    makeAutoResolveCoordinator().clearResults()
  }

  func runInboxAutoResolve(in scope: InboxScope) async {
    await makeAutoResolveCoordinator().run(in: scope)
  }
}
