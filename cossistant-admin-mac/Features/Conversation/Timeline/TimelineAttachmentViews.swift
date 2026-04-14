import AppKit
import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct TimelineImageStripView: View {
  let images: [DashboardTimelineImagePart]
  @State private var selectedImage: TimelineImagePreviewItem?

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(Array(images.enumerated()), id: \.offset) { _, image in
          TimelineImageThumbnailButton(image: image) {
            selectedImage = TimelineImagePreviewItem(image: image)
          }
        }
      }
    }
    .sheet(item: $selectedImage) { preview in
      TimelineImagePreviewSheet(preview: preview)
    }
  }
}

struct TimelineFileStripView: View {
  let files: [DashboardTimelineFilePart]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(files.enumerated()), id: \.offset) { _, file in
        TimelineFileAttachmentCard(file: file)
      }
    }
  }
}

struct TimelineImageThumbnailButton: View {
  let image: DashboardTimelineImagePart
  let onPreview: () -> Void

  var body: some View {
    Button(action: onPreview) {
      ZStack(alignment: .bottomTrailing) {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(.quaternary.opacity(0.18))

        AsyncImage(url: image.remoteURL) { phase in
          switch phase {
          case .success(let loadedImage):
            loadedImage
              .resizable()
              .scaledToFit()
              .padding(6)
          default:
            Image(systemSymbol: .photo)
              .foregroundStyle(.secondary)
          }
        }

        Image(systemSymbol: .arrowUpLeftAndArrowDownRight)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.white)
          .padding(6)
          .background(.black.opacity(0.5), in: Circle())
          .padding(6)
      }
      .frame(width: 132, height: 92)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .contextMenu {
      if let url = image.remoteURL {
        Link(destination: url) {
          Label("Open Original", systemSymbol: .arrowUpForwardSquare)
        }

        Button {
          Task {
            await TimelineAttachmentSaveCoordinator.save(
              from: url,
              suggestedFilename: image.filename
            )
          }
        } label: {
          Label("Save As…", systemSymbol: .arrowDownCircle)
        }
      }
    }
    .help("View full image")
  }
}

struct TimelineFileAttachmentCard: View {
  let file: DashboardTimelineFilePart
  @Environment(\.openURL) private var openURL

