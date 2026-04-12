import SwiftUI
import SFSafeSymbols

struct KnowledgeSectionHeader: View {
  @Bindable var store: KnowledgeStore
  let onCreate: (DashboardKnowledgeType) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Knowledge")
            .font(.title2.weight(.semibold))

          Text("\(store.totalCount) entries available")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 0)

        Menu {
          ForEach(DashboardKnowledgeType.allCases) { type in
            Button("New \(type.label)") {
              onCreate(type)
            }
          }
        } label: {
          Label("New", systemSymbol: .plus)
        }
        .menuStyle(.borderlessButton)
      }

      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 10) {
          Picker("Type", selection: $store.filterType) {
            Text("All Types")
              .tag(nil as DashboardKnowledgeType?)

            ForEach(DashboardKnowledgeType.allCases) { type in
              Text(type.label)
                .tag(Optional(type))
            }
          }

          Picker("Included", selection: $store.filterIncluded) {
            ForEach(DashboardKnowledgeIncludedFilter.allCases) { filter in
              Text(filter.label)
                .tag(filter)
            }
          }
        }

        TextField(
          "AI agent ID filter",
          text: Binding(
            get: { store.filterAIAgentID ?? "" },
            set: { store.filterAIAgentID = $0.dashboardNilIfEmpty }
          )
        )
        .textFieldStyle(.roundedBorder)

        TextField(
          "Link source ID filter",
          text: Binding(
            get: { store.filterLinkSourceID ?? "" },
            set: { store.filterLinkSourceID = $0.dashboardNilIfEmpty }
          )
        )
        .textFieldStyle(.roundedBorder)

        HStack(spacing: 10) {
          Stepper("Page size: \(store.pageSize)", value: $store.pageSize, in: 10...100, step: 10)

          Spacer(minLength: 0)

          Button("Clear Filters") {
            store.filterType = nil
            store.filterIncluded = .all
            store.filterAIAgentID = nil
            store.filterLinkSourceID = nil
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
    .background(.bar)
  }
}

struct KnowledgeRowView: View {
  let item: DashboardKnowledge

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text(item.titleText)
          .font(.headline)
          .lineLimit(2)

        Text(item.origin)
          .font(.caption)
          .foregroundStyle(.tertiary)
          .lineLimit(1)
      }

      Spacer(minLength: 0)

      VStack(alignment: .trailing, spacing: 6) {
        Text(item.type.label)
          .font(.caption.weight(.semibold))
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.quinary, in: .capsule)

        Text(item.isIncluded ? "Included" : "Excluded")
          .font(.caption2)
          .foregroundStyle(item.isIncluded ? .secondary : .tertiary)
      }
    }
  }
}

struct KnowledgePaginationFooter: View {
  @Bindable var store: KnowledgeStore

  var body: some View {
    HStack(spacing: 12) {
      Text("Page \(store.page)")
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)

      Text("\(store.items.count) shown")
        .font(.caption)
        .foregroundStyle(.tertiary)

      Spacer(minLength: 0)

      Button("Previous") {
        Task {
          await store.loadPreviousPage()
        }
      }
      .disabled(store.page <= 1 || store.isLoadingList)

      Button("Next") {
        Task {
          await store.loadNextPage()
        }
      }
      .disabled(!store.hasMore || store.isLoadingList)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 12)
    .background(.bar)
  }
}
