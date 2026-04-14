import Foundation
import CossistantAdmin

enum StoreConfigurationError: LocalizedError {
  case notConfigured

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      "Connect a profile before loading this resource."
    }
  }
}
