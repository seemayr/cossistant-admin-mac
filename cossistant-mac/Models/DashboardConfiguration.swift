import Foundation

struct DashboardConfiguration: Codable, Equatable, Sendable {
  var apiBaseURLString: String
  var privateAPIKey: String

  static let production = DashboardConfiguration(
    apiBaseURLString: "https://api.cossistant.com/v1",
    privateAPIKey: ""
  )

  var trimmedAPIBaseURLString: String {
    apiBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var trimmedPrivateAPIKey: String {
    privateAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var apiBaseURL: URL? {
    URL(string: trimmedAPIBaseURLString)
  }
}

struct GlobalAppSettings: Equatable, Sendable {
  var googleCloudTranslateAPIKey: String
  var openAIAPIKey: String
  var autoMarkSeenOnOpen: Bool

  static let empty = GlobalAppSettings(
    googleCloudTranslateAPIKey: "",
    openAIAPIKey: "",
    autoMarkSeenOnOpen: true
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
