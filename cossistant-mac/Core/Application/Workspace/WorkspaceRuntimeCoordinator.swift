import Foundation

@MainActor
final class WorkspaceRuntimeCoordinator {
  private var realtimeClient: CossistantRealtimeClient?
  private var pollingTask: Task<Void, Never>?
  private var selectedConversationRefreshTask: Task<Void, Never>?

  func configureRealtime(
    configuration: DashboardConfiguration,
    websiteID: String,
    organizationID: String,
    onConnectionStateChange: @escaping @MainActor @Sendable (DashboardRealtimeConnectionState) -> Void,
    onEvent: @escaping @MainActor @Sendable (DashboardRealtimeEvent) -> Void
  ) {
    guard let webSocketURL = makeRealtimeURL(
      configuration: configuration,
      websiteID: websiteID
    ) else {
      onConnectionStateChange(.failed(CossistantAPIError.invalidBaseURL.localizedDescription))
      return
    }

    Task { [weak self] in
      await self?.realtimeClient?.disconnect()
    }

    let client = CossistantRealtimeClient(
      webSocketURL: webSocketURL,
      websiteID: websiteID,
      organizationID: organizationID,
      onConnectionStateChange: onConnectionStateChange,
      onEvent: onEvent
    )

    realtimeClient = client

    Task {
      await client.connect()
    }
  }

  func startPollingLoop(
    connectionState: @escaping @MainActor @Sendable () -> DashboardRealtimeConnectionState,
    onRefresh: @escaping @MainActor @Sendable () async -> Void
  ) {
    pollingTask?.cancel()
    pollingTask = Task {
      while !Task.isCancelled {
        let interval = await MainActor.run {
          connectionState().isConnected ? Duration.seconds(90) : Duration.seconds(30)
        }

        do {
          try await Task.sleep(for: interval)
        } catch {
          return
        }

        await onRefresh()
      }
    }
  }

  func stopBackgroundWork(
    inboxRefreshTask: inout Task<Void, Never>?
  ) {
    pollingTask?.cancel()
    inboxRefreshTask?.cancel()
    selectedConversationRefreshTask?.cancel()
    pollingTask = nil
    inboxRefreshTask = nil
    selectedConversationRefreshTask = nil

    Task { [weak self] in
      await self?.realtimeClient?.disconnect()
    }
    realtimeClient = nil
  }

  func scheduleSelectedConversationRefresh(
    _ action: @escaping @MainActor @Sendable () async -> Void
  ) {
    selectedConversationRefreshTask?.cancel()
    selectedConversationRefreshTask = Task {
      do {
        try await Task.sleep(for: .milliseconds(700))
      } catch {
        return
      }

      await action()
    }
  }

  func send(_ event: DashboardRealtimeClientEvent) async {
    await realtimeClient?.send(event)
  }

  private func makeRealtimeURL(
    configuration: DashboardConfiguration,
    websiteID: String
  ) -> URL? {
    guard configuration.trimmedPrivateAPIKey.hasPrefix("sk_"),
          let baseURL = configuration.apiBaseURL,
          var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      return nil
    }

    switch components.scheme {
    case "https":
      components.scheme = "wss"
    case "http":
      components.scheme = "ws"
    default:
      return nil
    }

    let trimmedPath = components.path.replacingOccurrences(of: "/v1", with: "")
    components.path = "\(trimmedPath)/ws".replacingOccurrences(of: "//", with: "/")
    components.queryItems = [
      URLQueryItem(name: "token", value: configuration.trimmedPrivateAPIKey),
      URLQueryItem(name: "websiteId", value: websiteID),
    ]

    return components.url
  }
}
