import SwiftUI

struct ContactOrganizationEditorDraft {
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

struct ContactOrganizationEditorSheet: View {
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
