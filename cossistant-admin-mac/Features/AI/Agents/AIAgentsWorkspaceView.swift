import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct AIAgentListView: View {
  let agents: [DashboardWebsite.AIAgent]
  @Binding var selection: String?

  var body: some View {
    List(agents, selection: $selection) { agent in
      HStack(spacing: 12) {
        agentAvatar(agent)

        VStack(alignment: .leading, spacing: 4) {
          Text(agent.displayName)
            .font(.headline)

          Text(agent.id)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .padding(.vertical, 4)
      .tag(agent.id)
    }
    .listStyle(.inset(alternatesRowBackgrounds: false))
    .overlay {
      if agents.isEmpty {
        ContentUnavailableView(
          "No AI agents",
          systemImage: SFSymbol.sparkles.rawValue,
          description: Text("This workspace does not expose any AI agents yet.")
        )
      }
    }
    .navigationTitle("AI Agents")
  }

  @ViewBuilder
  private func agentAvatar(_ agent: DashboardWebsite.AIAgent) -> some View {
    if let imageURL = agent.image {
      AsyncImage(url: imageURL) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        default:
          Image(systemSymbol: .sparkles)
            .resizable()
            .scaledToFit()
            .padding(8)
            .foregroundStyle(.secondary)
        }
      }
      .frame(width: 34, height: 34)
      .background(.quinary, in: .circle)
      .clipShape(.circle)
    } else {
      Image(systemSymbol: .sparkles)
        .frame(width: 34, height: 34)
        .background(.quinary, in: .circle)
        .foregroundStyle(.secondary)
    }
  }
}

struct AIAgentDetailView: View {
  @Bindable var store: AIAgentStore
  let summary: DashboardWebsite.AIAgent?
  let onRefresh: () -> Void
  let onStartTraining: () -> Void

  var body: some View {
    Group {
      if let summary {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            header(summary: summary)

            if let status = store.statusMessage {
              Label(status, systemSymbol: .clockArrowTriangleheadCounterclockwiseRotate90)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let error = store.errorMessage {
              Label(error, systemSymbol: .exclamationmarkTriangleFill)
                .font(.subheadline)
                .foregroundStyle(.red)
            }

            if store.isLoadingDetail {
              ProgressView("Loading AI agent…")
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let agent = store.selectedAIAgent,
                      let trainingStatus = store.selectedTrainingStatus {
              overviewCard(agent: agent)
              trainingCard(agentID: agent.id, trainingStatus: trainingStatus)
            } else {
              ContentUnavailableView(
                "AI agent details unavailable",
                systemImage: SFSymbol.sparkles.rawValue,
                description: Text("Refresh the selected agent to load its configuration and training state.")
              )
            }
          }
          .padding(24)
          .frame(maxWidth: 980, alignment: .leading)
          .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .task(id: pollingKey) {
          guard let agentID = store.selectedAIAgent?.id,
                store.selectedTrainingStatus?.isTrainingInProgress == true else {
            return
          }

          while !Task.isCancelled,
                store.selectedAIAgent?.id == agentID,
                store.selectedTrainingStatus?.isTrainingInProgress == true {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await store.refreshTrainingStatus(id: agentID)
          }
        }
      } else {
        ContentUnavailableView(
          "Pick an AI agent",
          systemImage: SFSymbol.sparkles.rawValue,
          description: Text("Select an AI agent from the list to inspect its training status and knowledge setup.")
        )
      }
    }
  }

  private var pollingKey: String {
    guard let agentID = store.selectedAIAgent?.id else {
      return "none"
    }

    let progress = store.selectedTrainingStatus?.progress ?? -1
    let isInProgress = store.selectedTrainingStatus?.isTrainingInProgress == true
    return "\(agentID)|\(progress)|\(isInProgress)"
  }

  private func header(summary: DashboardWebsite.AIAgent) -> some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        Text(summary.displayName)
          .font(.largeTitle.weight(.semibold))

        Text(summary.id)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)

