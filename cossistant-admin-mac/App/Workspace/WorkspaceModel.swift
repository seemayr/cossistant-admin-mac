import Foundation
import Observation
import CossistantAdmin

@Observable @MainActor
final class WorkspaceModel {
  static let inboxPageSize = 100
  static let automaticInboxPageLimit = 10

  let runtimeCoordinator: WorkspaceRuntimeCoordinator
  let sessionCoordinator: WorkspaceSessionCoordinator
  var inboxRefreshTask: Task<Void, Never>?
  var selectedConversationLoadTask: Task<Void, Never>?
  var selectedContactLoadTask: Task<Void, Never>?
  var selectedKnowledgeLoadTask: Task<Void, Never>?
  var selectedAIAgentLoadTask: Task<Void, Never>?

  let analyticsStore: AnalyticsStore
  let aiAgentStore: AIAgentStore
  let autoResolveStore: AutoResolveStore
  let contactsStore: ContactsStore
  let conversationStore: ConversationStore
  let faqStore: FAQStore
  let inboxStore: InboxStore
  let knowledgeStore: KnowledgeStore
  var configuration = DashboardConfiguration.production
  var globalSettings: GlobalServiceSettings
  var profiles: [DashboardProfile]
  var currentProfileID: DashboardProfile.ID?
  var website: DashboardWebsite?
  var organization: DashboardOrganization?
  var selectedConversationID: DashboardConversation.ID?
  var visitorPresenceByID: [String: DashboardVisitorPresence] = [:]
  var currentActorUserID: String?
  var manuallyUnreadConversationIDs: Set<String> = [] {
    didSet {
      inboxStore.setManuallyUnreadConversationIDs(manuallyUnreadConversationIDs)
    }
  }
  var showDeveloperLogs = false
  var realtimeConnectionState: DashboardRealtimeConnectionState = .disconnected
  var lastRealtimeEventDate: Date?
  var isRefreshingInboxSnapshot = false
  var isConnecting = false
  var hasRestoredSession = false
  var isShowingConfigurationSheet = false
  var globalSettingsStatusMessage: String?
  var errorMessage: String?

  init(
    initialProfileID: DashboardProfile.ID? = nil,
    restoreLastUsedSession: Bool = true
  ) {
    let configurationStore = AppConfigurationStore()
    self.runtimeCoordinator = WorkspaceRuntimeCoordinator()
    self.sessionCoordinator = WorkspaceSessionCoordinator(
      configurationStore: configurationStore,
      initialProfileID: initialProfileID,
      restoreLastUsedSession: restoreLastUsedSession
    )
    self.analyticsStore = AnalyticsStore()
    self.aiAgentStore = AIAgentStore()
    self.autoResolveStore = AutoResolveStore()
    self.contactsStore = ContactsStore()
    self.conversationStore = ConversationStore()
    self.faqStore = FAQStore()
    self.inboxStore = InboxStore()
    self.knowledgeStore = KnowledgeStore()
    self.globalSettings = sessionCoordinator.loadGlobalSettings()
    self.profiles = sessionCoordinator.loadProfiles()
    self.analyticsStore.hasOpenAIAPIKey = self.globalSettings.hasOpenAIAPIKey
    self.autoResolveStore.hasOpenAIAPIKey = self.globalSettings.hasOpenAIAPIKey
    self.faqStore.hasOpenAIAPIKey = self.globalSettings.hasOpenAIAPIKey
  }

  func disconnectCurrentProfile() {
    runtimeCoordinator.stopBackgroundWork(inboxRefreshTask: &inboxRefreshTask)
    clearConnectedState()
    sessionCoordinator.setLastUsedProfileID(nil)
  }

  func clearConnectedState() {
    selectedConversationLoadTask?.cancel()
    selectedConversationLoadTask = nil
    selectedContactLoadTask?.cancel()
    selectedContactLoadTask = nil
    selectedKnowledgeLoadTask?.cancel()
    selectedKnowledgeLoadTask = nil
    selectedAIAgentLoadTask?.cancel()
    selectedAIAgentLoadTask = nil
    currentProfileID = nil
    website = nil
    organization = nil
    inboxStore.reset()
    inboxStore.setConfiguration(nil)
    selectedConversationID = nil
    currentActorUserID = nil
    manuallyUnreadConversationIDs = []
    contactsStore.setConfiguration(nil)
    knowledgeStore.setConfiguration(nil)
    aiAgentStore.setConfiguration(nil)
    conversationStore.reset()
    visitorPresenceByID = [:]
    realtimeConnectionState = .disconnected
    lastRealtimeEventDate = nil
  }

  func clearSelectedConversationState() {
    selectedConversationLoadTask?.cancel()
    selectedConversationLoadTask = nil
    conversationStore.clearSelection()
  }
}
