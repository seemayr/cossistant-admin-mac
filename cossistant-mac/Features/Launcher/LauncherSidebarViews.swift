import SwiftUI
import SFSafeSymbols

struct LauncherSidebarHeader: View {
  let profileCount: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Cossistant")
        .font(.title2.weight(.semibold))

      Text(profileCount == 1 ? "1 profile" : "\(profileCount) profiles")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

struct LauncherSidebarEmptyState: View {
  let onCreateProfile: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("No Profiles", systemSymbol: .personCropRectangleStack)
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

struct LauncherSidebarRow: View {
  let profile: DashboardProfile
  let onOpen: () -> Void
  let onEdit: () -> Void
  let onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(profile.name)
        .font(.headline.weight(.medium))
        .lineLimit(1)

      Text(profile.hostLabel)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(.rect(cornerRadius: 10))
    .onTapGesture(count: 2) {
      onOpen()
    }
    .contextMenu {
      Button {
        onOpen()
      } label: {
        Label("Open Workspace", systemSymbol: .arrowUpForwardApp)
      }

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
    }
  }
}