  var body: some View {
    HStack(spacing: 10) {
      Image(systemSymbol: icon)
        .font(.body)
        .foregroundStyle(Color.accentColor)
        .frame(width: 18, height: 18)

      VStack(alignment: .leading, spacing: 2) {
        Text(file.filename ?? "Attachment")
          .font(.caption.weight(.medium))
          .lineLimit(1)
          .truncationMode(.middle)

        HStack(spacing: 6) {
          Text(file.mediaType)
            .font(.caption2)
            .foregroundStyle(.secondary)

          if let sizeLabel = file.formattedSize {
            Text("•")
              .font(.caption2)
              .foregroundStyle(.tertiary)

            Text(sizeLabel)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }

      Spacer(minLength: 0)

      if let url = file.remoteURL {
        Button {
          openURL(url)
        } label: {
          Label("Open", systemSymbol: .arrowUpForwardSquare)
            .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)

        Button {
          Task {
            await TimelineAttachmentSaveCoordinator.save(
              from: url,
              suggestedFilename: file.filename
            )
          }
        } label: {
          Image(systemSymbol: .arrowDownCircle)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .help("Save attachment")
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(.separator.opacity(0.18), lineWidth: 1)
    }
    .contextMenu {
      if let url = file.remoteURL {
        Link(destination: url) {
          Label("Open Original", systemSymbol: .arrowUpForwardSquare)
        }

        Button {
          Task {
            await TimelineAttachmentSaveCoordinator.save(
              from: url,
              suggestedFilename: file.filename
            )
          }
        } label: {
          Label("Save As…", systemSymbol: .arrowDownCircle)
        }
      }
    }
    .help(file.remoteURL == nil ? "Attachment URL unavailable" : "Open the original attachment")
  }

  private var icon: SFSymbol {
    let mediaType = file.mediaType.lowercased()

    if mediaType.contains("pdf") {
      return .richtextPage
    }

    if mediaType.hasPrefix("image") {
      return .photo
    }

    if mediaType.hasPrefix("video") {
      return .film
    }

    if mediaType.hasPrefix("audio") {
      return .waveform
    }

    if mediaType.contains("zip") || mediaType.contains("compressed") {
      return .archivebox
    }

    return .paperclip
  }
}

struct TimelineImagePreviewItem: Identifiable {
  let id: String
  let url: URL
  let filename: String?
  let width: Int?
  let height: Int?

  init?(image: DashboardTimelineImagePart) {
    guard let url = image.remoteURL else { return nil }
    self.id = image.url
    self.url = url
    self.filename = image.filename
    self.width = image.width
    self.height = image.height
  }
}

struct TimelineImagePreviewSheet: View {
  let preview: TimelineImagePreviewItem
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(preview.filename ?? "Image")
            .font(.headline)
            .lineLimit(1)

          if let metadataText {
            Text(metadataText)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer(minLength: 12)

        Button {
          openURL(preview.url)
        } label: {
          Label("Open Original", systemSymbol: .arrowUpForwardSquare)
        }

        Button {
          Task {
            await TimelineAttachmentSaveCoordinator.save(
              from: preview.url,
              suggestedFilename: preview.suggestedFilename
            )
          }
        } label: {
          Label("Save As…", systemSymbol: .arrowDownCircle)
        }

        Button("Done") {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .background(.bar)

      Divider()

      ZStack {
        Color.black.opacity(0.92)
          .ignoresSafeArea()

        AsyncImage(url: preview.url) { phase in
          switch phase {
          case .success(let loadedImage):
            loadedImage
              .resizable()
              .scaledToFit()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .padding(24)
          case .failure:
            ContentUnavailableView(
              "Image unavailable",
              systemImage: SFSymbol.photo.rawValue,
              description: Text("The original image could not be loaded.")
            )
            .foregroundStyle(.white.opacity(0.8))
          default:
            ProgressView()
              .controlSize(.large)
              .tint(.white)
          }
        }
      }
    }
    .frame(minWidth: 760, minHeight: 520)
    .background(.black)
  }

  private var metadataText: String? {
    var components: [String] = []

    if let width = preview.width, let height = preview.height {
      components.append("\(width) × \(height)")
    }

    let pathExtension = preview.url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
    if !pathExtension.isEmpty {
      components.append(pathExtension.uppercased())
    }

    return components.isEmpty ? nil : components.joined(separator: " • ")
  }
}

@MainActor
enum TimelineAttachmentSaveCoordinator {
  static func save(from remoteURL: URL, suggestedFilename: String?) async {
    let panel = NSSavePanel()
    panel.canCreateDirectories = true
    panel.isExtensionHidden = false
    panel.nameFieldStringValue = resolvedFilename(
      remoteURL: remoteURL,
      suggestedFilename: suggestedFilename
    )

    guard panel.runModal() == .OK, let destinationURL = panel.url else {
      return
    }

    do {
      let (temporaryURL, _) = try await URLSession.shared.download(from: remoteURL)
      let fileManager = FileManager.default

      if fileManager.fileExists(atPath: destinationURL.path()) {
        try fileManager.removeItem(at: destinationURL)
      }

      try fileManager.copyItem(at: temporaryURL, to: destinationURL)
    } catch {
      NSAlert(error: error).runModal()
    }
  }

  private static func resolvedFilename(remoteURL: URL, suggestedFilename: String?) -> String {
    let trimmedSuggestion = suggestedFilename?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmedSuggestion.isEmpty {
      return trimmedSuggestion
    }

    let remoteName = remoteURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
    if !remoteName.isEmpty && remoteName != "/" {
      return remoteName
    }

    return "Attachment"
  }
}

private extension DashboardTimelineFilePart {
  var remoteURL: URL? {
    URL(string: url)
  }

  var formattedSize: String? {
    guard let size else { return nil }
    return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
  }
}

private extension DashboardTimelineImagePart {
  var remoteURL: URL? {
    URL(string: url)
  }
}

private extension TimelineImagePreviewItem {
  var suggestedFilename: String? {
    let trimmedFilename = filename?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmedFilename.isEmpty {
      return trimmedFilename
    }

    let remoteName = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
    return remoteName.isEmpty || remoteName == "/" ? nil : remoteName
  }
}
