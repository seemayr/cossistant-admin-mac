import SwiftUI
import SFSafeSymbols

struct ContactsListView: View {
  @Bindable var store: ContactsStore
  @Binding var selection: String?

  var body: some View {
    VStack(spacing: 0) {
      ContactsSectionHeader(store: store)

      List(store.items, selection: $selection) { contact in
        HStack(alignment: .top, spacing: 12) {
          DashboardAvatarPreviewButton(
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
        .tag(contact.id)
      }
      .overlay {
        if store.isLoadingList {
          ProgressView("Loading contacts…")
        } else if store.items.isEmpty {
          ContentUnavailableView(
            "No contacts yet",
            systemImage: SFSymbol.person2.rawValue,
            description: Text("Contacts will appear here once the workspace loads them from the API.")
          )
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

struct ContactDetailPrototypeView: View {
  @Bindable var store: ContactsStore
  let contact: DashboardContact?
  let listItem: DashboardContactListItem?

  @State private var notesDraft = ""
  @State private var isSavingNotes = false
  @State private var organizationEditorDraft = ContactOrganizationEditorDraft()
  @State private var isPresentingOrganizationEditor = false

  var body: some View {
    Group {
      if let contact {
        contactDetailContent(contact)
      } else {
        ContentUnavailableView(
          "Pick a contact",
          systemImage: SFSymbol.person2.rawValue,
          description: Text("Select a contact from the list to inspect identity and metadata.")
        )
      }
    }
    .task(id: contact?.id) {
      notesDraft = notesText(for: contact)
    }
    .task(id: contact?.contactOrganizationId) {
      guard let organizationID = contact?.contactOrganizationId else {
        store.selectedContactOrganization = nil
        return
      }

      if store.selectedContactOrganization?.id != organizationID {
        await store.loadContactOrganization(id: organizationID)
      }
    }
    .sheet(isPresented: $isPresentingOrganizationEditor) {
      ContactOrganizationEditorSheet(
        draft: $organizationEditorDraft,
        isSaving: store.isLoadingDetail,
        onSave: { draft in
          guard let organizationName = draft.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                !organizationName.isEmpty else {
            return
          }

          let request = DashboardContactOrganizationDraft(
            name: organizationName,
            externalId: normalizedOptional(draft.externalId),
            domain: normalizedOptional(draft.domain),
            description: normalizedOptional(draft.description),
            metadata: nil
          )

          if let organizationID = draft.id {
            _ = await store.updateContactOrganization(id: organizationID, draft: request)
          } else if let created = await store.createContactOrganization(request) {
            if let contactID = contact?.id {
              let metadata = contact?.metadata
              _ = await store.updateContact(
                id: contactID,
                draft: DashboardContactDraft(
                  externalId: contact?.externalId,
                  name: contact?.name,
                  email: contact?.email,
                  image: contact?.image,
                  metadata: metadata,
                  contactOrganizationId: created.id
                )
              )
            }
          }
        }
      )
    }
  }

  @ViewBuilder
  private func contactDetailContent(_ contact: DashboardContact) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        contactHeader(contact)
        identitySection(contact)
        contextSection(contact)
        notesSection(contact)
        organizationSection(contact)

        if let metadata = contact.metadata, !metadata.isEmpty {
          metadataSection(metadata)
        }
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private func contactHeader(_ contact: DashboardContact) -> some View {
    HStack(spacing: 16) {
      DashboardAvatarPreviewButton(
        name: contact.displayName,
        imageURL: contact.image,
        seed: contact.avatarSeed,
        size: 52
      )

      VStack(alignment: .leading, spacing: 4) {
        Text(contact.displayName)
          .font(.largeTitle.weight(.semibold))

        Text(contact.email ?? "No email yet")
          .font(.headline)
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private func identitySection(_ contact: DashboardContact) -> some View {
    PrototypeInfoCard(title: "Identity") {
      PrototypeFact(label: "Email", value: contact.email ?? "Not set")
      PrototypeFact(label: "External ID", value: contact.externalId ?? "Not set")
      PrototypeFact(label: "Contact ID", value: contact.id)
    }
  }

  @ViewBuilder
  private func contextSection(_ contact: DashboardContact) -> some View {
    PrototypeInfoCard(title: "Context") {
      PrototypeFact(label: "Website", value: contact.websiteId)
      PrototypeFact(label: "Organization", value: contact.organizationId)
      PrototypeFact(label: "Created", value: contact.createdAbsoluteText)
      PrototypeFact(label: "Updated", value: contact.updatedAbsoluteText)
      PrototypeFact(label: "Last Seen", value: listItem?.lastSeenAbsoluteText ?? "Not seen yet")
      PrototypeFact(label: "Visit Count", value: listItem.map { String($0.visitorCount) } ?? "Unknown")
    }
  }

  @ViewBuilder
  private func notesSection(_ contact: DashboardContact) -> some View {
    PrototypeInfoCard(title: "Notes") {
      TextEditor(text: $notesDraft)
        .font(.body)
        .frame(minHeight: 120)
        .padding(8)
        .background(.quaternary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

      HStack {
        Text("Stored in contact metadata as `notes`.")
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer()

        Button(isSavingNotes ? "Saving…" : "Save Notes") {
          Task {
            await saveNotes(for: contact)
          }
        }
        .disabled(isSavingNotes)
      }
    }
  }

  @ViewBuilder
  private func organizationSection(_ contact: DashboardContact) -> some View {
    PrototypeInfoCard(title: "Organization") {
      if let organization = activeOrganization(for: contact) {
        PrototypeFact(label: "Name", value: organization.name)
        PrototypeFact(label: "Domain", value: organization.domain ?? "Not set")
        PrototypeFact(label: "External ID", value: organization.externalId ?? "Not set")
        PrototypeFact(label: "Description", value: organization.description ?? "Not set")

        HStack {
          Button("Edit") {
            organizationEditorDraft = ContactOrganizationEditorDraft(organization: organization)
            isPresentingOrganizationEditor = true
          }

          Button("Delete", role: .destructive) {
            Task {
              await store.deleteContactOrganization(id: organization.id)
            }
          }
        }
      } else {
        Text(contact.contactOrganizationId == nil ? "No contact organization linked yet." : "Loading organization…")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        Button(contact.contactOrganizationId == nil ? "Create Organization" : "Retry Load") {
          if contact.contactOrganizationId == nil {
            organizationEditorDraft = ContactOrganizationEditorDraft(
              name: contact.name,
              domain: contact.email.flatMap(Self.emailDomain(from:))
            )
            isPresentingOrganizationEditor = true
          } else if let organizationID = contact.contactOrganizationId {
            Task {
              await store.loadContactOrganization(id: organizationID)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private func metadataSection(_ metadata: DashboardMetadata) -> some View {
    PrototypeInfoCard(title: "Metadata") {
      ForEach(metadata.dashboardSortedEntries, id: \.0) { key, value in
        PrototypeFact(label: key, value: value.dashboardDisplayText)
      }
    }
  }

  private func notesText(for contact: DashboardContact?) -> String {
    guard let notesValue = contact?.metadata?["notes"] else { return "" }
    return notesValue.dashboardDisplayText
  }

  private func saveNotes(for contact: DashboardContact) async {
    isSavingNotes = true
    defer { isSavingNotes = false }

    var metadata = contact.metadata ?? [:]
    let normalizedNotes = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalizedNotes.isEmpty {
      metadata.removeValue(forKey: "notes")
    } else {
      metadata["notes"] = .string(normalizedNotes)
    }

    _ = await store.updateContactMetadata(id: contact.id, metadata: metadata)
  }

  private func activeOrganization(for contact: DashboardContact) -> DashboardContactOrganization? {
    guard let organizationID = contact.contactOrganizationId else { return nil }
    guard store.selectedContactOrganization?.id == organizationID else { return nil }
    return store.selectedContactOrganization
  }

  private func normalizedOptional(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
  }

  nonisolated private static func emailDomain(from email: String) -> String? {
    guard let atIndex = email.firstIndex(of: "@") else { return nil }
    let domain = email[email.index(after: atIndex)...]
    return domain.isEmpty ? nil : String(domain)
  }
}

private struct ContactOrganizationEditorDraft {
  var id: String?
  var name: String?
  var externalId: String?
  var domain: String?
  var description: String?

  init(
    id: String? = nil,
    name: String? = nil,
    externalId: String? = nil,
    domain: String? = nil,
    description: String? = nil
  ) {
    self.id = id
    self.name = name
    self.externalId = externalId
    self.domain = domain
    self.description = description
  }

  init(organization: DashboardContactOrganization) {
    self.id = organization.id
    self.name = organization.name
    self.externalId = organization.externalId
    self.domain = organization.domain
    self.description = organization.description
  }
}

private struct ContactOrganizationEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var draft: ContactOrganizationEditorDraft
  let isSaving: Bool
  let onSave: @MainActor (ContactOrganizationEditorDraft) async -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(draft.id == nil ? "Create Organization" : "Edit Organization")
        .font(.title3.weight(.semibold))

      TextField("Name", text: binding(for: \.name))
        .textFieldStyle(.roundedBorder)

      TextField("Domain", text: binding(for: \.domain))
        .textFieldStyle(.roundedBorder)

      TextField("External ID", text: binding(for: \.externalId))
        .textFieldStyle(.roundedBorder)

      TextField("Description", text: binding(for: \.description), axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...6)

      HStack {
        Spacer()

        Button("Cancel") {
          dismiss()
        }

        Button(isSaving ? "Saving…" : "Save") {
          Task {
            await onSave(draft)
            dismiss()
          }
        }
        .disabled(isSaving)
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 420)
  }

  private func binding(for keyPath: WritableKeyPath<ContactOrganizationEditorDraft, String?>) -> Binding<String> {
    Binding<String>(
      get: { draft[keyPath: keyPath] ?? "" },
      set: { draft[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
    )
  }
}

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
            systemImage: SFSymbol.booksVertical.rawValue,
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
          systemImage: SFSymbol.booksVertical.rawValue,
          description: Text("Select an entry from the list to inspect its source and payload details.")
        )
      }
    }
  }
}

private struct KnowledgeSectionHeader: View {
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

private struct KnowledgeRowView: View {
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

private struct KnowledgePaginationFooter: View {
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

private struct KnowledgePayloadCard: View {
  let item: DashboardKnowledge

  var body: some View {
    switch item.type {
    case .faq:
      if let payload = item.faqPayload {
        PrototypeInfoCard(title: "FAQ") {
          PrototypeFact(label: "Question", value: payload.question)
          PrototypeFact(label: "Answer", value: payload.answer)
          PrototypeFact(
            label: "Categories",
            value: payload.categories.isEmpty ? "None" : payload.categories.joined(separator: ", ")
          )
          PrototypeFact(
            label: "Related Questions",
            value: payload.relatedQuestions.isEmpty
              ? "None"
              : payload.relatedQuestions.joined(separator: "\n")
          )
        }
      } else {
        KnowledgeRawPayloadCard(payload: item.payload)
      }
    case .article:
      if let payload = item.articlePayload {
        PrototypeInfoCard(title: "Article") {
          PrototypeFact(label: "Title", value: payload.title)
          PrototypeFact(label: "Summary", value: payload.summary ?? "None")
          PrototypeFact(
            label: "Keywords",
            value: payload.keywords.isEmpty ? "None" : payload.keywords.joined(separator: ", ")
          )
          if let heroImage = payload.heroImage {
            PrototypeFact(label: "Hero Image", value: heroImage.src.absoluteString)
            PrototypeFact(label: "Hero Alt", value: heroImage.alt ?? "None")
          }
          KnowledgeTextBlock(title: "Markdown", text: payload.markdown)
        }
      } else {
        KnowledgeRawPayloadCard(payload: item.payload)
      }
    case .url:
      if let payload = item.urlPayload {
        PrototypeInfoCard(title: "Page Content") {
          PrototypeFact(
            label: "Estimated Tokens",
            value: payload.estimatedTokens.map(String.init) ?? "Unknown"
          )
          PrototypeFact(
            label: "Headings",
            value: payload.headings.isEmpty
              ? "None"
              : payload.headings.map { "H\($0.level): \($0.text)" }.joined(separator: "\n")
          )
          PrototypeFact(
            label: "Links",
            value: payload.links.isEmpty
              ? "None"
              : payload.links.map(\.absoluteString).joined(separator: "\n")
          )
          PrototypeFact(
            label: "Images",
            value: payload.images.isEmpty
              ? "None"
              : payload.images.map { image in
                  if let alt = image.alt, !alt.isEmpty {
                    return "\(image.src.absoluteString) (\(alt))"
                  }
                  return image.src.absoluteString
                }.joined(separator: "\n")
          )
          KnowledgeTextBlock(title: "Markdown", text: payload.markdown)
        }
      } else {
        KnowledgeRawPayloadCard(payload: item.payload)
      }
    }
  }
}

private struct KnowledgeRawPayloadCard: View {
  let payload: JSONValue

  var body: some View {
    PrototypeInfoCard(title: "Payload") {
      KnowledgeTextBlock(
        title: "JSON",
        text: payload.dashboardPrettyPrintedJSONString ?? payload.dashboardDisplayText
      )
    }
  }
}

private struct KnowledgeTextBlock: View {
  let title: String
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      ScrollView(.horizontal) {
        Text(text)
          .font(.body.monospaced())
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(minHeight: 120, alignment: .topLeading)
      .padding(12)
      .background(.quinary, in: .rect(cornerRadius: 12))
    }
  }
}

private struct KnowledgeEditorView: View {
  @Binding var draft: DashboardKnowledgeEditorDraft
  let errorMessage: String?
  let onSave: () -> Void
  let onCancel: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack(alignment: .top, spacing: 16) {
          VStack(alignment: .leading, spacing: 6) {
            Text(draft.editorTitle)
              .font(.largeTitle.weight(.semibold))

            Text("This editor maps directly to the exposed `/v1/knowledge` payload.")
              .font(.headline)
              .foregroundStyle(.secondary)
          }

          Spacer(minLength: 0)

          HStack(spacing: 10) {
            Button("Cancel", action: onCancel)
            Button("Save", action: onSave)
              .buttonStyle(.borderedProminent)
          }
        }

        if let errorMessage, !errorMessage.isEmpty {
          Text(errorMessage)
            .font(.subheadline)
            .foregroundStyle(.red)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.08), in: .rect(cornerRadius: 12))
        }

        PrototypeInfoCard(title: "Common Fields") {
          Picker("Type", selection: $draft.type) {
            ForEach(DashboardKnowledgeType.allCases) { type in
              Text(type.label)
                .tag(type)
            }
          }
          .disabled(draft.id != nil)

          TextField("Source title", text: $draft.sourceTitle)
            .textFieldStyle(.roundedBorder)

          TextField("Source URL", text: $draft.sourceURL)
            .textFieldStyle(.roundedBorder)

          TextField("Origin", text: $draft.origin)
            .textFieldStyle(.roundedBorder)

          TextField("AI agent ID", text: $draft.aiAgentID)
            .textFieldStyle(.roundedBorder)

          VStack(alignment: .leading, spacing: 6) {
            Text("Metadata JSON object")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)

            TextEditor(text: $draft.metadataText)
              .font(.body.monospaced())
              .frame(minHeight: 100)
              .padding(8)
              .background(.quinary, in: .rect(cornerRadius: 12))
          }
        }

        KnowledgePayloadEditorSection(draft: $draft)
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct KnowledgePayloadEditorSection: View {
  @Binding var draft: DashboardKnowledgeEditorDraft

  var body: some View {
    switch draft.type {
    case .faq:
      PrototypeInfoCard(title: "FAQ Payload") {
        TextField("Question", text: $draft.faqQuestion)
          .textFieldStyle(.roundedBorder)

        editorTextArea(title: "Answer", text: $draft.faqAnswer, minHeight: 140)
        TextField("Categories (comma separated)", text: $draft.faqCategoriesText)
          .textFieldStyle(.roundedBorder)
        editorTextArea(
          title: "Related questions (one per line)",
          text: $draft.faqRelatedQuestionsText,
          minHeight: 100
        )
      }
    case .article:
      PrototypeInfoCard(title: "Article Payload") {
        TextField("Title", text: $draft.articleTitle)
          .textFieldStyle(.roundedBorder)
        TextField("Summary", text: $draft.articleSummary)
          .textFieldStyle(.roundedBorder)
        TextField("Keywords (comma separated)", text: $draft.articleKeywordsText)
          .textFieldStyle(.roundedBorder)
        TextField("Hero image URL", text: $draft.articleHeroImageURL)
          .textFieldStyle(.roundedBorder)
        TextField("Hero image alt", text: $draft.articleHeroImageAlt)
          .textFieldStyle(.roundedBorder)
        editorTextArea(title: "Markdown", text: $draft.articleMarkdown, minHeight: 220)
      }
    case .url:
      PrototypeInfoCard(title: "URL Payload") {
        TextField("Estimated tokens", text: $draft.urlEstimatedTokensText)
          .textFieldStyle(.roundedBorder)
        editorTextArea(title: "Markdown", text: $draft.urlMarkdown, minHeight: 220)
        editorTextArea(
          title: "Headings (`level|text`, one per line)",
          text: $draft.urlHeadingsText,
          minHeight: 100
        )
        editorTextArea(
          title: "Links (one absolute URL per line)",
          text: $draft.urlLinksText,
          minHeight: 100
        )
        editorTextArea(
          title: "Images (`url|alt`, one per line)",
          text: $draft.urlImagesText,
          minHeight: 100
        )
      }
    }
  }

  private func editorTextArea(
    title: String,
    text: Binding<String>,
    minHeight: CGFloat
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      TextEditor(text: text)
        .font(.body.monospaced())
        .frame(minHeight: minHeight)
        .padding(8)
        .background(.quinary, in: .rect(cornerRadius: 12))
    }
  }
}

struct AnalyticsPrototypeView: View {
  @Bindable var model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Analytics")
          .font(.largeTitle.weight(.semibold))

        Text("Summarize recent support problems across many conversations, then ask follow-up questions against the same AI thread.")
          .font(.title3)
          .foregroundStyle(.secondary)

        analyticsRangeCard

        if let status = model.analyticsSummaryStatusMessage {
          Label(status, systemSymbol: .clockArrowTriangleheadCounterclockwiseRotate90)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        if let error = model.analyticsSummaryErrorMessage {
          Label(error, systemSymbol: .exclamationmarkTriangleFill)
            .font(.subheadline)
            .foregroundStyle(.red)
        }

        if model.analyticsConversationCount > 0 {
          analyticsStatsCard
        }

        analyticsConversationCard
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
      .textSelection(.enabled)
    }
  }

  private var analyticsRangeCard: some View {
    PrototypeInfoCard(title: "Summary Range") {
      Picker("Range", selection: $model.analyticsRangeMode) {
        ForEach(AnalyticsSummaryRangeMode.allCases) { mode in
          Text(mode.label)
            .tag(mode)
        }
      }
      .pickerStyle(.segmented)

      switch model.analyticsRangeMode {
      case .lastHours:
        Stepper(value: $model.analyticsLastHours, in: 1...168) {
          Text("Analyze conversations active in the last \(model.analyticsLastHours) hour\(model.analyticsLastHours == 1 ? "" : "s").")
        }
      case .lastDays:
        Stepper(value: $model.analyticsLastDays, in: 1...90) {
          Text("Analyze conversations active in the last \(model.analyticsLastDays) day\(model.analyticsLastDays == 1 ? "" : "s").")
        }
      case .custom:
        VStack(alignment: .leading, spacing: 12) {
          DatePicker(
            "Start",
            selection: $model.analyticsCustomStartDate,
            displayedComponents: [.date, .hourAndMinute]
          )
          DatePicker(
            "End",
            selection: $model.analyticsCustomEndDate,
            displayedComponents: [.date, .hourAndMinute]
          )
        }
      }

      if !model.canUseOpenAIReplyDrafts {
        Label("Add an OpenAI API key in Settings to enable conversation summaries.", systemSymbol: .keyFill)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      HStack {
        Button(model.analyticsIsGeneratingSummary ? "Generating…" : "Generate Summary") {
          model.startAnalyticsSummaryGeneration()
        }
        .disabled(!model.analyticsCanGenerateSummary)

        Button("Reset") {
          model.resetAnalyticsSummaryConversation()
        }
        .disabled(
          model.analyticsSummaryMessages.isEmpty
            && model.analyticsSourceDocument == nil
            && model.analyticsSummaryStatusMessage == nil
        )

        Spacer()

        if let dateRange = model.analyticsSelectedDateRange {
          Text(dateRange.label)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var analyticsStatsCard: some View {
    PrototypeInfoCard(title: "Run Details") {
      PrototypeFact(label: "Range", value: model.analyticsSummaryRangeLabel ?? "Not generated yet")
      PrototypeFact(label: "Conversations", value: String(model.analyticsConversationCount))
      PrototypeFact(label: "Messages", value: String(model.analyticsSourceMessageCount))
      PrototypeFact(
        label: "OpenAI Mode",
        value: model.analyticsSummaryUsedChunking ? "Chunked synthesis" : "Single request"
      )

      if let generatedAt = model.analyticsSummaryGeneratedAt {
        PrototypeFact(
          label: "Generated",
          value: generatedAt.formatted(.dateTime.year().month().day().hour().minute())
        )
      }

      HStack {
        Button("Copy Source Markdown") {
          model.copyAnalyticsSourceDocument()
        }
        .disabled(model.analyticsSourceDocument == nil)

        if let sourceDocument = model.analyticsSourceDocument {
          Text("\(sourceDocument.count) characters of source context")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var analyticsConversationCard: some View {
    PrototypeInfoCard(title: "AI Conversation") {
      if model.analyticsSummaryMessages.isEmpty {
        ContentUnavailableView(
          "No summary yet",
          systemImage: SFSymbol.textBubble.rawValue,
          description: Text("Pick a time range, generate a summary, and then use follow-up questions to dig into recurring complaints or reported bugs.")
        )
      } else {
        VStack(alignment: .leading, spacing: 14) {
          ForEach(model.analyticsSummaryMessages) { message in
            AnalyticsChatBubble(message: message)
          }

          Divider()

          VStack(alignment: .leading, spacing: 10) {
            TextField(
              "Ask a follow-up question about the recent complaints…",
              text: $model.analyticsFollowUpDraft,
              axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...4)

            HStack {
              Spacer()

              Button(model.analyticsIsSendingFollowUp ? "Sending…" : "Ask Follow-Up") {
                model.startAnalyticsFollowUp()
              }
              .disabled(!model.analyticsCanSendFollowUp)
            }
          }
        }
      }
    }
  }
}

private struct AnalyticsChatBubble: View {
  let message: AnalyticsSummaryChatMessage

  var body: some View {
    VStack(alignment: message.role == .assistant ? .leading : .trailing, spacing: 6) {
      Text(message.role == .assistant ? "AI Summary" : "You")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      Text(displayText)
      .textSelection(.enabled)
      .lineSpacing(4)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(backgroundStyle)
      .clipShape(.rect(cornerRadius: 16))

      Text(message.createdAt.formatted(.dateTime.hour().minute()))
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, alignment: message.role == .assistant ? .leading : .trailing)
  }

  private var backgroundStyle: some ShapeStyle {
    switch message.role {
    case .assistant:
      return AnyShapeStyle(.quinary)
    case .user:
      return AnyShapeStyle(.blue.opacity(0.12))
    }
  }

  private var displayText: String {
    guard message.role == .assistant else { return message.text }
    return message.text.analyticsSummaryDisplayText
  }
}

private extension String {
  var analyticsSummaryDisplayText: String {
    let normalized = replacingOccurrences(of: "\r\n", with: "\n")
    let lines = normalized.components(separatedBy: "\n")
    var displayLines: [String] = []

    for rawLine in lines {
      let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

      guard !trimmed.isEmpty else {
        if displayLines.last?.isEmpty == false {
          displayLines.append("")
        }
        continue
      }

      if let heading = trimmed.firstMarkdownHeadingLine {
        if !displayLines.isEmpty, displayLines.last?.isEmpty == false {
          displayLines.append("")
        }
        displayLines.append(heading)
        displayLines.append("")
        continue
      }

      if let bullet = trimmed.firstMarkdownBulletLine {
        displayLines.append("• \(bullet)")
        continue
      }

      displayLines.append(rawLine)
    }

    while displayLines.last?.isEmpty == true {
      displayLines.removeLast()
    }

    return displayLines.joined(separator: "\n")
  }

  var firstMarkdownHeadingLine: String? {
    let line = trimmingCharacters(in: .whitespaces)
    let hashes = line.prefix { $0 == "#" }
    guard !hashes.isEmpty else { return nil }

    let remainder = line.dropFirst(hashes.count).trimmingCharacters(in: .whitespaces)
    return remainder.isEmpty ? nil : remainder
  }

  var firstMarkdownBulletLine: String? {
    let line = trimmingCharacters(in: .whitespaces)

    if line.hasPrefix("- ") || line.hasPrefix("* ") {
      let bullet = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
      return bullet.isEmpty ? nil : bullet
    }

    return nil
  }
}

private func sectionHeader(title: String, subtitle: String) -> some View {
  VStack(alignment: .leading, spacing: 6) {
    Text(title)
      .font(.title2.weight(.semibold))

    Text(subtitle)
      .font(.subheadline)
      .foregroundStyle(.secondary)
  }
  .frame(maxWidth: .infinity, alignment: .leading)
  .padding(.horizontal, 18)
  .padding(.vertical, 16)
  .background(.bar)
}

private func contactsSubtitle(store: ContactsStore) -> String {
  if store.totalCount == 0 {
    return "No contacts match the current search."
  }

  return "\(store.totalCount) contacts available"
}

private struct ContactsSectionHeader: View {
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

private struct ContactsHeaderControlLabel: View {
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

private struct PrototypeInfoCard<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title)
        .font(.headline)

      content
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(.quaternary, lineWidth: 1)
    }
  }
}

private struct PrototypeFact: View {
  let label: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      Text(value)
        .font(.body)
    }
  }
}
