import SwiftUI
import SFSafeSymbols

struct WorkspaceSettingsView: View {
  @Bindable var model: WorkspaceModel

  var body: some View {
    ScrollView {
      Form {
        Section {
          Menu {
            Button {
              model.setWorkspaceChannelFilter(nil)
            } label: {
              menuLabel(
                "Any Channel",
                isSelected: model.workspaceSettings.normalizedChannelFilter == nil
              )
            }

            ForEach(model.availableWorkspaceChannelFilters()) { option in
              Button {
                model.setWorkspaceChannelFilter(option.value)
              } label: {
                menuLabel(
                  option.label,
                  isSelected: model.workspaceSettings.normalizedChannelFilter == option.value
                )
              }
            }
          } label: {
            HeaderControlLabel(
              title: "Channel",
              value: model.workspaceSettings.normalizedChannelFilter.map {
                InboxChannelFilterOption(value: $0).label
              } ?? "Any Channel",
              systemImage: .bubbleLeftAndBubbleRight
            )
          }
        } header: {
          Text("Project Filters")
        } footer: {
          Text("Conversation tools use these filters by default across this workspace.")
        }

        Section {
          Toggle(
            isOn: Binding(
              get: { model.workspaceSettings.autoMarkSeenOnOpen },
              set: { model.setWorkspaceAutoMarkSeenOnOpen($0) }
            )
          ) {
            Text("Auto mark read on open")
          }
          .toggleStyle(.switch)
        } header: {
          Text("Workspace Behavior")
        } footer: {
          Text("Opening an unread conversation marks it as read for the current teammate.")
        }

        Section {
          Toggle(
            "Show translated subjects",
            isOn: Binding(
              get: { model.workspaceSettings.showBackendTranslatedSubjects },
              set: { model.setWorkspaceShowBackendTranslatedSubjects($0) }
            )
          )
          .toggleStyle(.switch)

          Toggle(
            "Show translated messages",
            isOn: Binding(
              get: { model.workspaceSettings.showBackendTranslatedMessages },
              set: { isEnabled in
                Task {
                  await model.setWorkspaceShowBackendTranslatedMessages(isEnabled)
                }
              }
            )
          )
          .toggleStyle(.switch)
        } header: {
          Text("Backend Translations")
        } footer: {
          Text("When disabled, backend-provided translations are ignored. Message translation then uses Google Cloud Translate for every message when the conversation translation switch is enabled.")
        }
      }
      .formStyle(.grouped)
      .padding(24)
      .frame(maxWidth: 640, alignment: .leading)
    }
    .navigationTitle("Workspace Settings")
  }

  private func menuLabel(_ title: String, isSelected: Bool) -> some View {
    Group {
      if isSelected {
        Label(title, systemSymbol: .checkmark)
      } else {
        Text(title)
      }
    }
  }
}
