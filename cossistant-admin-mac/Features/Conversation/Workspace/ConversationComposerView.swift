import AppKit
import SwiftUI
import SFSafeSymbols
import UniformTypeIdentifiers
import CossistantAdmin

struct ConversationComposerView: View {
  let canUseOpenAIReplyDrafts: Bool
  let isGeneratingReplyDraft: Bool
  let replyDraftErrorMessage: String?
  let onGenerateReplyDraft: @MainActor @Sendable (String) async -> String?
  let onSendMessage: @MainActor @Sendable (String, DashboardTimelineItemVisibility, [DashboardComposerAttachment]) async -> Void

  @State private var draftText = ""
  @State private var visibility: DashboardTimelineItemVisibility = .public
  @State private var isSending = false
  @State private var attachments: [DashboardComposerAttachment] = []
  @State private var attachmentErrorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        Picker("", selection: $visibility) {
          Text("Reply")
            .tag(DashboardTimelineItemVisibility.public)
          Text("Private Note")
            .tag(DashboardTimelineItemVisibility.private)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 230)

        if visibility == .public, canUseOpenAIReplyDrafts {
          Button {
            Task {
              await generateReplyDraft()
            }
          } label: {
            Label(
              isGeneratingReplyDraft ? "Drafting…" : "Draft with AI",
              systemSymbol: .sparklesRectangleStack
            )
          }
          .buttonStyle(.bordered)
          .disabled(isGeneratingReplyDraft || draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        Button {
          importAttachments()
        } label: {
          Label("Attach", systemSymbol: .paperclip)
        }
        .buttonStyle(.bordered)
        .disabled(isSending || isGeneratingReplyDraft || attachments.count >= DashboardUploadConstants.maxFilesPerMessage)

        Spacer(minLength: 12)

        Button {
          Task {
            await send()
          }
        } label: {
          Label(isSending ? "Sending…" : sendButtonTitle, systemSymbol: sendButtonSymbol)
        }
        .buttonStyle(.borderedProminent)
        .disabled(
          isSending
            || isGeneratingReplyDraft
            || (draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty)
        )
      }

      if !attachments.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(attachments) { attachment in
              ConversationComposerAttachmentChip(
                attachment: attachment,
                onRemove: {
                  removeAttachment(attachment.id)
                }
              )
            }
          }
        }
      }

      TextEditor(text: $draftText)
        .font(.body)
        .frame(minHeight: 96, maxHeight: 140)
        .scrollContentBackground(.hidden)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topLeading) {
          if draftText.isEmpty {
            Text(placeholder)
              .foregroundStyle(.tertiary)
              .padding(.horizontal, 18)
              .padding(.vertical, 20)
              .allowsHitTesting(false)
          }
        }

      if let replyDraftErrorMessage, visibility == .public {
        Text(replyDraftErrorMessage)
          .font(.caption)
          .foregroundStyle(.orange)
      }

      if let attachmentErrorMessage {
        Text(attachmentErrorMessage)
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
  }

  private var sendButtonTitle: String {
    visibility == .public ? "Send Reply" : "Save Note"
  }

  private var sendButtonSymbol: SFSymbol {
    visibility == .public ? .paperplaneFill : .textPadHeaderBadgePlus
  }

  private var placeholder: String {
    visibility == .public
      ? "Reply to the visitor…"
      : "Write an internal note…"
  }

  @MainActor
  private func send() async {
    let message = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    let currentAttachments = attachments

    guard !message.isEmpty || !currentAttachments.isEmpty else {
      return
    }

    isSending = true
    draftText = ""
    attachments = []
    attachmentErrorMessage = nil
    await onSendMessage(message, visibility, currentAttachments)
    isSending = false
  }

  @MainActor
  private func generateReplyDraft() async {
    let currentText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !currentText.isEmpty else { return }
    guard let generatedDraft = await onGenerateReplyDraft(currentText) else { return }
    draftText = generatedDraft
  }

  private func removeAttachment(_ id: DashboardComposerAttachment.ID) {
    attachments.removeAll { $0.id == id }
  }

  private func importAttachments() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = DashboardUploadConstants.importableTypes
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.canChooseFiles = true

    guard panel.runModal() == .OK else { return }

    do {
      let remainingSlots = DashboardUploadConstants.maxFilesPerMessage - attachments.count
      guard remainingSlots > 0 else {
        throw DashboardAttachmentValidationError.tooManyFiles(max: DashboardUploadConstants.maxFilesPerMessage)
      }

      if panel.urls.count > remainingSlots {
        throw DashboardAttachmentValidationError.tooManyFiles(max: DashboardUploadConstants.maxFilesPerMessage)
      }

      let newAttachments = try panel.urls.map { try Self.loadAttachment(from: $0) }
      attachments.append(contentsOf: newAttachments)
      attachmentErrorMessage = nil
    } catch {
      attachmentErrorMessage = error.localizedDescription
    }
  }

  private static func loadAttachment(from url: URL) throws -> DashboardComposerAttachment {
    let data = try Data(contentsOf: url)
    guard let contentType = contentType(for: url) else {
      throw DashboardAttachmentValidationError.unsupportedType(fileName: url.lastPathComponent)
    }

    let attachment = DashboardComposerAttachment(
      data: data,
      fileName: url.lastPathComponent,
      contentType: contentType
    )

    if let error = DashboardUploadConstants.validate(attachment) {
      throw error
    }

    return attachment
  }

  private static func contentType(for url: URL) -> String? {
    if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
       let mimeType = contentType.preferredMIMEType {
      return mimeType
    }

    return UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
  }
}

private struct ConversationComposerAttachmentChip: View {
  let attachment: DashboardComposerAttachment
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      thumbnail

      VStack(alignment: .leading, spacing: 2) {
        Text(attachment.fileName)
          .font(.subheadline.weight(.medium))
          .lineLimit(1)

        Text(attachment.formattedSize)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Button(action: onRemove) {
        Image(systemSymbol: .xmarkCircleFill)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  @ViewBuilder
  private var thumbnail: some View {
    if let image = attachment.thumbnailImage {
      Image(nsImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    } else {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(.quaternary.opacity(0.35))
        .frame(width: 34, height: 34)
        .overlay {
          Image(systemSymbol: attachment.isImage ? .photo : .document)
            .foregroundStyle(.secondary)
        }
    }
  }
}
