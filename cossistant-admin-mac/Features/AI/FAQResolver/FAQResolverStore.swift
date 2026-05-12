import Foundation
import Observation
import CossistantAdmin

@Observable @MainActor
final class FAQResolverStore {
  private var workspaceChannelFilter: String?

  var task: Task<Void, Never>?
  var autoAssignAllTask: Task<Void, Never>?
  var hasOpenAIAPIKey = false
  var selectedAIAgentID: String?
  var faqEntries: [DashboardKnowledge] = []
  var isLoadingFAQs = false
  var faqErrorMessage: String?
  var statusMessage: String?
  var sourceScope: FAQResolverSourceScope = .open
  var priorityFilter: InboxPriorityFilter = .all
  var dateRange: AutoResolveDateRange = .all
  var dateBasis: AutoResolveDateBasis = .latestActivity
  var summaryFilter: FAQResolverSummaryFilter = .all
  var visitorWaitingFilter: FAQResolverVisitorWaitingFilter = .all
  var teamActionFilter: FAQResolverTeamActionFilter = .all
  var ignoresHandledTimestamps = false
  var channelFilter: String?
  var metadataFilters: [InboxMetadataFilterKey: JSONValue] = [:]
  var appVersionFilter: String?
  var gameIDFilter: String?
  var inspectedConversationID: String?
  var conversationStatesByID: [DashboardConversation.ID: FAQResolverConversationState] = [:]
  var isRunningAutoAssignAll = false
  var isRunningFullResolve = false
  var isConfirmingAll = false
  var previewsDraftTranslations = false

  var canReloadFAQs: Bool {
    selectedAIAgentID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
      && !isLoadingFAQs
  }

  var hasActiveCandidateFilters: Bool {
    priorityFilter != .all
      || dateRange != .all
      || summaryFilter != .all
      || visitorWaitingFilter != .all
      || teamActionFilter != .all
      || ignoresHandledTimestamps
      || channelFilter != nil
      || !metadataFilters.isEmpty
      || appVersionFilter != nil
      || gameIDFilter != nil
  }

  func selectedMetadataValue(for key: InboxMetadataFilterKey) -> JSONValue? {
    metadataFilters[key]
  }

  func setMetadataFilter(_ value: JSONValue?, for key: InboxMetadataFilterKey) {
    if let value {
      metadataFilters[key] = value
    } else {
      metadataFilters.removeValue(forKey: key)
    }
  }

  func clearCandidateFilters() {
    priorityFilter = .all
    dateRange = .all
    dateBasis = .latestActivity
    summaryFilter = .all
    visitorWaitingFilter = .all
    teamActionFilter = .all
    ignoresHandledTimestamps = false
    channelFilter = workspaceChannelFilter
    metadataFilters = [:]
    appVersionFilter = nil
    gameIDFilter = nil
  }

  func applyWorkspaceChannelFilter(_ channelFilter: String?) {
    workspaceChannelFilter = channelFilter
    self.channelFilter = channelFilter
  }

  func state(for conversationID: DashboardConversation.ID) -> FAQResolverConversationState {
    conversationStatesByID[conversationID] ?? FAQResolverConversationState()
  }

  func assignedFAQIDs(for conversationID: DashboardConversation.ID) -> [DashboardKnowledge.ID] {
    state(for: conversationID).assignedFAQIDs
  }

  func assignedFAQs(for conversationID: DashboardConversation.ID) -> [DashboardKnowledge] {
    let ids = assignedFAQIDs(for: conversationID)
    guard !ids.isEmpty else { return [] }
    let entriesByID = Dictionary(uniqueKeysWithValues: faqEntries.map { ($0.id, $0) })
    return ids.compactMap { entriesByID[$0] }
  }

  func setAssignedFAQIDs(
    _ faqIDs: [DashboardKnowledge.ID],
    for conversationID: DashboardConversation.ID,
    source: FAQResolverAssignmentSource
  ) {
    let validIDs = Set(faqEntries.map(\.id))
    let dedupedIDs = faqIDs.reduce(into: [DashboardKnowledge.ID]()) { result, id in
      guard validIDs.contains(id), !result.contains(id) else { return }
      result.append(id)
    }
    var state = state(for: conversationID)
    state.assignedFAQIDs = dedupedIDs
    state.assignmentSource = dedupedIDs.isEmpty ? nil : source
    state.pendingConfirmation = nil
    if !dedupedIDs.isEmpty {
      state.urgentlyNeedsTeam = false
      state.teamActionNeeded = nil
    }
    state.status = state.hasResolvableWork ? .assigned : .idle
    conversationStatesByID[conversationID] = state
  }

  func removeAssignedFAQ(
    _ faqID: DashboardKnowledge.ID,
    from conversationID: DashboardConversation.ID
  ) {
    var state = state(for: conversationID)
    state.assignedFAQIDs.removeAll { $0 == faqID }
    state.pendingConfirmation = nil
    if state.assignedFAQIDs.isEmpty {
      state.assignmentSource = nil
      state.status = state.hasResolvableWork ? .assigned : .idle
    }
    conversationStatesByID[conversationID] = state
  }

