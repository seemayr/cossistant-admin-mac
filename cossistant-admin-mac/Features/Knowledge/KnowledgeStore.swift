import Foundation
import Observation
import CossistantAdmin

@Observable @MainActor
final class KnowledgeStore {
  private var configuration: DashboardConfiguration?

  var items: [DashboardKnowledge] = []
  var selectedKnowledge: DashboardKnowledge?
  var page = 1
  var pageSize = 20
  var totalCount = 0
  var hasMore = false
  var filterType: DashboardKnowledgeType?
  var filterIncluded: DashboardKnowledgeIncludedFilter = .all
  var filterAIAgentID: String?
  var filterLinkSourceID: String?
  var isLoadingList = false
  var isLoadingDetail = false
  var errorMessage: String?

  func setConfiguration(_ configuration: DashboardConfiguration?) {
    self.configuration = configuration

    if configuration == nil {
      reset()
    }
  }

  func reset() {
    items = []
    selectedKnowledge = nil
    page = 1
    totalCount = 0
    hasMore = false
    filterIncluded = .all
    filterAIAgentID = nil
    filterLinkSourceID = nil
    errorMessage = nil
  }

  func refresh(page requestedPage: Int? = nil) async {
    errorMessage = nil
    isLoadingList = true
    defer { isLoadingList = false }

    do {
      let currentPage = requestedPage ?? page
      let response = try await backendClient().knowledge.listKnowledge(
        page: currentPage,
        limit: pageSize,
        type: filterType,
        aiAgentID: filterAIAgentID,
        isIncluded: filterIncluded,
        linkSourceID: filterLinkSourceID
      )
      items = response.items
      page = response.pagination.page
      pageSize = response.pagination.limit
      totalCount = response.pagination.total
      hasMore = response.pagination.hasMore
    } catch {
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

  private func backendClient() throws -> CossistantAdminClient {
    guard let configuration else {
      throw StoreConfigurationError.notConfigured
    }

    return CossistantAdminClient(configuration: configuration)
  }
}
