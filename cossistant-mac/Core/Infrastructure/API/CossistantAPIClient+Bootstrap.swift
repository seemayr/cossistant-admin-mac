import Foundation

extension CossistantAPIClient {
  func fetchBootstrap(limit: Int = 100) async throws -> WorkspaceBootstrap {
    let website: DashboardWebsite = try await request(path: "websites")
    let organization: DashboardOrganization = try await request(
      path: "organizations/\(website.organizationId)"
    )
    let inbox = try await fetchInbox(limit: limit, cursor: nil)

    return WorkspaceBootstrap(
      website: website,
      organization: organization,
      inbox: inbox
    )
  }
}