  func setCanResolveWithoutReply(
    _ canResolve: Bool,
    for conversationID: DashboardConversation.ID
  ) {
    var state = state(for: conversationID)
    state.canResolveWithoutReply = canResolve
    state.pendingConfirmation = nil
    if canResolve {
      state.noActionNeeded = false
      state.urgentlyNeedsTeam = false
      state.teamActionNeeded = nil
      state.status = .assigned
    } else if !state.hasResolvableWork {
      state.status = .idle
    }
    conversationStatesByID[conversationID] = state
  }

  func setNoActionNeeded(
    _ noActionNeeded: Bool,
    for conversationID: DashboardConversation.ID
  ) {
    var state = state(for: conversationID)
    state.noActionNeeded = noActionNeeded
    state.pendingConfirmation = nil
    if noActionNeeded {
      state.canResolveWithoutReply = false
      state.urgentlyNeedsTeam = false
      state.teamActionNeeded = nil
      state.status = .assigned
    } else if !state.hasResolvableWork {
      state.status = .idle
    }
    conversationStatesByID[conversationID] = state
  }

  func setUrgentlyNeedsTeam(
    _ urgentlyNeedsTeam: Bool,
    for conversationID: DashboardConversation.ID,
    teamActionNeeded: String? = nil
  ) {
    var state = state(for: conversationID)
    state.urgentlyNeedsTeam = urgentlyNeedsTeam
    state.pendingConfirmation = nil
    if urgentlyNeedsTeam {
      state.canResolveWithoutReply = false
      state.noActionNeeded = false
      state.teamActionNeeded = normalizedTeamActionNeeded(teamActionNeeded)
      state.status = .assigned
    } else {
      state.teamActionNeeded = nil
      state.status = state.hasResolvableWork ? .assigned : .idle
    }
    conversationStatesByID[conversationID] = state
  }

  func setPendingConfirmation(
    _ pendingConfirmation: FAQResolverPendingConfirmation?,
    for conversationID: DashboardConversation.ID
  ) {
    var state = state(for: conversationID)
    state.pendingConfirmation = pendingConfirmation
    if pendingConfirmation != nil {
      state.status = .pendingConfirmation
    } else {
      state.status = state.hasResolvableWork ? .assigned : .idle
    }
    conversationStatesByID[conversationID] = state
  }

  func pendingConfirmation(for conversationID: DashboardConversation.ID) -> FAQResolverPendingConfirmation? {
    state(for: conversationID).pendingConfirmation
  }

  func setPendingDraftTranslation(
    _ translatedMessage: DashboardMessageTranslation?,
    errorMessage: String?,
    for conversationID: DashboardConversation.ID
  ) {
    var state = state(for: conversationID)
    guard var pendingConfirmation = state.pendingConfirmation else { return }
    pendingConfirmation.translatedMessage = translatedMessage
    pendingConfirmation.translationErrorMessage = errorMessage
    state.pendingConfirmation = pendingConfirmation
    conversationStatesByID[conversationID] = state
  }

  func resetPendingResolveResult(for conversationID: DashboardConversation.ID) {
    var state = state(for: conversationID)
    state.pendingConfirmation = nil
    state.status = state.hasResolvableWork ? .assigned : .idle
    conversationStatesByID[conversationID] = state
  }

  func completeConfirmation(
    for conversationID: DashboardConversation.ID,
    status: FAQResolverRowStatus,
    keepsTeamNeed: Bool = false
  ) {
    var state = state(for: conversationID)
    state.assignedFAQIDs = []
    state.assignmentSource = nil
    state.canResolveWithoutReply = false
    state.noActionNeeded = false
    state.pendingConfirmation = nil
    if keepsTeamNeed {
      state.urgentlyNeedsTeam = true
    } else {
      state.urgentlyNeedsTeam = false
      state.teamActionNeeded = nil
    }
    state.status = status
    conversationStatesByID[conversationID] = state
  }

  var pendingConfirmationCount: Int {
    conversationStatesByID.values.filter { $0.pendingConfirmation != nil }.count
  }

  func setStatus(
    _ status: FAQResolverRowStatus,
    for conversationID: DashboardConversation.ID
  ) {
    var state = state(for: conversationID)
    state.status = status
    conversationStatesByID[conversationID] = state
  }

  func resetResults() {
    task?.cancel()
    task = nil
    autoAssignAllTask?.cancel()
    autoAssignAllTask = nil
    statusMessage = nil
    isRunningFullResolve = false
    isRunningAutoAssignAll = false
    isConfirmingAll = false
    for key in conversationStatesByID.keys {
      var state = conversationStatesByID[key] ?? FAQResolverConversationState()
      state.pendingConfirmation = nil
      state.status = state.hasResolvableWork ? .assigned : .idle
      conversationStatesByID[key] = state
    }
  }

  func reset() {
    task?.cancel()
    task = nil
    autoAssignAllTask?.cancel()
    autoAssignAllTask = nil
    selectedAIAgentID = nil
    faqEntries = []
    isLoadingFAQs = false
    faqErrorMessage = nil
    statusMessage = nil
    sourceScope = .open
    clearCandidateFilters()
    inspectedConversationID = nil
    conversationStatesByID = [:]
    isRunningAutoAssignAll = false
    isRunningFullResolve = false
    isConfirmingAll = false
    previewsDraftTranslations = false
  }

  private func normalizedTeamActionNeeded(_ value: String?) -> String? {
    value?
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
      .nilIfEmpty
  }
}
