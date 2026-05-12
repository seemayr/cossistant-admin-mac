import Foundation
import Security
import CossistantAdmin

enum ConfigurationStoreError: LocalizedError {
  case invalidBaseURL
  case invalidKeychainValue
  case keychainFailure(OSStatus)

  var errorDescription: String? {
    switch self {
    case .invalidBaseURL:
      "Enter a valid API base URL."
    case .invalidKeychainValue:
      "The saved API key could not be read from the keychain."
    case .keychainFailure(let status):
      "Keychain operation failed with status \(status)."
    }
  }
}

final class AppConfigurationStore {
  private enum Constants {
    static let profilesKey = "dashboard.profiles"
    static let lastUsedProfileIDKey = "dashboard.last-used-profile-id"
    static let autoMarkSeenOnOpenKey = "dashboard.auto-mark-seen-on-open"
    static let showBackendTranslatedSubjectsKey = "dashboard.show-backend-translated-subjects"
    static let showBackendTranslatedMessagesKey = "dashboard.show-backend-translated-messages"
    static let workspaceSettingsKeyPrefix = "dashboard.workspace-settings"
    static let googleCloudTranslateAPIKeyAccount = "global.google-cloud-translate"
    static let openAIAPIKeyAccount = "global.openai"
  }

  private let defaults: UserDefaults
  private let keyStore: PrivateAPIKeyStore
  private let globalSecretStore: GlobalSecretStore

  init(
    defaults: UserDefaults = .standard,
    keyStore: PrivateAPIKeyStore = PrivateAPIKeyStore(),
    globalSecretStore: GlobalSecretStore = GlobalSecretStore()
  ) {
    self.defaults = defaults
    self.keyStore = keyStore
    self.globalSecretStore = globalSecretStore
  }

  func loadProfiles() throws -> [DashboardProfile] {
    guard let data = defaults.data(forKey: Constants.profilesKey) else {
      return []
    }

    return try JSONDecoder().decode([DashboardProfile].self, from: data)
  }

  func loadConfiguration(profileID: String) throws -> DashboardConfiguration? {
    guard let profile = try loadProfiles().first(where: { $0.id == profileID }),
          let privateAPIKey = try keyStore.load(account: profileID) else {
      return nil
    }

    return DashboardConfiguration(
      apiBaseURLString: profile.apiBaseURLString,
      privateAPIKey: privateAPIKey
    )
  }

  func save(profile: DashboardProfile, privateAPIKey: String) throws {
    let configuration = DashboardConfiguration(
      apiBaseURLString: profile.apiBaseURLString,
      privateAPIKey: privateAPIKey
    )

    guard configuration.apiBaseURL != nil else {
      throw ConfigurationStoreError.invalidBaseURL
    }

    var profiles = try loadProfiles().filter { $0.id != profile.id }
    profiles.append(
      DashboardProfile(
        id: profile.id,
        name: profile.trimmedName,
        apiBaseURLString: configuration.trimmedAPIBaseURLString
      )
    )
    profiles.sort { $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending }

    let data = try JSONEncoder().encode(profiles)
    defaults.set(data, forKey: Constants.profilesKey)
    try keyStore.save(configuration.trimmedPrivateAPIKey, account: profile.id)
  }

  func deleteProfile(id: String) throws {
    let profiles = try loadProfiles().filter { $0.id != id }
    let data = try JSONEncoder().encode(profiles)
    defaults.set(data, forKey: Constants.profilesKey)
    try keyStore.delete(account: id)

    if defaults.string(forKey: Constants.lastUsedProfileIDKey) == id {
      defaults.removeObject(forKey: Constants.lastUsedProfileIDKey)
    }

    defaults.removeObject(forKey: workspaceSettingsKey(profileID: id))
  }

  func lastUsedProfileID() -> String? {
    defaults.string(forKey: Constants.lastUsedProfileIDKey)
  }

