import SwiftUI
import SFSafeSymbols

struct ContactListRow: View {
  let contact: DashboardContactListItem

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
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

      VStack(alignment: .trailing, spacing: 3) {
        contactRowTimestamp(
          title: "Seen",
          value: contact.lastSeenRelativeText,
          emphasized: true
        )

        contactRowTimestamp(
          title: "Created",
          value: contact.createdRelativeText,
          emphasized: false
        )
      }
    }
    .padding(.vertical, 4)
  }

  private func contactRowTimestamp(title: String, value: String, emphasized: Bool) -> some View {
    HStack(spacing: 4) {
      Text(title)
        .font(.caption2.weight(.medium))
        .foregroundStyle(.tertiary)

      Text(value)
        .font(emphasized ? .caption.weight(.medium) : .caption2)
        .foregroundStyle(emphasized ? .secondary : .tertiary)
    }
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
    VStack(alignment: .leading, spacing: 8) {
      Text("Contacts")
        .font(.title2.weight(.semibold))

      Text(contactsSubtitle(store: store))
        .font(.subheadline)
        .foregroundStyle(.secondary)

      HStack(spacing: 10) {
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
          ContactsHeaderControlLabel(
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
          ContactsHeaderControlLabel(
            title: "Visitors",
            value: store.visitorStatus.label,
            systemImage: .person2
          )
        }
      }
      .padding(.top, 4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
    .background(.bar)
  }
}

struct ContactsHeaderControlLabel: View {
  let title: String
  let value: String
  let systemImage: SFSymbol

  var body: some View {
    Label {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)

        Text(value)
          .font(.subheadline.weight(.medium))
          .lineLimit(1)
      }
    } icon: {
      Image(systemSymbol: systemImage)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(.quinary, in: .rect(cornerRadius: 12))
  }
}
