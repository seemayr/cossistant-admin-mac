import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  func refreshRoute(_ route: WorkspaceRoute, in workspaceStore: WorkspaceStore) async {
    switch route {
    case .inbox:
      await refresh()
    case .statistics:
      await refresh()
    case .settings:
      break
    case .contacts:
      await contactsStore.refresh()
      if let selectedContactID = workspaceStore.selectedContactID {
        selectContact(selectedContactID, in: workspaceStore, force: true)
      }
    case .knowledge:
      await knowledgeStore.refresh()
      guard workspaceStore.knowledgeEditorDraft == nil,
            let selectedKnowledgeID = workspaceStore.selectedKnowledgeID else {
        return
      }
      selectKnowledge(selectedKnowledgeID, in: workspaceStore, force: true)
    case .aiAgents:
      guard let selectedAIAgentID = workspaceStore.selectedAIAgentID else { return }
      selectAIAgent(selectedAIAgentID, in: workspaceStore, force: true)
    case .faq:
      break
    case .aiSummarize:
      break
    case .aiAutoResolve:
      break
    case .aiFAQResolver:
      await reloadFAQResolverFAQs()
    }
  }

  func activateRoute(_ route: WorkspaceRoute, in workspaceStore: WorkspaceStore) async {
    switch route {
    case .inbox:
      break
    case .statistics:
      break
    case .settings:
      break
    case .contacts:
      guard modelCanRefreshContactsList else { return }
      await contactsStore.refresh()
    case .knowledge:
      knowledgeStore.showAllKnowledge(
        preferredAIAgentID: website?.availableAIAgents.count == 1
          ? website?.availableAIAgents.first?.id
          : nil,
        refreshAfterUpdate: false
      )
      guard modelCanRefreshKnowledgeList else { return }
      await knowledgeStore.refresh()
    case .aiAgents:
      if workspaceStore.selectedAIAgentID == nil {
        selectAIAgent(website?.availableAIAgents.first?.id, in: workspaceStore)
      }
    case .faq:
      break
    case .aiSummarize:
      break
    case .aiAutoResolve:
      break
    case .aiFAQResolver:
      ensureFAQResolverAIAgentSelection()
      if faqResolverStore.faqEntries.isEmpty {
        await reloadFAQResolverFAQs()
      }
    }
  }

  func selectContact(
    _ contactID: String?,
    in workspaceStore: WorkspaceStore,
    force: Bool = false
  ) {
    if !force,
       contactID == workspaceStore.selectedContactID,
       contactsStore.selectedContact?.id == contactID,
       !contactsStore.isLoadingDetail {
      return
    }

    selectedContactLoadTask?.cancel()
    selectedContactLoadTask = nil
    workspaceStore.selectedContactID = contactID
    contactsStore.errorMessage = nil

    guard let contactID else {
      contactsStore.selectedContact = nil
      contactsStore.selectedContactOrganization = nil
      contactsStore.isLoadingDetail = false
      return
    }

    contactsStore.selectedContact = nil
    contactsStore.selectedContactOrganization = nil
    contactsStore.isLoadingDetail = true

    selectedContactLoadTask = Task { [weak self] in
      guard let self else { return }

      defer {
        if workspaceStore.selectedContactID == contactID {
          self.contactsStore.isLoadingDetail = false
        }
      }

      do {
        let contact = try await self.backendClient.contacts.fetchContact(id: contactID)
        guard workspaceStore.selectedContactID == contactID else { return }
        self.contactsStore.selectedContact = contact
      } catch {
        guard workspaceStore.selectedContactID == contactID else { return }
        guard !self.isIgnorableCancellation(error) else { return }
        self.contactsStore.errorMessage = error.localizedDescription
      }
    }
  }

  func selectKnowledge(
    _ knowledgeID: String?,
    in workspaceStore: WorkspaceStore,
    force: Bool = false
  ) {
    if !force,
       knowledgeID == workspaceStore.selectedKnowledgeID,
       knowledgeStore.selectedKnowledge?.id == knowledgeID,
       workspaceStore.knowledgeEditorDraft == nil,
       !knowledgeStore.isLoadingDetail {
      return
    }

    selectedKnowledgeLoadTask?.cancel()
    selectedKnowledgeLoadTask = nil
    workspaceStore.selectedKnowledgeID = knowledgeID
    workspaceStore.knowledgeEditorDraft = nil
    knowledgeStore.errorMessage = nil

    guard let knowledgeID else {
      knowledgeStore.selectedKnowledge = nil
      knowledgeStore.isLoadingDetail = false
      return
    }

    knowledgeStore.selectedKnowledge = nil
    knowledgeStore.isLoadingDetail = true

    selectedKnowledgeLoadTask = Task { [weak self] in
      guard let self else { return }

      defer {
        if workspaceStore.selectedKnowledgeID == knowledgeID {
          self.knowledgeStore.isLoadingDetail = false
        }
      }

      do {
        let knowledge = try await self.backendClient.knowledge.fetchKnowledge(id: knowledgeID)
        guard workspaceStore.selectedKnowledgeID == knowledgeID else { return }
        self.knowledgeStore.selectedKnowledge = knowledge
      } catch {
        guard workspaceStore.selectedKnowledgeID == knowledgeID else { return }
        guard !self.isIgnorableCancellation(error) else { return }
        self.knowledgeStore.errorMessage = error.localizedDescription
      }
    }
  }

  func startCreatingKnowledge(_ type: DashboardKnowledgeType, in workspaceStore: WorkspaceStore) {
    selectedKnowledgeLoadTask?.cancel()
    selectedKnowledgeLoadTask = nil
    workspaceStore.selectedKnowledgeID = nil
    knowledgeStore.selectedKnowledge = nil
    knowledgeStore.isLoadingDetail = false

    var draft = DashboardKnowledgeEditorDraft.blank(type: type)
    if website?.availableAIAgents.count == 1 {
      draft.aiAgentID = website?.availableAIAgents.first?.id ?? ""
    }
    workspaceStore.knowledgeEditorDraft = draft
  }

  func startEditingKnowledge(_ item: DashboardKnowledge, in workspaceStore: WorkspaceStore) {
    selectedKnowledgeLoadTask?.cancel()
    selectedKnowledgeLoadTask = nil
    workspaceStore.selectedKnowledgeID = item.id
    knowledgeStore.selectedKnowledge = item
    knowledgeStore.isLoadingDetail = false
    workspaceStore.knowledgeEditorDraft = DashboardKnowledgeEditorDraft(item: item)
  }

  func presentKnowledge(_ item: DashboardKnowledge, in workspaceStore: WorkspaceStore) {
    selectedKnowledgeLoadTask?.cancel()
    selectedKnowledgeLoadTask = nil
    workspaceStore.selectedKnowledgeID = item.id
    workspaceStore.knowledgeEditorDraft = nil
    knowledgeStore.selectedKnowledge = item
    knowledgeStore.isLoadingDetail = false
    knowledgeStore.errorMessage = nil
  }

  func removeKnowledge(_ item: DashboardKnowledge, in workspaceStore: WorkspaceStore) async {
    await knowledgeStore.deleteKnowledge(id: item.id)

    if workspaceStore.selectedKnowledgeID == item.id {
      selectKnowledge(nil, in: workspaceStore)
    }

    if workspaceStore.knowledgeEditorDraft?.id == item.id {
      workspaceStore.knowledgeEditorDraft = nil
    }
  }

  func selectAIAgent(
    _ aiAgentID: String?,
    in workspaceStore: WorkspaceStore,
    force: Bool = false
  ) {
    if !force,
       aiAgentID == workspaceStore.selectedAIAgentID,
       aiAgentStore.selectedAIAgent?.id == aiAgentID,
       !aiAgentStore.isLoadingDetail {
      return
    }

    selectedAIAgentLoadTask?.cancel()
    selectedAIAgentLoadTask = nil
    workspaceStore.selectedAIAgentID = aiAgentID
    aiAgentStore.errorMessage = nil
    aiAgentStore.statusMessage = nil

    guard let aiAgentID else {
      aiAgentStore.selectedAIAgent = nil
      aiAgentStore.selectedTrainingStatus = nil
      aiAgentStore.isLoadingDetail = false
      return
    }

    aiAgentStore.selectedAIAgent = nil
    aiAgentStore.selectedTrainingStatus = nil
    aiAgentStore.isLoadingDetail = true

    selectedAIAgentLoadTask = Task { [weak self] in
      guard let self else { return }

      defer {
        if workspaceStore.selectedAIAgentID == aiAgentID {
          self.aiAgentStore.isLoadingDetail = false
        }
      }

      do {
        let configuration = self.configuration
        async let agent: DashboardAIAgent = {
          let client = CossistantAdminClient(configuration: configuration)
          return try await client.aiAgents.fetchAIAgent(id: aiAgentID)
        }()
        async let trainingStatus: DashboardAIAgentTrainingStatus = {
          let client = CossistantAdminClient(configuration: configuration)
          return try await client.aiAgents.fetchTrainingStatus(id: aiAgentID)
        }()
        let (resolvedAgent, resolvedTrainingStatus) = try await (agent, trainingStatus)

        guard workspaceStore.selectedAIAgentID == aiAgentID else { return }
        self.aiAgentStore.selectedAIAgent = resolvedAgent
        self.aiAgentStore.selectedTrainingStatus = resolvedTrainingStatus
      } catch {
        guard workspaceStore.selectedAIAgentID == aiAgentID else { return }
        guard !self.isIgnorableCancellation(error) else { return }
        self.aiAgentStore.errorMessage = error.localizedDescription
      }
    }
  }

  private var modelCanRefreshContactsList: Bool {
    contactsStore.items.isEmpty && !contactsStore.isLoadingList
  }

  private var modelCanRefreshKnowledgeList: Bool {
    knowledgeStore.items.isEmpty && !knowledgeStore.isLoadingList
  }
}
