import SwiftUI
import CossistantAdmin

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
      .listStyle(.inset(alternatesRowBackgrounds: false))
      .overlay {
        if store.isLoadingList {
          ProgressView("Loading contacts…")
        } else if store.items.isEmpty {
          if store.searchText.isEmpty {
            ContactsEmptyState()
          } else {
            ContentUnavailableView.search(text: store.searchText)
          }
        }
      }
    }
    .searchable(text: $store.searchText, prompt: "Search contacts, email, metadata")
    .navigationTitle("Contacts")
  }
}
