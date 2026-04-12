import Foundation
import Observation

@Observable @MainActor
final class LauncherStore {
  let configurationStore: AppConfigurationStore

  var profiles: [DashboardProfile]
  var draftProfileID: DashboardProfile.ID?
  var draftProfileName = ""
  var configuration = DashboardConfiguration.production
  var errorMessage: String?

  init(configurationStore: AppConfigurationStore? = nil) {
    let resolvedConfigurationStore = configurationStore ?? AppConfigurationStore()
    self.configurationStore = resolvedConfigurationStore
    self.profiles = (try? resolvedConfigurationStore.loadProfiles()) ?? []
    beginCreatingProfile()
  }

  var draftTitle: String {
    draftProfileID == nil ? "New Profile" : "Edit Profile"
  }

  var canSaveDraft: Bool {
    !draftProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && configuration.apiBaseURL != nil
      && !configuration.trimmedPrivateAPIKey.isEmpty
  }

  func reloadProfiles() {
    profiles = (try? configurationStore.loadProfiles()) ?? []
  }

  func beginCreatingProfile() {
    draftProfileID = nil
    draftProfileName = ""
    configuration = .production
    errorMessage = nil
  }

  func editProfile(_ profile: DashboardProfile) {
    draftProfileID = profile.id
    draftProfileName = profile.name
    errorMessage = nil

    if let savedConfiguration = try? configurationStore.loadConfiguration(profileID: profile.id) {
      configuration = savedConfiguration
    } else {
      configuration = DashboardConfiguration(
        apiBaseURLString: profile.apiBaseURLString,
        privateAPIKey: ""
      )
    }
  }

  func saveDraftProfile() {
    errorMessage = nil

    let name = draftProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
    let profileID = draftProfileID ?? UUID().uuidString
    let profile = DashboardProfile(
      id: profileID,
      name: name,
      apiBaseURLString: configuration.trimmedAPIBaseURLString
    )

    do {
      try configurationStore.save(profile: profile, privateAPIKey: configuration.trimmedPrivateAPIKey)
      reloadProfiles()
      draftProfileID = profileID
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func deleteProfile(_ profile: DashboardProfile) {
    do {
      try configurationStore.deleteProfile(id: profile.id)
      reloadProfiles()

      if draftProfileID == profile.id {
        beginCreatingProfile()
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
