import Foundation

enum DashboardStoreError: LocalizedError {
  case notConfigured

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      "Connect a profile before loading this resource."
    }
  }
}
