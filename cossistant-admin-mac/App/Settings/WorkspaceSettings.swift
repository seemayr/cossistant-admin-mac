import Foundation
import CossistantAdmin

struct WorkspaceSettings: Codable, Equatable, Sendable {
  var channelFilter: String?
  var autoMarkSeenOnOpen: Bool
  var showBackendTranslatedSubjects: Bool
  var showBackendTranslatedMessages: Bool

  static let empty = WorkspaceSettings(
    channelFilter: nil,
    autoMarkSeenOnOpen: false,
    showBackendTranslatedSubjects: true,
    showBackendTranslatedMessages: true
  )

  var normalizedChannelFilter: String? {
    channelFilter?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
  }
}
