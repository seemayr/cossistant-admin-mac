import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  func restoreSessionIfNeeded() async {
    guard !hasRestoredSession else { return }
    hasRestoredSession = true
    reloadProfiles()

    guard let profileID = sessionCoordinator.restoredProfileID(profiles: profiles) else { return }
    await connect(profileID: profileID)
  }

  func reloadProfiles() {
    profiles = sessionCoordinator.loadProfiles()
  }

  func clearErrorMessage() {
    errorMessage = nil
  }

  func setGlobalErrorMessage(_ error: any Error) {
    guard !isIgnorableCancellation(error) else { return }
    errorMessage = error.localizedDescription
  }

  func isIgnorableCancellation(_ error: any Error) -> Bool {
    if error is CancellationError {
      return true
    }

    if let urlError = error as? URLError, urlError.code == .cancelled {
      return true
    }

    let nsError = error as NSError
    return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
  }

  func reloadGlobalSettings() {
    globalSettings = sessionCoordinator.loadGlobalSettings()
    analyticsStore.hasOpenAIAPIKey = globalSettings.hasOpenAIAPIKey
    autoResolveStore.hasOpenAIAPIKey = globalSettings.hasOpenAIAPIKey
    faqResolverStore.hasOpenAIAPIKey = globalSettings.hasOpenAIAPIKey
    faqStore.hasOpenAIAPIKey = globalSettings.hasOpenAIAPIKey
  }

  func reloadGlobalSettingsAndRefreshTranslations() async {
    reloadGlobalSettings()

    guard showMessageTranslations else { return }
    translatedMessagesByID = [:]
    translatedClarification = nil
    await loadTranslationsForSelectedConversationIfNeeded(force: true)
  }

  func saveGlobalSettings() {
    do {
      try sessionCoordinator.saveGlobalSettings(globalSettings)
      globalSettingsStatusMessage = "Saved global service keys."
      analyticsStore.hasOpenAIAPIKey = globalSettings.hasOpenAIAPIKey
      autoResolveStore.hasOpenAIAPIKey = globalSettings.hasOpenAIAPIKey
      faqResolverStore.hasOpenAIAPIKey = globalSettings.hasOpenAIAPIKey
      faqStore.hasOpenAIAPIKey = globalSettings.hasOpenAIAPIKey
      translationErrorMessage = nil
      replyDraftErrorMessage = nil
    } catch {
      globalSettingsStatusMessage = nil
      setGlobalErrorMessage(error)
    }
  }

  func connect(profileID: DashboardProfile.ID) async {
    errorMessage = nil
    isConnecting = true
    defer { isConnecting = false }

    do {
      let context = try await sessionCoordinator.fetchConnectionContext(
        profileID: profileID,
        profiles: profiles,
        inboxPageSize: Self.inboxPageSize
      )

      configuration = context.configuration
      inboxStore.setConfiguration(context.configuration)
      currentProfileID = context.profile.id
      workspaceSettings = sessionCoordinator.loadWorkspaceSettings(profileID: context.profile.id)
      applyWorkspaceConversationFilterDefaults()
      website = context.bootstrap.website
      organization = context.bootstrap.organization
      inboxStore.applyBootstrap(context.bootstrap.inbox)
      selectedConversationID = nil
      contactsStore.setConfiguration(context.configuration)
      knowledgeStore.setConfiguration(context.configuration)
      aiAgentStore.setConfiguration(context.configuration)
      clearSelectedConversationState()
      sessionCoordinator.setLastUsedProfileID(context.profile.id)
      isShowingConfigurationSheet = false
      runtimeCoordinator.configureRealtime(
        backendClient: CossistantAdminClient(configuration: context.configuration),
        websiteID: context.bootstrap.website.id,
        organizationID: context.bootstrap.organization.id,
        onConnectionStateChange: { [weak self] state in
          self?.realtimeConnectionState = state
        },
        onEvent: { [weak self] event in
          self?.handleRealtimeEvent(event)
        }
      )
      runtimeCoordinator.startPollingLoop(
        connectionState: { [weak self] in
          self?.realtimeConnectionState ?? .disconnected
        },
        onRefresh: { [weak self] in
          await self?.performBackgroundRefresh()
        }
      )
      startInboxPrefetch()

      await loadSelectedConversation(force: true)
    } catch {
      if website == nil {
        clearConnectedState()
      }
      setGlobalErrorMessage(error)
    }
  }

  func saveWorkspaceSettings() {
    guard let currentProfileID else { return }

    do {
      try sessionCoordinator.saveWorkspaceSettings(workspaceSettings, profileID: currentProfileID)
      applyWorkspaceConversationFilterDefaults()
      globalSettingsStatusMessage = nil
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func setWorkspaceChannelFilter(_ channelFilter: String?) {
    workspaceSettings.channelFilter = channelFilter?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    saveWorkspaceSettings()
  }

  func setWorkspaceAutoMarkSeenOnOpen(_ isEnabled: Bool) {
    workspaceSettings.autoMarkSeenOnOpen = isEnabled
    saveWorkspaceSettings()
  }

  func setWorkspaceShowBackendTranslatedSubjects(_ isEnabled: Bool) {
    workspaceSettings.showBackendTranslatedSubjects = isEnabled
    saveWorkspaceSettings()
  }

  func setWorkspaceShowBackendTranslatedMessages(_ isEnabled: Bool) async {
    workspaceSettings.showBackendTranslatedMessages = isEnabled
    saveWorkspaceSettings()

    guard showMessageTranslations else { return }
    translatedMessagesByID = [:]
    translatedClarification = nil
    await loadTranslationsForSelectedConversationIfNeeded(force: true)
  }

  func applyWorkspaceConversationFilterDefaults() {
    let channelFilter = workspaceSettings.normalizedChannelFilter
    inboxStore.applyWorkspaceChannelFilter(channelFilter)
    analyticsStore.applyWorkspaceChannelFilter(channelFilter)
    autoResolveStore.applyWorkspaceChannelFilter(channelFilter)
    faqResolverStore.applyWorkspaceChannelFilter(channelFilter)
  }

  func refresh() async {
    guard !isConnecting, let currentProfileID else { return }
    await connect(profileID: currentProfileID)
  }
}