  func setLastUsedProfileID(_ profileID: String?) {
    if let profileID {
      defaults.set(profileID, forKey: Constants.lastUsedProfileIDKey)
    } else {
      defaults.removeObject(forKey: Constants.lastUsedProfileIDKey)
    }
  }

  func loadGlobalSettings() throws -> GlobalServiceSettings {
    GlobalServiceSettings(
      googleCloudTranslateAPIKey: try globalSecretStore.load(
        account: Constants.googleCloudTranslateAPIKeyAccount
      ) ?? "",
      openAIAPIKey: try globalSecretStore.load(
        account: Constants.openAIAPIKeyAccount
      ) ?? ""
    )
  }

  func saveGlobalSettings(_ settings: GlobalServiceSettings) throws {
    try globalSecretStore.saveOrDelete(
      settings.trimmedGoogleCloudTranslateAPIKey,
      account: Constants.googleCloudTranslateAPIKeyAccount
    )
    try globalSecretStore.saveOrDelete(
      settings.trimmedOpenAIAPIKey,
      account: Constants.openAIAPIKeyAccount
    )
    NotificationCenter.default.post(name: .globalServiceSettingsDidChange, object: nil)
  }

  func loadWorkspaceSettings(profileID: DashboardProfile.ID) throws -> WorkspaceSettings {
    if let data = defaults.data(forKey: workspaceSettingsKey(profileID: profileID)) {
      return try JSONDecoder().decode(WorkspaceSettings.self, from: data)
    }

    return WorkspaceSettings(
      channelFilter: nil,
      autoMarkSeenOnOpen: defaults.object(forKey: Constants.autoMarkSeenOnOpenKey) as? Bool ?? false,
      showBackendTranslatedSubjects: defaults.object(forKey: Constants.showBackendTranslatedSubjectsKey) as? Bool ?? true,
      showBackendTranslatedMessages: defaults.object(forKey: Constants.showBackendTranslatedMessagesKey) as? Bool ?? true
    )
  }

  func saveWorkspaceSettings(
    _ settings: WorkspaceSettings,
    profileID: DashboardProfile.ID
  ) throws {
    let data = try JSONEncoder().encode(settings)
    defaults.set(data, forKey: workspaceSettingsKey(profileID: profileID))
    NotificationCenter.default.post(name: .workspaceSettingsDidChange, object: profileID)
  }

  private func workspaceSettingsKey(profileID: DashboardProfile.ID) -> String {
    "\(Constants.workspaceSettingsKeyPrefix).\(profileID)"
  }
}

extension Notification.Name {
  static let globalServiceSettingsDidChange = Notification.Name(
    "earth.mizo.cossistant-admin-mac.global-service-settings-did-change"
  )

  static let workspaceSettingsDidChange = Notification.Name(
    "earth.mizo.cossistant-admin-mac.workspace-settings-did-change"
  )
}

struct GlobalSecretStore {
  private let service = "earth.mizo.cossistant-admin-mac.global-settings"

  func load(account: String) throws -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      guard let data = result as? Data,
            let key = String(data: data, encoding: .utf8) else {
        throw ConfigurationStoreError.invalidKeychainValue
      }
      return key
    case errSecItemNotFound:
      return nil
    default:
      throw ConfigurationStoreError.keychainFailure(status)
    }
  }

  func saveOrDelete(_ value: String, account: String) throws {
    if value.isEmpty {
      try delete(account: account)
    } else {
      try save(value, account: account)
    }
  }

  func save(_ value: String, account: String) throws {
    let encoded = Data(value.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]

    let attributes: [String: Any] = [
      kSecValueData as String: encoded,
    ]

    let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecItemNotFound {
      var item = query
      item[kSecValueData as String] = encoded

      let addStatus = SecItemAdd(item as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        throw ConfigurationStoreError.keychainFailure(addStatus)
      }
      return
    }

    guard updateStatus == errSecSuccess else {
      throw ConfigurationStoreError.keychainFailure(updateStatus)
    }
  }

  func delete(account: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw ConfigurationStoreError.keychainFailure(status)
    }
  }
}
