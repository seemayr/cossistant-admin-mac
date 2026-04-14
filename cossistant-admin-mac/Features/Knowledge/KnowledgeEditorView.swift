import SwiftUI
import CossistantAdmin

struct KnowledgeEditorView: View {
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
