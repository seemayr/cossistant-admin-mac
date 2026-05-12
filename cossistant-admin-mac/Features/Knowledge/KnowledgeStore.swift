import Foundation
import Observation
import CossistantAdmin

enum KnowledgeAIAgentScope: String, CaseIterable, Identifiable {
  case all
  case shared
  case specific

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      "All"
    case .shared:
      "Shared"
    case .specific:
      "Agent"
    }
  }
}

@Observable @MainActor
final class KnowledgeStore {
  private var configuration: DashboardConfiguration?
  private var queryRefreshTask: Task<Void, Never>?
  private var suppressAutomaticRefresh = false

  var items: [DashboardKnowledge] = []
  var selectedKnowledge: DashboardKnowledge?
  var page = 1
  var pageSize = 100 {
    didSet {
      guard pageSize != oldValue else { return }
      handleQueryInputsChanged()
    }
  }
  var totalCount = 0
  var hasMore = false
  var hasLoadedListOnce = false
  var searchText = ""
  var filterType: DashboardKnowledgeType? {
    didSet {
      guard filterType != oldValue else { return }
      handleQueryInputsChanged()
    }
  }
  var filterIncluded: DashboardKnowledgeIncludedFilter = .all {
    didSet {
      guard filterIncluded != oldValue else { return }
      handleQueryInputsChanged()
    }
  }
  var filterAIAgentScope: KnowledgeAIAgentScope = .all {
    didSet {
      guard filterAIAgentScope != oldValue else { return }
      handleQueryInputsChanged()
    }
  }
  var filterSpecificAIAgentID: String? {
    didSet {
      guard filterSpecificAIAgentID != oldValue else { return }
      handleQueryInputsChanged()
    }
  }
  var filterLinkSourceID: String? {
    didSet {
      guard filterLinkSourceID != oldValue else { return }
      handleQueryInputsChanged()
    }
  }
  var isLoadingList = false
  var isLoadingDetail = false
  var isExportingFAQ = false
  var errorMessage: String?
  var exportStatusMessage: String?

