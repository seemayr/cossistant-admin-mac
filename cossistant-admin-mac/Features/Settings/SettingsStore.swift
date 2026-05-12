import Foundation
import Observation
import CossistantAdmin

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
      statusMessage = "Saved API keys."
      errorMessage = nil
    } catch {
      statusMessage = nil
      errorMessage = error.localizedDescription
    }
  }
}
