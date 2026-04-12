import SwiftUI
import SFSafeSymbols

struct InboxQueueView: View {
  @Bindable var model: WorkspaceModel
  @Bindable var store: InboxStore
  let scope: InboxScope
  @Binding var selection: DashboardConversation.ID?

  var body: some View {
    VStack(spacing: 0) {
      InboxQueueHeaderView(model: model, store: store, scope: scope)

      List(displayedConversations, selection: $selection) { conversation in
        InboxConversationRow(
          model: model,
          conversation: conversation,
          visitorPresence: model.visitorPresence(for: conversation.visitorId)
        )
        .tag(conversation.id)
      }
      .listStyle(.inset(alternatesRowBackgrounds: false))
      .overlay {
        if displayedConversations.isEmpty {
          if store.searchText.isEmpty, !store.hasActiveConversationFilters {
            ContentUnavailableView(
              "No conversations yet",
              systemImage: scope.systemSymbol.rawValue,
              description: Text("This queue is empty right now.")
            )
          } else {
            ContentUnavailableView.search(text: store.searchText)
          }
        }
      }

      if store.canLoadMore {
        HStack {
          Spacer()

          Button {
            Task {
              await model.loadMoreConversations()
            }
          } label: {
            Label(store.isLoadingMore ? "Loading…" : "Load More", systemSymbol: .ellipsisCircle)
          }
          .disabled(store.isLoadingMore)
        }
        .padding(14)
        .background(.bar)
      }
    }
    .searchable(text: $store.searchText, prompt: "Search conversations")
  }

  private var displayedConversations: [DashboardConversation] {
    let filteredConversations = scopedConversations

    guard let selection,
          let selectedConversation = model.selectedConversation,
          selectedConversation.id == selection,
          !filteredConversations.contains(where: { $0.id == selectedConversation.id }) else {
      return filteredConversations
    }

    return [selectedConversation] + filteredConversations
  }

  private var scopedConversations: [DashboardConversation] {
    model.conversations(in: scope)
  }
}
