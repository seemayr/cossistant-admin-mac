import SwiftUI

struct AISummarizeNavigationPlaceholderView: View {
  let store: AnalyticsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Summarize")
        .font(.title2.weight(.semibold))

      Text("Generate an AI summary for a recent time window, then keep asking follow-up questions in the detail pane.")
        .foregroundStyle(.secondary)

      if store.hasOpenAIAPIKey {
        Text("OpenAI key detected")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      } else {
        Text("Add an OpenAI key in Settings to enable this view.")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      }

      if store.conversationCount > 0 {
        VStack(alignment: .leading, spacing: 4) {
          Text("\(store.conversationCount) conversations analyzed")
          Text("\(store.sourceMessageCount) messages included")
            .foregroundStyle(.secondary)
        }
        .font(.subheadline)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(24)
  }
}

struct AIAutoResolveNavigationPlaceholderView: View {
  let store: AutoResolveStore

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Auto-Resolve")
        .font(.title2.weight(.semibold))

      Text("Review open conversations one by one with AI, automatically resolve safe cases, and inspect a per-conversation result list in the detail pane.")
        .foregroundStyle(.secondary)

      if store.hasOpenAIAPIKey {
        Text("OpenAI key detected")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      } else {
        Text("Add an OpenAI key in Settings to enable this workflow.")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      }

      if !store.results.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("\(store.results.count) reviewed conversations")
          if let status = store.statusMessage {
            Text(status)
              .foregroundStyle(.secondary)
          }
        }
        .font(.subheadline)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(24)
  }
}

struct FAQNavigationPlaceholderView: View {
  let store: FAQStore

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("FAQ")
        .font(.title2.weight(.semibold))

      Text("Draft retrieval-friendly FAQ entries, optimize them with OpenAI, or build new suggestions from a selected conversation.")
        .foregroundStyle(.secondary)

      if store.hasOpenAIAPIKey {
        Text("OpenAI key detected")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      } else {
        Text("Add an OpenAI key in Settings to enable FAQ drafting and optimization.")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      }

      if let suggestion = store.suggestion {
        VStack(alignment: .leading, spacing: 4) {
          Text("Suggestion ready")
          Text(suggestion.generatedAt.formatted(.dateTime.year().month().day().hour().minute()))
            .foregroundStyle(.secondary)
        }
        .font(.subheadline)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(24)
  }
}
