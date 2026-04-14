import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct SidebarView: View {
  @Bindable var model: WorkspaceModel
  @Bindable var inboxStore: InboxStore

  var body: some View {
    List(selection: $model.selectedConversationID) {
      contextSection
      inboxSection
    }
    .navigationTitle("Cossistant")
    .searchable(text: $inboxStore.searchText, prompt: "Search inbox")
  }

  private var contextSection: some View {
    Section("Connected Website") {
      SidebarStatRow(
        label: "Open",
        value: inboxStore.conversations.filter { $0.status == .open }.count,
        tint: .green
      )

      SidebarStatRow(
        label: "Resolved",
        value: inboxStore.conversations.filter { $0.status == .resolved }.count,
        tint: .secondary
      )

      SidebarStatRow(
        label: "Spam",
        value: inboxStore.conversations.filter { $0.status == .spam }.count,
        tint: .red
      )

      if let website = model.website {
        VStack(alignment: .leading, spacing: 6) {
          Text(website.name)
            .font(.headline)

          if let domain = website.domain, !domain.isEmpty {
            Text(domain)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Text(model.connectionSummary)
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
      }
    }
  }

  private var inboxSection: some View {
    Section("Inbox") {
      ForEach(inboxStore.filteredConversations) { conversation in
        NavigationLink(value: conversation.id) {
          ConversationRowView(conversation: conversation)
        }
      }

      if inboxStore.filteredConversations.isEmpty {
        ContentUnavailableView.search(text: inboxStore.searchText)
          .listRowBackground(Color.clear)
      }

      if inboxStore.canLoadMore {
        Button {
          Task {
            await model.loadMoreConversations()
          }
        } label: {
          HStack {
            Text(inboxStore.isLoadingMore ? "Loading…" : "Load More")
            Spacer()
            Image(systemSymbol: .ellipsisCircle)
          }
        }
      }
    }
  }
}

private struct SidebarStatRow: View {
  let label: String
  let value: Int
  let tint: Color

  var body: some View {
    HStack {
      Label(label, systemSymbol: .circleFill)
        .symbolRenderingMode(.palette)
        .foregroundStyle(tint, tint.opacity(0.35))

      Spacer()

      Text(value, format: .number)
        .font(.headline)
        .foregroundStyle(.secondary)
    }
  }
}

private struct ConversationRowView: View {
  let conversation: DashboardConversation

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(conversation.displayTitle)
          .font(.headline)
          .lineLimit(1)

        Spacer(minLength: 0)
      }

      Text("\(conversation.visitorDisplayName) • \(conversation.channelLabel)")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)

      Text(conversation.previewText)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(2)

      HStack(spacing: 8) {
        Label(conversation.status.label, systemSymbol: .circleFill)
          .foregroundStyle(conversation.status.tint)

        Label(conversation.priority.label, systemSymbol: .flagFill)
          .foregroundStyle(conversation.priority.tint)

        Spacer(minLength: 0)

        Text(conversation.lastActivityRelativeText)
          .foregroundStyle(.tertiary)

        Label(conversation.visitorShortID, systemImage: "person.text.rectangle")
          .foregroundStyle(.tertiary)
      }
      .font(.caption)
    }
    .padding(.vertical, 4)
  }
}
