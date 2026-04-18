import Foundation
import Observation
import CossistantAdmin

@Observable @MainActor
final class ContactsStore {
  private var configuration: DashboardConfiguration?
  private var queryRefreshTask: Task<Void, Never>?

  var items: [DashboardContactListItem] = []
  var selectedContact: DashboardContact?
  var selectedContactOrganization: DashboardContactOrganization?
  var page = 1
  var pageSize = 20
  var totalCount = 0
  var searchText = "" {
    didSet {
      guard searchText != oldValue else { return }
      handleQueryInputsChanged(debounce: true)
    }
  }
  var sortBy: DashboardContactSortBy = .updatedAt {
    didSet {
      guard sortBy != oldValue else { return }
      handleQueryInputsChanged()
    }
  }
  var sortOrder: DashboardSortOrder = .desc {
    didSet {
      guard sortOrder != oldValue else { return }
      handleQueryInputsChanged()
    }
  }
  var visitorStatus: DashboardContactVisitorStatus = .all {
    didSet {
      guard visitorStatus != oldValue else { return }
      handleQueryInputsChanged()
    }
  }
  var isLoadingList = false
  var isLoadingDetail = false
  var errorMessage: String?

  var selectedListItem: DashboardContactListItem? {
    if let selectedContact {
      return items.first { $0.id == selectedContact.id }
    }

    return nil
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
    selectedContact = nil
    selectedContactOrganization = nil
    page = 1
    totalCount = 0
    errorMessage = nil
  }

  func refresh(page requestedPage: Int? = nil) async {
    let querySignature = currentQuerySignature
    errorMessage = nil
    isLoadingList = true
    defer { isLoadingList = false }

    do {
      let response = try await backendClient().contacts.listContacts(
        page: requestedPage ?? page,
        limit: pageSize,
        search: searchText.isEmpty ? nil : searchText,
        sortBy: sortBy,
        sortOrder: sortOrder,
        visitorStatus: visitorStatus
      )
      guard querySignature == currentQuerySignature else { return }
      items = response.items
      page = response.page
      pageSize = response.pageSize
      totalCount = response.totalCount
    } catch {
      guard querySignature == currentQuerySignature else { return }
      errorMessage = error.localizedDescription
    }
  }

  func loadContact(id: String) async {
    errorMessage = nil
    isLoadingDetail = true
    defer { isLoadingDetail = false }

    do {
      selectedContact = try await backendClient().contacts.fetchContact(id: id)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @discardableResult
  func createContact(_ draft: DashboardContactDraft) async -> DashboardContact? {
    errorMessage = nil

    do {
      let createdContact = try await backendClient().contacts.createContact(draft)
      selectedContact = createdContact
      await refresh()
      return createdContact
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  @discardableResult
  func updateContact(id: String, draft: DashboardContactDraft) async -> DashboardContact? {
    errorMessage = nil

    do {
      let updatedContact = try await backendClient().contacts.updateContact(id: id, draft: draft)
      selectedContact = updatedContact
      await refresh()
      return updatedContact
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  @discardableResult
  func updateContactMetadata(
    id: String,
    metadata: DashboardMetadata
  ) async -> DashboardContact? {
    errorMessage = nil

    do {
      let updatedContact = try await backendClient().contacts.updateContactMetadata(
        id: id,
        metadata: metadata
      )
      selectedContact = updatedContact
      await refresh()
      return updatedContact
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  func deleteContact(id: String) async {
    errorMessage = nil

    do {
      try await backendClient().contacts.deleteContact(id: id)
      items.removeAll { $0.id == id }

      if selectedContact?.id == id {
        selectedContact = nil
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @discardableResult
  func identifyContact(
    request: DashboardIdentifyContactRequest
  ) async -> DashboardIdentifyContactResponse? {
    errorMessage = nil

    do {
      let response = try await backendClient().contacts.identifyContact(request)
      selectedContact = response.contact
      await refresh()
      return response
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  @discardableResult
  func createContactOrganization(
    _ draft: DashboardContactOrganizationDraft
  ) async -> DashboardContactOrganization? {
    errorMessage = nil

    do {
      let organization = try await backendClient().contacts.createContactOrganization(draft)
      selectedContactOrganization = organization
      return organization
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  func loadContactOrganization(id: String) async {
    errorMessage = nil

    do {
      selectedContactOrganization = try await backendClient().contacts.fetchContactOrganization(id: id)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @discardableResult
  func updateContactOrganization(
    id: String,
    draft: DashboardContactOrganizationDraft
  ) async -> DashboardContactOrganization? {
    errorMessage = nil

    do {
      let organization = try await backendClient().contacts.updateContactOrganization(id: id, draft: draft)
      selectedContactOrganization = organization
      return organization
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  func deleteContactOrganization(id: String) async {
    errorMessage = nil

    do {
      try await backendClient().contacts.deleteContactOrganization(id: id)

      if selectedContactOrganization?.id == id {
        selectedContactOrganization = nil
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

  private var currentQuerySignature: String {
    [
      searchText,
      sortBy.rawValue,
      sortOrder.rawValue,
      visitorStatus.rawValue,
      String(pageSize),
    ].joined(separator: "|")
  }

  private func handleQueryInputsChanged(debounce: Bool = false) {
    page = 1
    scheduleRefresh(debounce: debounce)
  }

  private func scheduleRefresh(debounce: Bool) {
    queryRefreshTask?.cancel()
    guard configuration != nil else { return }

    queryRefreshTask = Task { [weak self] in
      guard let self else { return }
      if debounce {
        try? await Task.sleep(for: .milliseconds(250))
      }
      guard !Task.isCancelled else { return }
      await self.refresh(page: 1)
    }
  }
}
