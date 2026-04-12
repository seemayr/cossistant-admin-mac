import Foundation

struct DashboardProfile: Codable, Equatable, Identifiable, Sendable {
  let id: String
  var name: String
  var apiBaseURLString: String

  var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var hostLabel: String {
    URL(string: apiBaseURLString)?.host() ?? apiBaseURLString
  }
}
