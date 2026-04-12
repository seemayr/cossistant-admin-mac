import Foundation
import Observation

@Observable @MainActor
final class SettingsStore {
  let configurationStore: AppConfigurationStore

  var globalSettings: GlobalServiceSettings
  var statusMessage: String?
  var errorMessage: String?

  init(configurationStore: AppConfigurationStore? = nil) {
    let resolvedConfigurationStore = configurationStore ?? AppConfigurationStore()
    self.configurationStore = resolvedConfigurationStore
    self.globalSettings = (try? resolvedConfigurationStore.loadGlobalSettings()) ?? .empty
  }

  func reload() {
    globalSettings = (try? configurationStore.loadGlobalSettings()) ?? .empty
    statusMessage = nil
    errorMessage = nil
  }

  func save() {
    do {
      try configurationStore.saveGlobalSettings(globalSettings)
      statusMessage = "Saved global service keys."
      errorMessage = nil
    } catch {
      statusMessage = nil
      errorMessage = error.localizedDescription
    }
  }

  func setAutoMarkSeenOnOpen(_ isEnabled: Bool) {
    globalSettings.autoMarkSeenOnOpen = isEnabled
    configurationStore.saveAutoMarkSeenOnOpen(isEnabled)
    statusMessage = nil
  }
}
