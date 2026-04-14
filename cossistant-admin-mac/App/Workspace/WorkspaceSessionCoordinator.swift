import Foundation
import CossistantAdmin

struct WorkspaceConnectionContext {
  let profile: DashboardProfile
  let configuration: DashboardConfiguration
  let bootstrap: WorkspaceBootstrap
}

@MainActor
final class WorkspaceSessionCoordinator {
  let configurationStore: AppConfigurationStore
  let initialProfileID: DashboardProfile.ID?
  let restoreLastUsedSession: Bool

  init(
    configurationStore: AppConfigurationStore,
    initialProfileID: DashboardProfile.ID? = nil,
    restoreLastUsedSession: Bool = true
  ) {
    self.configurationStore = configurationStore
    self.initialProfileID = initialProfileID
    self.restoreLastUsedSession = restoreLastUsedSession
  }

  func loadProfiles() -> [DashboardProfile] {
    (try? configurationStore.loadProfiles()) ?? []
  }

  func loadGlobalSettings() -> GlobalServiceSettings {
    (try? configurationStore.loadGlobalSettings()) ?? .empty
  }

  func saveGlobalSettings(_ settings: GlobalServiceSettings) throws {
    try configurationStore.saveGlobalSettings(settings)
  }

  func saveAutoMarkSeenOnOpen(_ isEnabled: Bool) {
    configurationStore.saveAutoMarkSeenOnOpen(isEnabled)
  }

  func setLastUsedProfileID(_ profileID: DashboardProfile.ID?) {
    configurationStore.setLastUsedProfileID(profileID)
  }

  func restoredProfileID(
    profiles: [DashboardProfile]
  ) -> DashboardProfile.ID? {
    if let initialProfileID,
       profiles.contains(where: { $0.id == initialProfileID }) {
      return initialProfileID
    }

    guard restoreLastUsedSession,
          let profileID = configurationStore.lastUsedProfileID(),
          profiles.contains(where: { $0.id == profileID }) else {
      return nil
    }

    return profileID
  }

  func fetchConnectionContext(
    profileID: DashboardProfile.ID,
    profiles: [DashboardProfile],
    inboxPageSize: Int
  ) async throws -> WorkspaceConnectionContext {
    guard let profile = profiles.first(where: { $0.id == profileID }),
          let savedConfiguration = try configurationStore.loadConfiguration(profileID: profileID) else {
      throw CossistantAPIError.invalidPrivateAPIKey
    }

    let backendClient = CossistantAdminClient(configuration: savedConfiguration)
    let bootstrap = try await backendClient.bootstrap.fetchWorkspace(limit: inboxPageSize)

    return WorkspaceConnectionContext(
      profile: profile,
      configuration: savedConfiguration,
      bootstrap: bootstrap
    )
  }
}
