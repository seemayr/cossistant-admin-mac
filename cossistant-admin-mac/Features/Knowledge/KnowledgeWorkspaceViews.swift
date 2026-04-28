import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct KnowledgeListView: View {
  @Bindable var store: KnowledgeStore
  let availableAIAgents: [DashboardWebsite.AIAgent]
  @Binding var selection: String?
  let onCreate: (DashboardKnowledgeType) -> Void
  let onEdit: (DashboardKnowledge) -> Void
  let onDelete: (DashboardKnowledge) async -> Void

  @State private var pendingDeleteItem: DashboardKnowledge?

  var body: some View {
    VStack(spacing: 0) {
      KnowledgeSectionHeader(
        store: store,
        availableAIAgents: availableAIAgents,
        onCreate: onCreate
      )

      List(store.filteredItems, selection: $selection) { item in
        KnowledgeRowView(
          item: item,
          aiAgentLabel: aiAgentLabel(for: item.aiAgentId)
        )
          .padding(.vertical, 4)
          .tag(item.id)
          .contextMenu {
            Button("Edit") {
              onEdit(item)
            }

            Button("Delete", role: .destructive) {
              pendingDeleteItem = item
            }
          }
      }
      .overlay {
        if !store.hasLoadedListOnce && store.items.isEmpty {
          ProgressView("Loading knowledge…")
        } else if store.isLoadingList && !store.items.isEmpty {
          ProgressView("Loading knowledge…")
        } else if store.filteredItems.isEmpty {
          ContentUnavailableView(
            store.hasActiveTitleSearch ? "No matching knowledge" : "No knowledge yet",
            systemImage: SFSafeSymbols.SFSymbol.booksVertical.rawValue,
            description: Text(
              store.hasActiveTitleSearch
                ? "Try a different title search or clear the search."
                : "Knowledge sources and FAQs will appear here once loaded."
            )
          )
        }
      }
      .confirmationDialog(
        "Delete knowledge entry?",
        isPresented: Binding(
          get: { pendingDeleteItem != nil },
          set: { isPresented in
            if !isPresented {
              pendingDeleteItem = nil
            }
          }
        ),
        titleVisibility: .visible
      ) {
        Button("Delete", role: .destructive) {
          guard let pendingDeleteItem else { return }
          Task {
            await onDelete(pendingDeleteItem)
            self.pendingDeleteItem = nil
          }
        }
      } message: {
        Text("This removes the selected knowledge entry from the workspace.")
      }

      KnowledgePaginationFooter(store: store)
    }
    .searchable(text: $store.searchText, prompt: "Search knowledge titles")
  }

  private func aiAgentLabel(for aiAgentID: String?) -> String {
    if let aiAgentID,
       let agent = availableAIAgents.first(where: { $0.id == aiAgentID }) {
      return "AI Agent • \(agent.displayName)"
    }

    if let aiAgentID {
      return "AI Agent • \(aiAgentID)"
    }

    return "Shared Knowledge"
  }
}

struct KnowledgeDetailView: View {
  let item: DashboardKnowledge?
  @Binding var draft: DashboardKnowledgeEditorDraft?
  let availableAIAgents: [DashboardWebsite.AIAgent]
  let isLoading: Bool
  let errorMessage: String?
  let onSave: (DashboardKnowledgeEditorDraft) async -> Void
  let onCancelEditing: () -> Void
  let onEdit: (DashboardKnowledge) -> Void
  let onOpenAIAgent: (String) -> Void
  let onDelete: (DashboardKnowledge) async -> Void

  @State private var pendingDeleteItem: DashboardKnowledge?

  var body: some View {
    Group {
      if draft != nil {
        KnowledgeEditorView(
          draft: Binding(
            get: { draft ?? DashboardKnowledgeEditorDraft.blank(type: .faq) },
            set: { draft = $0 }
          ),
          availableAIAgents: availableAIAgents,
          errorMessage: errorMessage,
          onSave: onSave,
          onCancel: onCancelEditing
        )
      } else if isLoading {
        ProgressView("Loading knowledge…")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let item {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
              VStack(alignment: .leading, spacing: 6) {
                Text(item.titleText)
                  .font(.largeTitle.weight(.semibold))

                Text(item.type.label)
                  .font(.headline)
                  .foregroundStyle(.secondary)
              }

              Spacer(minLength: 0)

              HStack(spacing: 10) {
                Button {
                  onEdit(item)
                } label: {
                  Label("Edit", systemSymbol: .pencil)
                }

                Button(role: .destructive) {
                  pendingDeleteItem = item
                } label: {
                  Label("Delete", systemSymbol: .trash)
                }
              }
              .labelStyle(.titleAndIcon)
            }

            PrototypeInfoCard(title: "Source") {
              KnowledgeDetailFact(label: "Type", value: item.type.label)
              KnowledgeDetailFact(label: "Included", value: item.isIncluded ? "Yes" : "No")
              KnowledgeDetailFact(label: "AI Agent", value: aiAgentLabel(for: item.aiAgentId))
              KnowledgeDetailFact(label: "Link Source ID", value: item.linkSourceId ?? "None")
              if let sourceURL = item.sourceUrl?.absoluteString {
                KnowledgeDetailFact(label: "Source URL", value: sourceURL)
              }
              if let sourceTitle = item.sourceTitle {
                KnowledgeDetailFact(label: "Source Title", value: sourceTitle)
              }
              if let aiAgentID = item.aiAgentId {
                Button("Open Agent") {
                  onOpenAIAgent(aiAgentID)
                }
              }
            }

            PrototypeInfoCard(title: "Storage") {
              KnowledgeDetailFact(label: "Size", value: "\(item.sizeBytes) bytes")
              KnowledgeDetailFact(label: "Created", value: item.createdAbsoluteText)
              KnowledgeDetailFact(label: "Updated", value: item.updatedAbsoluteText)
              KnowledgeDetailFact(label: "Content Hash", value: item.contentHash)
            }

            KnowledgePayloadCard(item: item)

            if let metadata = item.metadata, !metadata.isEmpty {
              PrototypeInfoCard(title: "Metadata") {
                ForEach(metadata.dashboardSortedEntries, id: \.0) { key, value in
                  KnowledgeDetailFact(label: key, value: value.dashboardDisplayText)
                }
              }
            }
          }
          .padding(24)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .confirmationDialog(
          "Delete knowledge entry?",
          isPresented: Binding(
            get: { pendingDeleteItem != nil },
            set: { isPresented in
              if !isPresented {
                pendingDeleteItem = nil
              }
            }
          ),
          titleVisibility: .visible
        ) {
          Button("Delete", role: .destructive) {
            guard let pendingDeleteItem else { return }
            Task {
              await onDelete(pendingDeleteItem)
              self.pendingDeleteItem = nil
            }
          }
        } message: {
          Text("This removes the selected knowledge entry from the workspace.")
        }
      } else {
        ContentUnavailableView(
          "Pick a knowledge item",
          systemImage: SFSafeSymbols.SFSymbol.booksVertical.rawValue,
          description: Text("Select an entry from the list to inspect its source and payload details.")
        )
      }
    }
  }

  private func aiAgentLabel(for aiAgentID: String?) -> String {
    if let aiAgentID,
       let agent = availableAIAgents.first(where: { $0.id == aiAgentID }) {
      return "\(agent.displayName) (\(aiAgentID))"
    }

    if let aiAgentID {
      return aiAgentID
    }

    return "Shared"
  }
}
