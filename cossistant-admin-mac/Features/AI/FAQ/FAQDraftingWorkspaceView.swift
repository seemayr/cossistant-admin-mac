import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct FAQDraftingWorkspaceView: View {
  @Bindable var store: FAQStore
  let selectedConversation: DashboardConversation?
  let canBuildFromConversation: Bool
  let onOptimizeDraft: () -> Void
  let onBuildFromSelectedConversation: () -> Void
  let onResetDraft: () -> Void
  let onClearSuggestion: () -> Void
  let onApplySuggestionToDraft: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("FAQ")
          .font(.largeTitle.weight(.semibold))

        Text("Draft FAQ entries that match the current backend retrieval model. Optimize manual drafts or build a new suggestion from the selected conversation without overwriting your working copy.")
          .font(.title3)
          .foregroundStyle(.secondary)

        faqActionCard

        if let status = store.statusMessage {
          Label(status, systemSymbol: .clockArrowTriangleheadCounterclockwiseRotate90)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        if let error = store.errorMessage {
          Label(error, systemSymbol: .exclamationmarkTriangleFill)
            .font(.subheadline)
            .foregroundStyle(.red)
        }

        HStack(alignment: .top, spacing: 20) {
          VStack(alignment: .leading, spacing: 20) {
            FAQDraftEditorCard(
              title: "Manual Draft",
              subtitle: "These fields stay editable. Optimize creates a separate suggestion instead of overwriting this draft.",
              draft: $store.draft,
              isEditable: true
            )

            FAQTrainingStatsCard(
              title: "Manual Draft Training Stats",
              draft: store.draft
            )
          }
          .frame(maxWidth: .infinity, alignment: .topLeading)

          VStack(alignment: .leading, spacing: 20) {
            FAQSuggestionCard(
              store: store,
              onApplyToDraft: onApplySuggestionToDraft
            )

            FAQGuideHighlightsCard()
          }
          .frame(maxWidth: .infinity, alignment: .topLeading)
        }
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
      .textSelection(.enabled)
    }
  }

  private var faqActionCard: some View {
    PrototypeInfoCard(title: "Draft Actions") {
      Text("The current backend embeds only the main Question and Answer. Related Questions and Categories help operators, but they do not carry the main retrieval load.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if !store.hasOpenAIAPIKey {
        Label("Add an OpenAI API key in Settings to enable FAQ optimization and conversation-based drafting.", systemSymbol: .keyFill)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 12) {
        Button(store.isOptimizing ? "Optimizing…" : "Optimize Draft") {
          onOptimizeDraft()
        }
        .disabled(!store.canOptimize)

        Button(store.isBuildingFromConversation ? "Building…" : "Build from Selected Conversation") {
          onBuildFromSelectedConversation()
        }
        .disabled(!canBuildFromConversation)

        Button("Reset Draft") {
          onResetDraft()
        }
        .disabled(!store.draft.hasMeaningfulContent)

        if store.suggestion != nil {
          Button("Clear Suggestion") {
            onClearSuggestion()
          }
        }

        Spacer()
      }

      if let selectedConversation {
        HStack(spacing: 10) {
          Image(systemSymbol: .bubbleLeftAndBubbleRight)
            .foregroundStyle(.secondary)

          VStack(alignment: .leading, spacing: 2) {
            Text("Selected conversation")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)

            Text(selectedConversation.displayTitle)
              .font(.subheadline)

            Text(selectedConversation.visitorDisplayName)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.top, 2)
      }
    }
  }
}

private struct FAQDraftEditorCard: View {
  let title: String
  let subtitle: String
  @Binding var draft: FAQDraft
  let isEditable: Bool

  var body: some View {
    PrototypeInfoCard(title: title) {
      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 14) {
        FAQFieldLabel(
          title: "Question",
          characterCount: draft.question.trimmingCharacters(in: .whitespacesAndNewlines).count
        )
        TextField("What users actually ask", text: $draft.question)
          .textFieldStyle(.roundedBorder)
          .disabled(!isEditable)

        FAQFieldLabel(
          title: "Categories",
          characterCount: draft.categoriesText.trimmingCharacters(in: .whitespacesAndNewlines).count,
          note: "Metadata only in the current backend"
        )
        TextField("Comma separated categories", text: $draft.categoriesText)
          .textFieldStyle(.roundedBorder)
          .disabled(!isEditable)

        FAQTextAreaField(
          title: "Related Questions",
          note: "Helpful metadata, but not the main embedded retrieval text",
          text: $draft.relatedQuestionsText,
          placeholder: "One alternate phrasing per line",
          minHeight: 96,
          isEditable: isEditable
        )

        FAQTextAreaField(
          title: "Answer",
          note: "Main embedded retrieval text together with the Question",
          text: $draft.answer,
          placeholder: "Exact fix, workaround, and escalation condition",
          minHeight: 180,
          isEditable: isEditable
        )
      }
    }
  }
}

private struct FAQSuggestionCard: View {
  @Bindable var store: FAQStore
  let onApplyToDraft: () -> Void

