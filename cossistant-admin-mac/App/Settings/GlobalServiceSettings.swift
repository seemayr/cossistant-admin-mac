import Foundation
import CossistantAdmin

struct GlobalServiceSettings: Equatable, Sendable {
  var googleCloudTranslateAPIKey: String
  var openAIAPIKey: String
  var autoMarkSeenOnOpen: Bool

  static let empty = GlobalServiceSettings(
    googleCloudTranslateAPIKey: "",
    openAIAPIKey: "",
    autoMarkSeenOnOpen: false
  )

  var trimmedGoogleCloudTranslateAPIKey: String {
    googleCloudTranslateAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var trimmedOpenAIAPIKey: String {
    openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var hasGoogleCloudTranslateAPIKey: Bool {
    !trimmedGoogleCloudTranslateAPIKey.isEmpty
  }

  var hasOpenAIAPIKey: Bool {
    !trimmedOpenAIAPIKey.isEmpty
  }
}
