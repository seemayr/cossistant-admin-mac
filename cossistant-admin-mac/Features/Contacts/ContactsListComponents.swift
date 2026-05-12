import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct ContactListRow: View {
  let contact: DashboardContactListItem

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      AvatarPreviewButton(
        name: contact.displayName,
        imageURL: contact.image,
        seed: contact.avatarSeed,
        size: 34
      )

      VStack(alignment: .leading, spacing: 6) {
        Text(contact.displayName)
          .font(.headline)
          .lineLimit(1)

        Text(contact.email ?? contact.contactOrganizationName ?? "No email yet")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 0)

      Text(contact.lastSeenRelativeText)
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 4)
  }
}

struct ContactsEmptyState: View {
  var body: some View {
    ContentUnavailableView(
      "No contacts yet",
      systemImage: SFSymbol.person2.rawValue,
      description: Text("Contacts will appear here once the workspace loads them from the API.")
    )
  }
}

private func contactsSubtitle(store: ContactsStore) -> String {
  if store.totalCount == 0 {
    return "No contacts match the current search."
  }

  return "\(store.totalCount) contacts available"
}

struct ContactsSectionHeader: View {
  @Bindable var store: ContactsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Contacts")
        .font(.headline.weight(.semibold))

      Text(contactsSubtitle(store: store))
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
        Picker("Sort by", selection: $store.sortBy) {
          ForEach(DashboardContactSortBy.allCases) { sortBy in
            Text(sortBy.label)
              .tag(sortBy)
          }
        }

        Picker("Order", selection: $store.sortOrder) {
          ForEach(DashboardSortOrder.allCases) { sortOrder in
            Text(sortOrder.label)
              .tag(sortOrder)
          }
        }
      } label: {
        HeaderControlLabel(
          title: "Sort",
          value: store.sortBy.label,
          systemImage: .arrowUpArrowDown
        )
      }

      Menu {
        Picker("Visitors", selection: $store.visitorStatus) {
          ForEach(DashboardContactVisitorStatus.allCases) { status in
            Text(status.label)
              .tag(status)
          }
        }
      } label: {
        HeaderControlLabel(
          title: "Visitors",
          value: store.visitorStatus.label,
          systemImage: .person2
        )
      }
    }
  }
}
