import SwiftUI
import CossistantAdmin

enum AvatarRole: Hashable, Sendable {
  case person
  case ai
}

struct AvatarView: View {
  let name: String
  let imageURL: URL?
  let seed: String
  var size: CGFloat = 38
  var showsActivePresence = false
  var role: AvatarRole = .person

  var body: some View {
    Group {
      if let imageURL {
        AsyncImage(url: imageURL) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFill()
          default:
            fallbackAvatar
          }
        }
      } else {
        fallbackAvatar
      }
    }
    .frame(width: size, height: size)
    .clipShape(.circle)
    .overlay {
      Circle()
        .strokeBorder(.white.opacity(0.6), lineWidth: 1)
    }
    .overlay(alignment: .bottomLeading) {
      if showsActivePresence {
        Circle()
          .fill(.green)
          .frame(width: max(size * 0.32, 11), height: max(size * 0.32, 11))
          .overlay {
            Circle()
              .strokeBorder(.background, lineWidth: 2)
          }
          .offset(x: -2, y: 2)
      }
    }
  }

  @ViewBuilder
  private var fallbackAvatar: some View {
    if role == .ai {
      aiFallbackAvatar
    } else {
      personFallbackAvatar
    }
  }

  private var personFallbackAvatar: some View {
    let descriptor = DashboardIdentity.avatarFallback(seed: seed)
    let fillColor = Color(
      hue: descriptor.hue,
      saturation: descriptor.saturation,
      brightness: descriptor.brightness
    )

    return ZStack {
      Circle()
        .fill(fillColor.gradient)

      Text(descriptor.emoji)
        .font(.system(size: max(size * 0.5, 14)))
    }
  }

  private var aiFallbackAvatar: some View {
    RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
      .fill(.secondary.opacity(0.12))
      .overlay {
        Image("coss")
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .frame(width: size * 0.5, height: size * 0.5)
          .foregroundStyle(.secondary)
      }
  }
}

struct AvatarPreviewButton: View {
  let name: String
  let imageURL: URL?
  let seed: String
  var size: CGFloat = 38
  var showsActivePresence = false
  var role: AvatarRole = .person

  @State private var isPresentingPreview = false

  var body: some View {
    Group {
      if imageURL != nil {
        Button {
          isPresentingPreview = true
        } label: {
          AvatarView(
            name: name,
            imageURL: imageURL,
            seed: seed,
            size: size,
            showsActivePresence: showsActivePresence,
            role: role
          )
        }
        .buttonStyle(.plain)
        .help("Show larger avatar")
        .sheet(isPresented: $isPresentingPreview) {
          AvatarPreviewSheet(name: name, imageURL: imageURL)
        }
      } else {
        AvatarView(
          name: name,
          imageURL: imageURL,
          seed: seed,
          size: size,
          showsActivePresence: showsActivePresence,
          role: role
        )
      }
    }
  }
}

private struct AvatarPreviewSheet: View {
  let name: String
  let imageURL: URL?

  var body: some View {
    VStack(spacing: 18) {
      if let imageURL {
        AsyncImage(url: imageURL) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFit()
          case .failure:
            ContentUnavailableView("Avatar unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
          default:
            ProgressView()
              .controlSize(.large)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      }

      Text(name)
        .font(.headline)
    }
    .padding(24)
    .frame(minWidth: 360, minHeight: 420)
    .background(.regularMaterial)
  }
}
