import Foundation
import Observation
import CossistantAdmin

@Observable @MainActor
final class AIAgentStore {
  private var configuration: DashboardConfiguration?

  var selectedAIAgent: DashboardAIAgent?
  var selectedTrainingStatus: DashboardAIAgentTrainingStatus?
  var isLoadingDetail = false
  var isRefreshingTrainingStatus = false
  var isStartingTraining = false
  var statusMessage: String?
  var errorMessage: String?

  func setConfiguration(_ configuration: DashboardConfiguration?) {
    self.configuration = configuration

    if configuration == nil {
      reset()
    }
  }

  func reset() {
    selectedAIAgent = nil
    selectedTrainingStatus = nil
    isLoadingDetail = false
    isRefreshingTrainingStatus = false
    isStartingTraining = false
    statusMessage = nil
    errorMessage = nil
  }

  func loadAIAgent(id: String) async {
    errorMessage = nil
    isLoadingDetail = true
    defer { isLoadingDetail = false }

    do {
      async let agent = backendClient().aiAgents.fetchAIAgent(id: id)
      async let trainingStatus = backendClient().aiAgents.fetchTrainingStatus(id: id)

      selectedAIAgent = try await agent
      selectedTrainingStatus = try await trainingStatus
      statusMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func refreshTrainingStatus(id: String, announcesRefresh: Bool = false) async {
    if announcesRefresh {
      statusMessage = "Refreshing training status…"
    }
    errorMessage = nil
    isRefreshingTrainingStatus = true
    defer { isRefreshingTrainingStatus = false }

    do {
      selectedTrainingStatus = try await backendClient().aiAgents.fetchTrainingStatus(id: id)
      if announcesRefresh {
        statusMessage = "Updated the training status."
      }
    } catch {
      errorMessage = error.localizedDescription
      if announcesRefresh {
        statusMessage = nil
      }
    }
  }

  func startTraining(id: String) async {
    errorMessage = nil
    isStartingTraining = true
    statusMessage = "Queueing AI agent training…"
    defer { isStartingTraining = false }

    do {
      let job = try await backendClient().aiAgents.startTraining(id: id)
      selectedTrainingStatus = try await backendClient().aiAgents.fetchTrainingStatus(id: id)
      statusMessage = trainingQueuedMessage(for: job)
    } catch {
      statusMessage = nil
      errorMessage = error.localizedDescription
    }
  }

  private func trainingQueuedMessage(for job: DashboardAIAgentTrainingJob) -> String {
    switch job.status {
    case .trainingOngoing:
      "Training queued. Current progress: \(job.progress)%."
    case .outOfDate:
      "Training request accepted. The agent still has out-of-date knowledge."
    case .trained:
      "Training request accepted."
    }
  }

  private func backendClient() throws -> CossistantAdminClient {
    guard let configuration else {
      throw StoreConfigurationError.notConfigured
    }

    return CossistantAdminClient(configuration: configuration)
  }
}
