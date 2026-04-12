import SwiftUI

struct ContactsListView: View {
  @Bindable var store: ContactsStore
  @Binding var selection: String?

  var body: some View {
    VStack(spacing: 0) {
      ContactsSectionHeader(store: store)

      List(store.items, selection: $selection) { contact in
        ContactListRow(contact: contact)
          .tag(contact.id)
      }
      .overlay {
        if store.isLoadingList {
          ProgressView("Loading contacts…")
        } else if store.items.isEmpty {
          ContactsEmptyState()
        }
      }
    }
    .searchable(text: $store.searchText, prompt: "Search contacts, email, metadata")
    .task(id: contactsQueryKey) {
      if !store.searchText.isEmpty {
        try? await Task.sleep(for: .milliseconds(250))
      }

      guard !Task.isCancelled else { return }
      await store.refresh()
    }
  }

  private var contactsQueryKey: String {
    [
      store.searchText,
      store.sortBy.rawValue,
      store.sortOrder.rawValue,
      store.visitorStatus.rawValue,
    ].joined(separator: "|")
  }
}
