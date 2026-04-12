import SwiftUI

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
          systemImage: "person.2",
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
      AvatarPreviewButton(
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
