import Foundation
import CossistantAdmin

@MainActor
final class WorkspaceRuntimeCoordinator {
  private var realtimeClient: CossistantRealtimeClient?
  private var pollingTask: Task<Void, Never>?
  private var selectedConversationRefreshTask: Task<Void, Never>?

  func configureRealtime(
    backendClient: CossistantAdminClient,
    websiteID: String,
    organizationID: String,
    onConnectionStateChange: @escaping @MainActor @Sendable (DashboardRealtimeConnectionState) -> Void,
    onEvent: @escaping @MainActor @Sendable (DashboardRealtimeEvent) -> Void
  ) {
    let client: CossistantRealtimeClient
    do {
      client = try backendClient.makeRealtimeClient(
        websiteID: websiteID,
        organizationID: organizationID,
        onConnectionStateChange: onConnectionStateChange,
        onEvent: onEvent
      )
    } catch {
      onConnectionStateChange(.failed(error.localizedDescription))
      return
    }

    Task { [weak self] in
      await self?.realtimeClient?.disconnect()
    }

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
        do {
          try await Task.sleep(for: .seconds(60))
        } catch {
          return
        }

        let isConnected = await MainActor.run {
          connectionState().isConnected
        }
        guard !isConnected else { continue }

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
}
