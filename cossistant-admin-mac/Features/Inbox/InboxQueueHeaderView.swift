import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct InboxQueueHeaderView: View {
  @Bindable var store: InboxStore
  let scope: InboxScope

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(scope.title)
        .font(.headline.weight(.semibold))

      Text(queueSummary)
        .font(.caption)
        .foregroundStyle(.secondary)

      ViewThatFits(in: .horizontal) {
        controlRow
        ScrollView(.horizontal, showsIndicators: false) {
          controlRow
        }
      }
      .padding(.top, 4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(.bar)
  }

  private var controlRow: some View {
    HStack(spacing: 8) {
      Menu {
        Picker("Sort by", selection: $store.sortMode) {
          ForEach(InboxSortMode.allCases) { mode in
            Text(mode.label)
              .tag(mode)
          }
        }
      } label: {
        HeaderControlLabel(
          title: "Sort",
          value: store.sortMode.label,
          systemImage: .arrowUpArrowDown
        )
      }

      Menu {
        Picker("Priority", selection: $store.priorityFilter) {
          ForEach(InboxPriorityFilter.allCases) { filter in
            Text(filter.label)
              .tag(filter)
          }
        }

        Picker("Sentiment", selection: $store.sentimentFilter) {
          ForEach(InboxSentimentFilter.allCases) { filter in
            Text(filter.label)
              .tag(filter)
          }
        }

        Picker("FAQ Resolver", selection: $store.faqResolverHandlingFilter) {
          ForEach(InboxFAQResolverHandlingFilter.allCases) { filter in
            Text(filter.label)
              .tag(filter)
          }
        }

        if !store.availableChannelFilters.isEmpty {
          Menu("Channel") {
            Button {
              store.channelFilter = nil
            } label: {
              metadataMenuLabel(
                "Any Channel",
                isSelected: store.channelFilter == nil
              )
            }

            ForEach(store.availableChannelFilters) { option in
              Button {
                store.channelFilter = option.value
              } label: {
                metadataMenuLabel(
                  option.label,
                  isSelected: store.channelFilter == option.value
                )
              }
            }
          }
        }

        if !store.availableAppVersionFilters.isEmpty {
          Menu("App Version") {
            Button {
              store.appVersionFilters = []
            } label: {
              metadataMenuLabel(
                "Any Version",
                isSelected: store.appVersionFilters.isEmpty
              )
            }

            ForEach(store.availableAppVersionFilters) { option in
              Toggle(
                option.label,
                isOn: Binding(
                  get: {
                    store.appVersionFilters.contains(option.value)
                  },
                  set: { isSelected in
                    store.setAppVersionFilter(option.value, isSelected: isSelected)
                  }
                )
              )
            }
          }
        }

        if !store.availableMetadataFilters.isEmpty {
          Menu("Metadata") {
            ForEach(store.availableMetadataFilters) { section in
              Menu(section.label) {
                Button {
                  store.setMetadataFilter(nil, for: section.key)
                } label: {
                  metadataMenuLabel(
                    "Any \(section.label)",
                    isSelected: store.selectedMetadataValue(for: section.key) == nil
                  )
                }

                ForEach(section.options) { option in
                  Button {
                    store.setMetadataFilter(option.value, for: section.key)
                  } label: {
                    metadataMenuLabel(
                      option.label,
                      isSelected: store.selectedMetadataValue(for: section.key) == option.value
                    )
                  }
                }
              }
            }
          }
        }

        Divider()

        Toggle("Previously opened", isOn: $store.onlyPreviouslyOpenedConversations)
        Toggle("Only needs team", isOn: $store.onlyTeamActionNeededConversations)
        Toggle("Hide seen conversations", isOn: $store.hideSeenConversations)
        Toggle("Hide empty conversations", isOn: $store.hideEmptyConversations)

        Divider()

        Toggle("Use summary previews", isOn: $store.showsMetadataSummaryPreviews)

        if store.hasActiveConversationFilters {
          Divider()

          Button("Clear Filters") {
            store.clearFilters()
          }
        }
      } label: {
        HeaderControlLabel(
          title: "Filter",
          value: filterSummary,
          systemImage: .line3HorizontalDecreaseCircle
        )
      }
    }
  }

  private var queueSummary: String {
    let shown = store.shownConversationCount(for: scope)
    let total = store.conversationCount(for: scope)

    if total == 0 {
      return "No conversations match this queue right now."
    }

    if shown == total {
      return "\(total) conversations in this queue"
    }

    return "\(shown) of \(total) conversations shown"
  }

  private var filterSummary: String {
    let values = [
      store.priorityFilter == .all ? nil : store.priorityFilter.label,
      store.sentimentFilter == .all ? nil : store.sentimentFilter.label,
      store.faqResolverHandlingFilter == .all ? nil : store.faqResolverHandlingFilter.label,
      store.channelFilter.map { "Channel: \(InboxChannelFilterOption(value: $0).label)" },
      appVersionFilterSummary,
      metadataFilterSummary,
      store.onlyPreviouslyOpenedConversations ? "Previously Opened" : nil,
      store.onlyTeamActionNeededConversations ? "Needs Team" : nil,
      store.hideSeenConversations ? "Hide Seen" : nil,
      store.hideEmptyConversations ? "Has Messages" : nil,
      store.showsMetadataSummaryPreviews ? "Summaries" : nil,
    ]
      .compactMap { $0 }

    if values.isEmpty {
      return "All"
    }

    return values.joined(separator: " • ")
  }

  private var metadataFilterSummary: String? {
    let values: [String] = store.availableMetadataFilters.compactMap { section in
      guard let selectedValue = store.selectedMetadataValue(for: section.key) else {
        return nil
      }

      return "\(section.label): \(selectedValue.dashboardDisplayText)"
    }

    guard !values.isEmpty else { return nil }
    return values.joined(separator: " • ")
  }

  private var appVersionFilterSummary: String? {
    guard !store.appVersionFilters.isEmpty else { return nil }

    let values = store.appVersionFilters.sorted {
      $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
    }

    return "Version: \(values.joined(separator: ", "))"
  }

  private func metadataMenuLabel(_ title: String, isSelected: Bool) -> some View {
    Group {
      if isSelected {
        Label(title, systemSymbol: .checkmark)
      } else {
        Text(title)
      }
    }
  }
}
