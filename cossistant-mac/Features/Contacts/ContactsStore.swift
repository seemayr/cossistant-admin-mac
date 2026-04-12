import Foundation
import Observation

@Observable @MainActor
final class ContactsStore {
  private var configuration: DashboardConfiguration?

  var items: [DashboardContactListItem] = []
  var selectedContact: DashboardContact?
  var selectedContactOrganization: DashboardContactOrganization?
  var page = 1
  var pageSize = 20
  var totalCount = 0
  var searchText = ""
  var sortBy: DashboardContactSortBy = .updatedAt
  var sortOrder: DashboardSortOrder = .desc
  var visitorStatus: DashboardContactVisitorStatus = .all
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
    items = []
    selectedContact = nil
    selectedContactOrganization = nil
    page = 1
    totalCount = 0
    errorMessage = nil
  }

  func refresh() async {
    errorMessage = nil
    isLoadingList = true
    defer { isLoadingList = false }

    do {
      let response = try await client().listContacts(
        page: page,
        limit: pageSize,
        search: searchText.isEmpty ? nil : searchText,
        sortBy: sortBy,
        sortOrder: sortOrder,
        visitorStatus: visitorStatus
      )
      items = response.items
      page = response.page
      pageSize = response.pageSize
      totalCount = response.totalCount
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func loadContact(id: String) async {
    errorMessage = nil
    isLoadingDetail = true
    defer { isLoadingDetail = false }

    do {
      selectedContact = try await client().fetchContact(id: id)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @discardableResult
  func createContact(_ draft: DashboardContactDraft) async -> DashboardContact? {
    errorMessage = nil

    do {
      let createdContact = try await client().createContact(draft)
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
      let updatedContact = try await client().updateContact(id: id, draft: draft)
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
      let updatedContact = try await client().updateContactMetadata(
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
      try await client().deleteContact(id: id)
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
      let response = try await client().identifyContact(request)
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
      let organization = try await client().createContactOrganization(draft)
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
      selectedContactOrganization = try await client().fetchContactOrganization(id: id)
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
      let organization = try await client().updateContactOrganization(id: id, draft: draft)
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
      try await client().deleteContactOrganization(id: id)

      if selectedContactOrganization?.id == id {
        selectedContactOrganization = nil
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func client() throws -> CossistantAPIClient {
    guard let configuration else {
      throw StoreConfigurationError.notConfigured
    }

    return CossistantAPIClient(configuration: configuration)
  }
}
