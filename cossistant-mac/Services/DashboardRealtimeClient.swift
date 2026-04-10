import Foundation

actor DashboardRealtimeClient {
  private let webSocketURL: URL
  private let websiteID: String
  private let organizationID: String?
  private let session: URLSession
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()
  private let heartbeatInterval: Duration = .seconds(15)
  private let onConnectionStateChange: @MainActor @Sendable (DashboardRealtimeConnectionState) -> Void
  private let onEvent: @MainActor @Sendable (DashboardRealtimeEvent) -> Void

  private var task: URLSessionWebSocketTask?
  private var receiveTask: Task<Void, Never>?
  private var heartbeatTask: Task<Void, Never>?
  private var reconnectTask: Task<Void, Never>?
  private var isIntentionalDisconnect = false
  private var reconnectAttempt = 0

  init(
    webSocketURL: URL,
    websiteID: String,
    organizationID: String?,
    session: URLSession = .shared,
    onConnectionStateChange: @escaping @MainActor @Sendable (DashboardRealtimeConnectionState) -> Void,
    onEvent: @escaping @MainActor @Sendable (DashboardRealtimeEvent) -> Void
  ) {
    self.webSocketURL = webSocketURL
    self.websiteID = websiteID
    self.organizationID = organizationID
    self.session = session
    self.onConnectionStateChange = onConnectionStateChange
    self.onEvent = onEvent
  }

  func connect() async {
    isIntentionalDisconnect = false
    reconnectAttempt = 0
    await updateConnectionState(.connecting)
    await establishConnection()
  }

  func disconnect() async {
    isIntentionalDisconnect = true
    reconnectTask?.cancel()
    reconnectTask = nil
    tearDown()
    await updateConnectionState(.disconnected)
  }

  func send(_ event: DashboardRealtimeClientEvent) async {
    guard let task else { return }

    do {
      let message = await MainActor.run {
        [
          "type": JSONValue.string(event.type),
          "payload": .object(event.payload(websiteID: websiteID, organizationID: organizationID)),
        ]
      }
      let data = try encoder.encode(message)
      let text = String(decoding: data, as: UTF8.self)
      try await task.send(.string(text))
    } catch {
      await emit(.serverError(message: error.localizedDescription))
    }
  }

  private func establishConnection() async {
    tearDown()

    let webSocketTask = session.webSocketTask(with: webSocketURL)
    webSocketTask.resume()
    task = webSocketTask

    receiveTask = Task { [weak self] in
      await self?.receiveLoop()
    }

    heartbeatTask = Task { [weak self] in
      await self?.heartbeatLoop()
    }
  }

  private func receiveLoop() async {
    guard let task else { return }

    while !Task.isCancelled {
      do {
        let message = try await task.receive()
        await handle(message)
      } catch {
        guard !Task.isCancelled else { return }
        await handleDisconnect(error: error)
        return
      }
    }
  }

  private func handle(_ message: URLSessionWebSocketTask.Message) async {
    let data: Data

    switch message {
    case .string(let text):
      guard text != "pong" else { return }
      data = Data(text.utf8)
    case .data(let payload):
      data = payload
    @unknown default:
      return
    }

    do {
      let event = try await MainActor.run {
        try DashboardRealtimeEvent(data: data, decoder: decoder)
      }

      if case .connectionEstablished(let payload) = event {
        reconnectAttempt = 0
        await updateConnectionState(.connected(connectionID: payload.connectionId))
      }

      await emit(event)
    } catch {
      await emit(.serverError(message: error.localizedDescription))
    }
  }

  private func heartbeatLoop() async {
    while !Task.isCancelled {
      do {
        try await Task.sleep(for: heartbeatInterval)
        try await task?.send(.string("ping"))
      } catch {
        guard !Task.isCancelled else { return }
        await handleDisconnect(error: error)
        return
      }
    }
  }

  private func handleDisconnect(error: Error) async {
    tearDown()

    guard !isIntentionalDisconnect else {
      await updateConnectionState(.disconnected)
      return
    }

    reconnectAttempt += 1
    await updateConnectionState(.failed(error.localizedDescription))

    let delaySeconds = min(pow(2, Double(min(reconnectAttempt, 5))), 30)
    reconnectTask?.cancel()
    reconnectTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .seconds(delaySeconds))
      } catch {
        return
      }

      await self?.updateConnectionState(.connecting)
      await self?.establishConnection()
    }
  }

  private func tearDown() {
    receiveTask?.cancel()
    heartbeatTask?.cancel()
    receiveTask = nil
    heartbeatTask = nil
    task?.cancel(with: .normalClosure, reason: nil)
    task = nil
  }

  private func emit(_ event: DashboardRealtimeEvent) async {
    await MainActor.run {
      onEvent(event)
    }
  }

  private func updateConnectionState(_ state: DashboardRealtimeConnectionState) async {
    await MainActor.run {
      onConnectionStateChange(state)
    }
  }
}
