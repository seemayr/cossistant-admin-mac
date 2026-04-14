import SwiftUI
import CossistantAdmin

struct KnowledgePayloadCard: View {
  let item: DashboardKnowledge

  var body: some View {
    switch item.type {
    case .faq:
      if let payload = item.faqPayload {
        PrototypeInfoCard(title: "FAQ") {
          PrototypeFact(label: "Question", value: payload.question)
          PrototypeFact(label: "Answer", value: payload.answer)
          PrototypeFact(
            label: "Categories",
            value: payload.categories.isEmpty ? "None" : payload.categories.joined(separator: ", ")
          )
          PrototypeFact(
            label: "Related Questions",
            value: payload.relatedQuestions.isEmpty
              ? "None"
              : payload.relatedQuestions.joined(separator: "\n")
          )
        }
      } else {
        KnowledgeRawPayloadCard(payload: item.payload)
      }
    case .article:
      if let payload = item.articlePayload {
        PrototypeInfoCard(title: "Article") {
          PrototypeFact(label: "Title", value: payload.title)
          PrototypeFact(label: "Summary", value: payload.summary ?? "None")
          PrototypeFact(
            label: "Keywords",
            value: payload.keywords.isEmpty ? "None" : payload.keywords.joined(separator: ", ")
          )
          if let heroImage = payload.heroImage {
            PrototypeFact(label: "Hero Image", value: heroImage.src.absoluteString)
            PrototypeFact(label: "Hero Alt", value: heroImage.alt ?? "None")
          }
          KnowledgeTextBlock(title: "Markdown", text: payload.markdown)
        }
      } else {
        KnowledgeRawPayloadCard(payload: item.payload)
      }
    case .url:
      if let payload = item.urlPayload {
        PrototypeInfoCard(title: "Page Content") {
          PrototypeFact(
            label: "Estimated Tokens",
            value: payload.estimatedTokens.map(String.init) ?? "Unknown"
          )
          PrototypeFact(
            label: "Headings",
            value: payload.headings.isEmpty
              ? "None"
              : payload.headings.map { "H\($0.level): \($0.text)" }.joined(separator: "\n")
          )
          PrototypeFact(
            label: "Links",
            value: payload.links.isEmpty
              ? "None"
              : payload.links.map(\.absoluteString).joined(separator: "\n")
          )
          PrototypeFact(
            label: "Images",
            value: payload.images.isEmpty
              ? "None"
              : payload.images.map { image in
                  if let alt = image.alt, !alt.isEmpty {
                    return "\(image.src.absoluteString) (\(alt))"
                  }
                  return image.src.absoluteString
                }.joined(separator: "\n")
          )
          KnowledgeTextBlock(title: "Markdown", text: payload.markdown)
        }
      } else {
        KnowledgeRawPayloadCard(payload: item.payload)
      }
    }
  }
}

struct KnowledgeRawPayloadCard: View {
  let payload: JSONValue

  var body: some View {
    PrototypeInfoCard(title: "Payload") {
      KnowledgeTextBlock(
        title: "JSON",
        text: payload.dashboardPrettyPrintedJSONString ?? payload.dashboardDisplayText
      )
    }
  }
}

struct KnowledgeTextBlock: View {
  let title: String
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      ScrollView(.horizontal) {
        Text(text)
          .font(.body.monospaced())
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(minHeight: 120, alignment: .topLeading)
      .padding(12)
      .background(.quinary, in: .rect(cornerRadius: 12))
    }
  }
}
