import Foundation
import CossistantAdmin

enum FAQPromptLibrary {
  private enum Resource: String, CaseIterable {
    case authoringGuide = "faq-authoring-guide"
    case examples = "faq-examples"
    case optimizeDeveloper = "faq-optimize-developer"
    case optimizeUser = "faq-optimize-user"
    case buildDeveloper = "faq-build-developer"
    case buildUser = "faq-build-user"
    case selfCheckDeveloper = "faq-self-check-developer"
    case selfCheckUser = "faq-self-check-user"
  }

  static func authoringGuideMarkdown() throws -> String {
    try load(.authoringGuide)
  }

  static func optimizePrompts(
    workspaceName: String?,
    draftJSON: String
  ) throws -> (developer: String, user: String) {
    let guide = try load(.authoringGuide)
    let examples = try load(.examples)

    return (
      developer: try load(.optimizeDeveloper),
      user: try render(
        template: load(.optimizeUser),
        placeholders: [
          "workspace_name": workspaceName ?? "Cossistant",
          "guide_markdown": guide,
          "examples_markdown": examples,
          "draft_json": draftJSON,
        ]
      )
    )
  }

  static func buildPrompts(
    workspaceName: String?,
    conversationTitle: String?,
    messageCount: Int,
    transcriptJSON: String
  ) throws -> (developer: String, user: String) {
    let guide = try load(.authoringGuide)
    let examples = try load(.examples)

    return (
      developer: try load(.buildDeveloper),
      user: try render(
        template: load(.buildUser),
        placeholders: [
          "workspace_name": workspaceName ?? "Cossistant",
          "conversation_title": conversationTitle ?? "Untitled conversation",
          "message_count": String(messageCount),
          "guide_markdown": guide,
          "examples_markdown": examples,
          "transcript_json": transcriptJSON,
        ]
      )
    )
  }

  static func selfCheckPrompts(
    sourceLabel: String,
    sourceMaterial: String,
    candidateJSON: String
  ) throws -> (developer: String, user: String) {
    let guide = try load(.authoringGuide)
    let examples = try load(.examples)

    return (
      developer: try load(.selfCheckDeveloper),
      user: try render(
        template: load(.selfCheckUser),
        placeholders: [
          "source_label": sourceLabel,
          "source_material": sourceMaterial,
          "guide_markdown": guide,
          "examples_markdown": examples,
          "candidate_json": candidateJSON,
        ]
      )
    )
  }

  private static func render(
    template: String,
    placeholders: [String: String]
  ) throws -> String {
    var result = template

    for (key, value) in placeholders {
      result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
    }

    return result
  }

  private static func load(_ resource: Resource) throws -> String {
    let bundledURL = Bundle.main.url(
      forResource: resource.rawValue,
      withExtension: "md",
      subdirectory: "Prompts/FAQ"
    ) ?? Bundle.main.url(
      forResource: resource.rawValue,
      withExtension: "md"
    )

    guard let url = bundledURL else {
      throw ConversationAssistantError.server(
        message: "Missing bundled FAQ prompt resource: \(resource.rawValue).md"
      )
    }

    return try String(contentsOf: url, encoding: .utf8)
  }
}