      HStack(spacing: 10) {
        Button {
          onRefresh()
        } label: {
          Label(store.isLoadingDetail ? "Refreshing…" : "Refresh", systemSymbol: .arrowClockwise)
        }
        .disabled(store.isLoadingDetail)

        Button {
          onStartTraining()
        } label: {
          Label(trainingButtonTitle, systemSymbol: .sparkles)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isTrainingButtonDisabled)
      }
    }
  }

  private var trainingButtonTitle: String {
    if store.isStartingTraining {
      return "Starting…"
    }

    return "Train Agent"
  }

  private var isTrainingButtonDisabled: Bool {
    store.isStartingTraining
      || store.isLoadingDetail
      || store.selectedTrainingStatus?.isTrainingInProgress == true
  }

  private func overviewCard(agent: DashboardAIAgent) -> some View {
    PrototypeInfoCard(title: "Overview") {
      PrototypeFact(label: "Description", value: agent.description ?? "None")
      PrototypeFact(label: "Model", value: agent.model)
      PrototypeFact(label: "Temperature", value: agent.temperature.map { "\($0)" } ?? "Default")
      PrototypeFact(
        label: "Max Output Tokens",
        value: agent.maxOutputTokens.map(String.init) ?? "Default"
      )
      PrototypeFact(label: "Active", value: agent.isActive ? "Yes" : "No")
      PrototypeFact(label: "Usage Count", value: String(agent.usageCount))
      PrototypeFact(
        label: "Last Used",
        value: agent.lastUsedAtDate?.formatted(.dateTime.year().month().day().hour().minute()) ?? "Never"
      )
      PrototypeFact(
        label: "Onboarding Completed",
        value: agent.onboardingCompletedAtDate?.formatted(.dateTime.year().month().day().hour().minute()) ?? "No"
      )
      PrototypeFact(
        label: "Goals",
        value: (agent.goals ?? []).isEmpty ? "None" : (agent.goals ?? []).joined(separator: ", ")
      )
      KnowledgeTextBlock(title: "Base Prompt", text: agent.basePrompt)
    }
  }

  private func trainingCard(
    agentID: String,
    trainingStatus: DashboardAIAgentTrainingStatus
  ) -> some View {
    PrototypeInfoCard(title: "Training") {
      HStack(alignment: .center, spacing: 14) {
        RowTag(
          title: trainingStatus.publicStatusLabel,
          systemSymbol: .sparkles,
          tint: trainingStatus.publicStatusTint
        )
        RowTag(
          title: trainingStatus.internalStatusLabel,
          systemSymbol: .gearshape2,
          tint: .secondary
        )
        Spacer(minLength: 0)
        if store.isRefreshingTrainingStatus {
          ProgressView()
            .controlSize(.small)
        }
      }
      .lineLimit(1)

      ProgressView(value: Double(trainingStatus.progress), total: 100) {
        Text("Progress")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      } currentValueLabel: {
        Text("\(trainingStatus.progress)%")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      PrototypeFact(label: "Updated Sources", value: String(trainingStatus.updatedSourcesCount))
      PrototypeFact(
        label: "Trained Items",
        value: trainingStatus.trainedItemsCount.map(String.init) ?? "Unknown"
      )
      PrototypeFact(
        label: "Last Trained",
        value: trainingStatus.lastTrainedAtDate?.formatted(.dateTime.year().month().day().hour().minute()) ?? "Never"
      )
      PrototypeFact(
        label: "Training Started",
        value: trainingStatus.trainingStartedAtDate?.formatted(.dateTime.year().month().day().hour().minute()) ?? "Not running"
      )
      PrototypeFact(
        label: "Cooldown Ends",
        value: trainingStatus.canTrainAtDate?.formatted(.dateTime.year().month().day().hour().minute()) ?? "Ready"
      )
      PrototypeFact(label: "Agent ID", value: agentID)

      if let lastError = trainingStatus.lastError, !lastError.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("Last Error")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(lastError)
            .font(.body.monospaced())
            .foregroundStyle(.red)
        }
      }
    }
  }
}

private extension DashboardAIAgentTrainingStatus {
  var publicStatusLabel: String {
    switch status {
    case .outOfDate:
      "Out of Date"
    case .trained:
      "Trained"
    case .trainingOngoing:
      "Training Ongoing"
    }
  }

  var internalStatusLabel: String {
    switch internalStatus {
    case .idle:
      "Idle"
    case .pending:
      "Pending"
    case .training:
      "Training"
    case .completed:
      "Completed"
    case .failed:
      "Failed"
    }
  }

  var publicStatusTint: Color {
    switch status {
    case .outOfDate:
      .orange
    case .trained:
      .green
    case .trainingOngoing:
      .blue
    }
  }
}