  var filteredItems: [DashboardKnowledge] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return items }

    return items.filter { item in
      item.titleText.localizedCaseInsensitiveContains(query)
    }
  }

  var hasActiveTitleSearch: Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var hasConfiguredFilters: Bool {
    filterType != nil
      || hasActiveTitleSearch
      || filterIncluded != .all
      || filterAIAgentScope != .all
      || filterSpecificAIAgentID != nil
      || filterLinkSourceID != nil
  }

  func setConfiguration(_ configuration: DashboardConfiguration?) {
    self.configuration = configuration

    if configuration == nil {
      reset()
    }
  }

  func reset() {
    queryRefreshTask?.cancel()
    items = []
    selectedKnowledge = nil
    page = 1
    totalCount = 0
    hasMore = false
    hasLoadedListOnce = false
    searchText = ""
    filterIncluded = .all
    filterAIAgentScope = .all
    filterSpecificAIAgentID = nil
    filterLinkSourceID = nil
    errorMessage = nil
    exportStatusMessage = nil
  }

  func showAllKnowledge(
    preferredAIAgentID: String? = nil,
    refreshAfterUpdate: Bool = true
  ) {
    updateFilters(refreshAfterUpdate: refreshAfterUpdate) {
      page = 1
      filterType = nil
      filterIncluded = .all
      if let preferredAIAgentID, !preferredAIAgentID.isEmpty {
        filterAIAgentScope = .specific
        filterSpecificAIAgentID = preferredAIAgentID
      } else {
        filterAIAgentScope = .all
        filterSpecificAIAgentID = nil
      }
      filterLinkSourceID = nil
      searchText = ""
    }
    print("[KnowledgeUI][macOS] reset to all knowledge filters")
  }

  func refresh(page requestedPage: Int? = nil) async {
    let querySignature = currentQuerySignature
    errorMessage = nil
    isLoadingList = true
    defer {
      isLoadingList = false
      hasLoadedListOnce = true
    }

    do {
      let currentPage = requestedPage ?? page
      print(
        """
        [KnowledgeUI][macOS] refreshKnowledge \
        page=\(currentPage) \
        type=\(filterType?.rawValue ?? "nil") \
        included=\(filterIncluded.rawValue) \
        scope=\(filterAIAgentScope.rawValue) \
        specificAgent=\(filterSpecificAIAgentID ?? "nil") \
        linkSourceId=\(filterLinkSourceID ?? "nil")
        """
      )
      let response = try await backendClient().knowledge.listKnowledge(
        page: currentPage,
        limit: pageSize,
        type: filterType,
        aiAgentFilter: resolvedAIAgentFilter,
        isIncluded: filterIncluded,
        linkSourceID: filterLinkSourceID
      )
      guard querySignature == currentQuerySignature else { return }
      items = response.items
      page = response.pagination.page
      pageSize = response.pagination.limit
      totalCount = response.pagination.total
      hasMore = response.pagination.hasMore
      print(
        """
        [KnowledgeUI][macOS] refreshKnowledge response \
        items=\(items.count) \
        total=\(totalCount) \
        page=\(page) \
        hasMore=\(hasMore)
        """
      )
    } catch {
      guard querySignature == currentQuerySignature else { return }
      print("[KnowledgeUI][macOS] refreshKnowledge failed: \(error.localizedDescription)")
      errorMessage = error.localizedDescription
    }
  }

  func loadPreviousPage() async {
    guard page > 1 else { return }
    await refresh(page: page - 1)
  }

  func loadNextPage() async {
    guard hasMore else { return }
    await refresh(page: page + 1)
  }

  func loadKnowledge(id: String) async {
    errorMessage = nil
    isLoadingDetail = true
    defer { isLoadingDetail = false }

    do {
      selectedKnowledge = try await backendClient().knowledge.fetchKnowledge(id: id)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @discardableResult
  func createKnowledge(_ draft: DashboardKnowledgeDraft) async -> DashboardKnowledge? {
    errorMessage = nil

    do {
      let createdKnowledge = try await backendClient().knowledge.createKnowledge(draft)
      selectedKnowledge = createdKnowledge
      await refresh()
      return createdKnowledge
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  @discardableResult
  func updateKnowledge(
    id: String,
    draft: DashboardKnowledgeDraft
  ) async -> DashboardKnowledge? {
    errorMessage = nil

    do {
      let updatedKnowledge = try await backendClient().knowledge.updateKnowledge(id: id, draft: draft)
      selectedKnowledge = updatedKnowledge
      await refresh()
      return updatedKnowledge
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  func deleteKnowledge(id: String) async {
    errorMessage = nil

    do {
      try await backendClient().knowledge.deleteKnowledge(id: id)
      items.removeAll { $0.id == id }

      if selectedKnowledge?.id == id {
        selectedKnowledge = nil
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func showSharedKnowledge() {
    updateFilters(refreshAfterUpdate: true) {
      filterAIAgentScope = .shared
      filterSpecificAIAgentID = nil
      page = 1
    }
  }

  func buildFAQExport() async throws -> KnowledgeFAQExportResult {
    guard !isExportingFAQ else {
      throw KnowledgeFAQExportError.exportAlreadyRunning
    }

    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    let client = try backendClient()
    var page = 1
    var hasMore = true
    var entries: [KnowledgeFAQExportEntry] = []
    var seenIDs = Set<String>()

    errorMessage = nil
    exportStatusMessage = "Exporting FAQ entries..."
    isExportingFAQ = true
    defer { isExportingFAQ = false }

    while hasMore {
      let response = try await client.knowledge.listKnowledge(
        page: page,
        limit: 100,
        type: .faq,
        aiAgentFilter: resolvedAIAgentFilter,
        isIncluded: filterIncluded,
        linkSourceID: filterLinkSourceID
      )

      for item in response.items where seenIDs.insert(item.id).inserted {
        guard let payload = item.faqPayload else { continue }
        guard query.isEmpty || item.titleText.localizedCaseInsensitiveContains(query) else { continue }
        entries.append(
          KnowledgeFAQExportEntry(
            question: payload.question,
            categories: payload.categories,
            relatedQuestions: payload.relatedQuestions,
            answer: payload.answer
          )
        )
      }

      hasMore = response.pagination.hasMore
      page += 1
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
    let data = try encoder.encode(entries)
    guard let json = String(data: data, encoding: .utf8) else {
      throw KnowledgeFAQExportError.invalidEncoding
    }

    return KnowledgeFAQExportResult(json: json, count: entries.count)
  }

  private var resolvedAIAgentFilter: DashboardKnowledgeAIAgentFilter {
    switch filterAIAgentScope {
    case .all:
      return .all
    case .shared:
      return .shared
    case .specific:
      if let filterSpecificAIAgentID, !filterSpecificAIAgentID.isEmpty {
        return .specific(filterSpecificAIAgentID)
      }
      return .all
    }
  }

  private func backendClient() throws -> CossistantAdminClient {
    guard let configuration else {
      throw StoreConfigurationError.notConfigured
    }

    return CossistantAdminClient(configuration: configuration)
  }

  private var currentQuerySignature: String {
    [
      filterType?.rawValue ?? "all",
      filterIncluded.rawValue,
      filterAIAgentScope.rawValue,
      filterSpecificAIAgentID ?? "",
      filterLinkSourceID ?? "",
      String(pageSize),
    ].joined(separator: "|")
  }

  private func handleQueryInputsChanged() {
    guard !suppressAutomaticRefresh else { return }
    page = 1
    scheduleRefresh(page: 1)
  }

  private func scheduleRefresh(page requestedPage: Int) {
    queryRefreshTask?.cancel()
    guard configuration != nil else { return }

    queryRefreshTask = Task { [weak self] in
      guard let self else { return }
      guard !Task.isCancelled else { return }
      await self.refresh(page: requestedPage)
    }
  }

  private func updateFilters(
    refreshAfterUpdate: Bool,
    _ update: () -> Void
  ) {
    suppressAutomaticRefresh = true
    update()
    suppressAutomaticRefresh = false
    if refreshAfterUpdate {
      scheduleRefresh(page: 1)
    }
  }
}

struct KnowledgeFAQExportResult: Sendable {
  let json: String
  let count: Int
}

struct KnowledgeFAQExportEntry: Encodable, Sendable {
  let question: String
  let categories: [String]
  let relatedQuestions: [String]
  let answer: String
}

enum KnowledgeFAQExportError: LocalizedError {
  case exportAlreadyRunning
  case invalidEncoding

  var errorDescription: String? {
    switch self {
    case .exportAlreadyRunning:
      "An FAQ export is already running."
    case .invalidEncoding:
      "The FAQ export could not be encoded as UTF-8 JSON."
    }
  }
}
