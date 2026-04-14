import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct KnowledgeListView: View {
  @Bindable var store: KnowledgeStore
  @Binding var selection: String?
  let onCreate: (DashboardKnowledgeType) -> Void
  let onEdit: (DashboardKnowledge) -> Void
  let onDelete: (DashboardKnowledge) async -> Void

  @State private var pendingDeleteItem: DashboardKnowledge?

  var body: some View {
    VStack(spacing: 0) {
      KnowledgeSectionHeader(store: store, onCreate: onCreate)

      List(store.items, selection: $selection) { item in
        KnowledgeRowView(item: item)
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
        if store.isLoadingList {
          ProgressView("Loading knowledge…")
        } else if store.items.isEmpty {
          ContentUnavailableView(
            "No knowledge yet",
            systemImage: SFSafeSymbols.SFSymbol.booksVertical.rawValue,
            description: Text("Knowledge sources and FAQs will appear here once loaded.")
          )
        }
      }
      .task(id: knowledgeQueryKey) {
        store.page = 1
        await store.refresh(page: 1)
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
  }

  private var knowledgeQueryKey: String {
    [
      store.filterType?.rawValue ?? "all",
      store.filterIncluded.rawValue,
      store.filterAIAgentID ?? "",
      store.filterLinkSourceID ?? "",
      String(store.pageSize),
    ].joined(separator: "|")
  }
}

struct KnowledgeDetailView: View {
  let item: DashboardKnowledge?
  @Binding var draft: DashboardKnowledgeEditorDraft?
  let errorMessage: String?
  let onSave: (DashboardKnowledgeEditorDraft) async -> Void
  let onCancelEditing: () -> Void
  let onEdit: (DashboardKnowledge) -> Void
  let onDelete: (DashboardKnowledge) async -> Void

  @State private var pendingDeleteItem: DashboardKnowledge?

  var body: some View {
    Group {
      if let draft {
        KnowledgeEditorView(
          draft: Binding(
            get: { draft },
            set: { self.draft = $0 }
          ),
          errorMessage: errorMessage,
          onSave: {
            Task {
              await onSave(draft)
            }
          },
          onCancel: onCancelEditing
        )
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
              PrototypeFact(label: "Type", value: item.type.label)
              PrototypeFact(label: "Origin", value: item.origin)
              PrototypeFact(label: "Included", value: item.isIncluded ? "Yes" : "No")
              PrototypeFact(label: "AI Agent ID", value: item.aiAgentId ?? "Shared")
              PrototypeFact(label: "Link Source ID", value: item.linkSourceId ?? "None")
              if let sourceURL = item.sourceUrl?.absoluteString {
                PrototypeFact(label: "Source URL", value: sourceURL)
              }
              if let sourceTitle = item.sourceTitle {
                PrototypeFact(label: "Source Title", value: sourceTitle)
              }
            }

            PrototypeInfoCard(title: "Storage") {
              PrototypeFact(label: "Size", value: "\(item.sizeBytes) bytes")
              PrototypeFact(label: "Created", value: item.createdAbsoluteText)
              PrototypeFact(label: "Updated", value: item.updatedAbsoluteText)
              PrototypeFact(label: "Content Hash", value: item.contentHash)
            }

            KnowledgePayloadCard(item: item)

            if let metadata = item.metadata, !metadata.isEmpty {
              PrototypeInfoCard(title: "Metadata") {
                ForEach(metadata.dashboardSortedEntries, id: \.0) { key, value in
                  PrototypeFact(label: key, value: value.dashboardDisplayText)
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
}
