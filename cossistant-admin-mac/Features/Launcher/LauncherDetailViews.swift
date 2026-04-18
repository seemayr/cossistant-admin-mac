import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct LauncherProfileDetail: View {
  let profile: DashboardProfile
  let onOpen: () -> Void
  let onEdit: () -> Void
  let onDelete: () -> Void

  var body: some View {
    VStack(alignment: .center, spacing: 22) {
      Spacer(minLength: 40)

      ZStack {
        Circle()
          .fill(.thinMaterial)
          .frame(width: 104, height: 104)

        Image(systemSymbol: .bubbleLeftAndBubbleRightFill)
          .font(.system(size: 38, weight: .semibold))
          .foregroundStyle(.blue)
      }

      VStack(spacing: 6) {
        Text(profile.name)
          .font(.system(size: 32, weight: .semibold, design: .rounded))
          .multilineTextAlignment(.center)

        Text(profile.hostLabel)
          .font(.headline)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 12) {
        Button {
          onOpen()
        } label: {
          Label("Open Workspace", systemSymbol: .arrowUpForwardApp)
            .frame(minWidth: 170)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .buttonBorderShape(.capsule)

        Menu {
          Button {
            onEdit()
          } label: {
            Label("Edit Profile", systemSymbol: .sliderHorizontal3)
          }

          Divider()

          Button(role: .destructive) {
            onDelete()
          } label: {
            Label("Delete Profile", systemSymbol: .trash)
          }
        } label: {
          Image(systemSymbol: .ellipsisCircleFill)
            .font(.title2)
        }
        .menuStyle(.borderlessButton)
        .controlSize(.large)
      }

      Spacer()
    }
    .padding(.horizontal, 34)
    .padding(.bottom, 34)
  }
}

struct LauncherWelcomeState: View {
  let onCreateProfile: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("No Workspace Profiles", systemSymbol: .bubbleLeftAndBubbleRight)
    } description: {
      Text("Create a profile to open a workspace.")
    } actions: {
      Button {
        onCreateProfile()
      } label: {
        Label("New Profile", systemSymbol: .plus)
      }
      .buttonStyle(.borderedProminent)
    }
  }
}

struct LauncherSelectionState: View {
  var body: some View {
    ContentUnavailableView {
      Label("Select a Profile", systemSymbol: .bubbleLeftAndBubbleRight)
    } description: {
      Text("Choose a profile from the sidebar.")
    }
  }
}
