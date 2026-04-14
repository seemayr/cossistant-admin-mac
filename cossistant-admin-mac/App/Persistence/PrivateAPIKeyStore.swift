import Foundation
import Security
import CossistantAdmin

struct PrivateAPIKeyStore {
  private let service = "earth.mizo.cossistant-admin-mac.private-api-key"

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
