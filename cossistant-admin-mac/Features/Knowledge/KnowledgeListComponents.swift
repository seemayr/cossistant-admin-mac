import AppKit
import SwiftUI
import SFSafeSymbols
import UniformTypeIdentifiers
import CossistantAdmin

private let frontendKnowledgeTypes: [DashboardKnowledgeType] = [.faq, .article]

struct KnowledgeSectionHeader: View {
  @Bindable var store: KnowledgeStore
  let availableAIAgents: [DashboardWebsite.AIAgent]
  let onCreate: (DashboardKnowledgeType) -> Void
  let onExportFAQJSON: () async -> Void

  private var soleAvailableAIAgentID: String? {
    availableAIAgents.count == 1 ? availableAIAgents.first?.id : nil
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Knowledge")
            .font(.headline.weight(.semibold))

          Text("\(store.totalCount) entries available")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 0)

        HStack(spacing: 8) {
          Button {
            Task {
              await onExportFAQJSON()
            }
          } label: {
            Label("Export FAQs", systemSymbol: .squareAndArrowDown)
          }
          .disabled(store.isExportingFAQ)

          Menu {
            ForEach(frontendKnowledgeTypes) { type in
              Button("New \(type.label)") {
                onCreate(type)
              }
            }
          } label: {
            Label("New", systemSymbol: .plus)
          }
          .menuStyle(.borderlessButton)
        }
      }

      if let exportStatusMessage = store.exportStatusMessage {
        Label(exportStatusMessage, systemSymbol: .checkmarkCircle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 10) {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 150), spacing: 10, alignment: .leading)],
          alignment: .leading,
          spacing: 10
        ) {
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

        VStack(alignment: .leading, spacing: 10) {
          if soleAvailableAIAgentID == nil {
            Picker("Knowledge Scope", selection: $store.filterAIAgentScope) {
              ForEach(KnowledgeAIAgentScope.allCases) { scope in
                Text(scope.label)
                  .tag(scope)
              }
            }
            .pickerStyle(.segmented)

            if store.filterAIAgentScope == .specific {
              Picker(
                "AI Agent",
                selection: Binding(
                  get: {
                    store.filterSpecificAIAgentID ?? availableAIAgents.first?.id
                  },
                  set: { store.filterSpecificAIAgentID = $0 }
                )
              ) {
                ForEach(availableAIAgents) { agent in
                  Text(agent.displayName)
                    .tag(Optional(agent.id))
                }
              }
              .pickerStyle(.menu)
              .disabled(availableAIAgents.isEmpty)
            }
          }
        }
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 10) {
            Stepper("Page size: \(store.pageSize)", value: $store.pageSize, in: 10...100, step: 10)

            Spacer(minLength: 0)

            Button("Clear Filters") {
              store.showAllKnowledge(preferredAIAgentID: soleAvailableAIAgentID)
            }
          }

          VStack(alignment: .leading, spacing: 8) {
            Stepper("Page size: \(store.pageSize)", value: $store.pageSize, in: 10...100, step: 10)

            Button("Clear Filters") {
              store.showAllKnowledge(preferredAIAgentID: soleAvailableAIAgentID)
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(.bar)
  }
}

@MainActor
enum KnowledgeFAQExportFileSaveCoordinator {
  static func destinationURL() -> URL? {
    let panel = NSSavePanel()
    panel.canCreateDirectories = true
    panel.isExtensionHidden = false
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = defaultFilename

    guard panel.runModal() == .OK else {
      return nil
    }

    return panel.url
  }

  static func write(_ json: String, to destinationURL: URL) throws {
    guard let data = json.data(using: .utf8) else {
      throw KnowledgeFAQExportError.invalidEncoding
    }

    try data.write(to: destinationURL, options: [.atomic])
  }

  private static var defaultFilename: String {
    let timestamp = Self.filenameDateFormatter.string(from: .now)
    return "cossistant-faq-export-\(timestamp).json"
  }

  private static let filenameDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    return formatter
  }()
}

struct KnowledgeRowView: View {
  let item: DashboardKnowledge
  let aiAgentLabel: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text(item.titleText)
          .font(.body.weight(.medium))
          .lineLimit(2)

        Text(aiAgentLabel)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 0)

      VStack(alignment: .trailing, spacing: 6) {
        Text(item.type.label)
          .font(.caption.weight(.semibold))
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.quinary, in: .rect(cornerRadius: 6))

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

      Text("\(store.filteredItems.count) shown")
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