  var body: some View {
    PrototypeInfoCard(title: "AI Suggestion") {
      if let suggestion = store.suggestion {
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Text("Generated \(suggestion.generatedAt.formatted(.dateTime.year().month().day().hour().minute()))")
              .font(.caption)
              .foregroundStyle(.secondary)

            Spacer()

            Button("Apply to Draft") {
              onApplyToDraft()
            }
          }

          if let title = suggestion.sourceConversationTitle {
            PrototypeFact(label: "Source Conversation", value: title)
          }

          if let sourceMessageCount = suggestion.sourceMessageCount {
            PrototypeFact(label: "Source Messages", value: String(sourceMessageCount))
          }

          FAQSuggestionField(title: "Question", value: suggestion.draft.normalizedQuestion)
          FAQSuggestionField(
            title: "Categories",
            value: suggestion.draft.categoriesDisplayText.faqNilIfEmpty ?? "No categories suggested"
          )
          FAQSuggestionField(
            title: "Related Questions",
            value: suggestion.draft.relatedQuestionsDisplayText.faqNilIfEmpty ?? "No related questions suggested"
          )
          FAQSuggestionField(title: "Answer", value: suggestion.draft.normalizedAnswer)

          if let notes = suggestion.notes {
            FAQSuggestionField(title: "AI Notes", value: notes)
          }

          FAQTrainingStatsCard(
            title: "Suggestion Training Stats",
            draft: suggestion.draft
          )
        }
      } else {
        ContentUnavailableView(
          "No suggestion yet",
          systemImage: SFSymbol.questionmarkBubble.rawValue,
          description: Text("Optimize the manual draft or build a new FAQ from the selected conversation.")
        )
      }
    }
  }
}

private struct FAQTrainingStatsCard: View {
  let title: String
  let draft: FAQDraft

  var body: some View {
    PrototypeInfoCard(title: title) {
      PrototypeFact(
        label: "Embedded Training Characters",
        value: draft.embeddedTrainingCharacterCount == 0 ? "0" : String(draft.embeddedTrainingCharacterCount)
      )
      PrototypeFact(label: "Estimated Chunks", value: draft.estimatedChunkCount == 0 ? "0" : String(draft.estimatedChunkCount))
      PrototypeFact(label: "Chunk Status", value: draft.chunkStatusLabel)
      PrototypeFact(label: "Question Characters", value: String(draft.questionCharacterCount))
      PrototypeFact(label: "Answer Characters", value: String(draft.answerCharacterCount))
      PrototypeFact(label: "Related Question Characters", value: String(draft.relatedQuestionsCharacterCount))
      PrototypeFact(label: "Category Characters", value: String(draft.categoriesCharacterCount))
      PrototypeFact(label: "Embedded Fields", value: "Question + Answer")
      PrototypeFact(label: "Metadata Only", value: "Categories + Related Questions")

      Text("Budget formula: `3 + question.count + 4 + answer.count` because the backend embeds `Q: <question>` and `A: <answer>`.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

private struct FAQGuideHighlightsCard: View {
  var body: some View {
    PrototypeInfoCard(title: "Perfect FAQ Rules") {
      FAQRuleLine(text: "Use one FAQ for one issue or one tightly connected workflow.")
      FAQRuleLine(text: "Keep the strongest wording variants inside the Question and Answer, not only in Related Questions.")
      FAQRuleLine(text: "Aim for 900 embedded Question + Answer characters to stay comfortably single-chunk.")
      FAQRuleLine(text: "If users say wildly different things for the same mechanic, make the Question canonical and mention the variants early in the Answer.")
      FAQRuleLine(text: "Treat Categories as operator metadata, not as the main retrieval surface.")
      FAQRuleLine(text: "When drafting from a conversation, trust visitor and human admin messages over AI messages.")
    }
  }
}

private struct FAQFieldLabel: View {
  let title: String
  let characterCount: Int
  var note: String? = nil

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        if let note {
          Text(note)
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }

      Spacer()

      Text("\(characterCount) chars")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

private struct FAQTextAreaField: View {
  let title: String
  let note: String
  @Binding var text: String
  let placeholder: String
  let minHeight: CGFloat
  let isEditable: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      FAQFieldLabel(
        title: title,
        characterCount: text.trimmingCharacters(in: .whitespacesAndNewlines).count,
        note: note
      )

      TextEditor(text: $text)
        .font(.body.monospaced())
        .frame(minHeight: minHeight)
        .padding(8)
        .background(.quinary, in: .rect(cornerRadius: 12))
        .overlay(alignment: .topLeading) {
          if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(placeholder)
              .font(.body)
              .foregroundStyle(.tertiary)
              .padding(.horizontal, 14)
              .padding(.vertical, 16)
              .allowsHitTesting(false)
          }
        }
        .disabled(!isEditable)
    }
  }
}

private struct FAQSuggestionField: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      Text(value)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quinary, in: .rect(cornerRadius: 12))
        .textSelection(.enabled)
    }
  }
}

private struct FAQRuleLine: View {
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Text("•")
        .foregroundStyle(.secondary)

      Text(text)
        .foregroundStyle(.secondary)
    }
    .font(.subheadline)
  }
}

private extension String {
  var faqNilIfEmpty: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
