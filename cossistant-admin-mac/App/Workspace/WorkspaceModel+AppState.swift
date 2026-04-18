import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  var backendClient: CossistantAdminClient {
    CossistantAdminClient(configuration: configuration)
  }

  var needsConfiguration: Bool {
    website == nil
  }

  var currentProfile: DashboardProfile? {
    profiles.first { $0.id == currentProfileID }
  }

  var connectionSummary: String {
    if let profile = currentProfile, let website, let organization {
      return "\(profile.name) • \(organization.name) • \(website.name)"
    }

    return "Not connected"
  }

  var canUseMessageTranslations: Bool {
    globalSettings.hasGoogleCloudTranslateAPIKey
      || selectedConversation?.translationActivatedAt != nil
      || selectedTimelineItems.contains { hasStoredTeamTranslation(for: $0) }
  }

  var canUseConversationDraftTranslation: Bool {
    globalSettings.hasGoogleCloudTranslateAPIKey
  }

  var canUseOpenAIReplyDrafts: Bool {
    globalSettings.hasOpenAIAPIKey
  }

  var shouldAutoMarkSeenOnOpen: Bool {
    globalSettings.autoMarkSeenOnOpen
  }

  func isConversationManuallyMarkedUnread(_ conversationID: String?) -> Bool {
    guard let conversationID else { return false }
    return manuallyUnreadConversationIDs.contains(conversationID)
  }

  func conversationHasUnreadActivity(_ conversation: DashboardConversation) -> Bool {
    manuallyUnreadConversationIDs.contains(conversation.id) || conversation.hasUnreadActivity
  }
}
