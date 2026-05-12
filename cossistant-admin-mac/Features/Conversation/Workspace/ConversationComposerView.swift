import AppKit
import SwiftUI
import SFSafeSymbols
import UniformTypeIdentifiers
import CossistantAdmin

struct ConversationComposerView: View {
  @Binding var draftText: String
  @Binding var visibility: DashboardTimelineItemVisibility
  let canUseOpenAIReplyDrafts: Bool
  let canUseTranslationPreview: Bool
  let isGeneratingReplyDraft: Bool
  let replyDraftErrorMessage: String?
  let onGenerateReplyDraft: @MainActor @Sendable (String) async -> String?
  let onPreviewTranslation: @MainActor @Sendable (String) async throws -> DashboardMessageTranslation
  let onSendMessage: @MainActor @Sendable (String, DashboardTimelineItemVisibility, [DashboardComposerAttachment]) async -> Void

  @State private var isSending = false
  @State private var attachments: [DashboardComposerAttachment] = []
  @State private var attachmentErrorMessage: String?
  @State private var isPreviewingTranslation = false
  @State private var translationPreview: DashboardMessageTranslation?
  @State private var translationPreviewErrorMessage: String?
  @State private var isShowingTranslationPreview = false
  @State private var localDraftText = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .center, spacing: 12) {
          composerLeadingControls
          Spacer(minLength: 12)
          sendButton
        }

        VStack(alignment: .leading, spacing: 10) {
          composerLeadingControls
          sendButton
        }
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

      TextEditor(text: $localDraftText)
        .font(.body)
        .frame(minHeight: 96, maxHeight: 140)
        .scrollContentBackground(.hidden)
        .disabled(isGeneratingReplyDraft || isSending)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topLeading) {
          if localDraftText.isEmpty {
            Text(composerPlaceholder)
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

      if let translationPreviewErrorMessage {
        Text(translationPreviewErrorMessage)
          .font(.caption)
          .foregroundStyle(.orange)
      }

      if let attachmentErrorMessage {
        Text(attachmentErrorMessage)
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
    .sheet(isPresented: $isShowingTranslationPreview) {
      if let translationPreview {
        ConversationDraftTranslationSheet(
          originalText: trimmedLocalDraftText,
          translation: translationPreview
        )
      }
    }
    .onAppear {
      localDraftText = draftText
    }
    .onChange(of: draftText) { _, newValue in
      guard localDraftText != newValue else { return }
      localDraftText = newValue
    }
    .onDisappear {
      commitLocalDraftText()
    }
  }

  private var composerLeadingControls: some View {
    Group {
      Picker("", selection: $visibility) {
        Text("Reply")
          .tag(DashboardTimelineItemVisibility.public)
        Text("Private Note")
          .tag(DashboardTimelineItemVisibility.private)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 220)

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
        .disabled(isGeneratingReplyDraft || trimmedLocalDraftText.isEmpty)
      }

      if canUseTranslationPreview {
        Button {
          Task {
            await previewTranslation()
          }
        } label: {
          Image(systemSymbol: .globe)
        }
        .buttonStyle(.bordered)
        .disabled(isSending || isGeneratingReplyDraft || isPreviewingTranslation || trimmedLocalDraftText.isEmpty)
        .help("Preview translation")
      }

      Button {
        importAttachments()
      } label: {
        Label("Attach", systemSymbol: .paperclip)
      }
      .buttonStyle(.bordered)
      .disabled(isSending || isGeneratingReplyDraft || attachments.count >= DashboardUploadConstants.maxFilesPerMessage)
    }
  }

  private var sendButton: some View {
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
        || (trimmedLocalDraftText.isEmpty && attachments.isEmpty)
    )
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

  private var composerPlaceholder: String {
    if isGeneratingReplyDraft {
      return "Drafting reply…"
    }

    return placeholder
  }

  private var trimmedLocalDraftText: String {
    localDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  @MainActor
  private func send() async {
    let message = trimmedLocalDraftText
    let currentAttachments = attachments

    guard !message.isEmpty || !currentAttachments.isEmpty else {
      return
    }

    isSending = true
    attachments = []
    attachmentErrorMessage = nil
    await onSendMessage(message, visibility, currentAttachments)
    localDraftText = ""
    draftText = ""
    isSending = false
  }

  @MainActor
  private func generateReplyDraft() async {
    let currentText = trimmedLocalDraftText
    guard !currentText.isEmpty else { return }
    guard let generatedDraft = await onGenerateReplyDraft(currentText) else { return }
    localDraftText = generatedDraft
    draftText = generatedDraft
  }

  @MainActor
  private func previewTranslation() async {
    let currentText = trimmedLocalDraftText
    guard !currentText.isEmpty else { return }
    commitLocalDraftText()

    isPreviewingTranslation = true
    translationPreviewErrorMessage = nil
    defer { isPreviewingTranslation = false }

    do {
      translationPreview = try await onPreviewTranslation(currentText)
      isShowingTranslationPreview = true
    } catch {
      translationPreviewErrorMessage = error.localizedDescription
    }
  }

  private func commitLocalDraftText() {
    guard draftText != localDraftText else { return }
    draftText = localDraftText
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

private struct ConversationDraftTranslationSheet: View {
  let originalText: String
  let translation: DashboardMessageTranslation

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Translation Preview")
        .font(.title3.weight(.semibold))

      GroupBox("Current Text") {
        Text(originalText)
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }

      GroupBox("Translation") {
        Text(translation.text)
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }

      if let detectedSourceLanguage = translation.detectedSourceLanguage,
         !detectedSourceLanguage.isEmpty {
        GroupBox("Detected Source Language") {
          Text(detectedSourceLanguage)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .padding(24)
    .frame(minWidth: 420, minHeight: 260)
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
