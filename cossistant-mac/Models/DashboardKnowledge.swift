import Foundation

enum DashboardKnowledgeType: String, Codable, CaseIterable, Identifiable, Sendable {
  case url
  case faq
  case article

  var id: String { rawValue }

  var label: String {
    switch self {
    case .url:
      "URL"
    case .faq:
      "FAQ"
    case .article:
      "Article"
    }
  }
}

struct DashboardPaginationMetadata: Decodable, Hashable, Sendable {
  let page: Int
  let limit: Int
  let total: Int
  let hasMore: Bool
}

struct DashboardKnowledgeListResponse: Decodable, Sendable {
  let items: [DashboardKnowledge]
  let pagination: DashboardPaginationMetadata
}

struct DashboardKnowledge: Identifiable, Decodable, Hashable, Sendable {
  let id: String
  let organizationId: String
  let websiteId: String
  let aiAgentId: String?
  let linkSourceId: String?
  let type: DashboardKnowledgeType
  let sourceUrl: URL?
  let sourceTitle: String?
  let origin: String
  let createdBy: String
  let contentHash: String
  let payload: JSONValue
  let metadata: DashboardMetadata?
  let isIncluded: Bool
  let sizeBytes: Int
  let createdAt: String
  let updatedAt: String
  let deletedAt: String?

  var titleText: String {
    sourceTitle ?? sourceUrl?.absoluteString ?? id
  }

  var createdAbsoluteText: String {
    DashboardTimestampParser.absoluteString(from: createdAt) ?? createdAt
  }

  var updatedAbsoluteText: String {
    DashboardTimestampParser.absoluteString(from: updatedAt) ?? updatedAt
  }

  var faqPayload: DashboardFAQKnowledgePayload? {
    payload.dashboardDecoded(as: DashboardFAQKnowledgePayload.self)
  }

  var articlePayload: DashboardArticleKnowledgePayload? {
    payload.dashboardDecoded(as: DashboardArticleKnowledgePayload.self)
  }

  var urlPayload: DashboardURLKnowledgePayload? {
    payload.dashboardDecoded(as: DashboardURLKnowledgePayload.self)
  }
}

struct DashboardKnowledgeDraft: Encodable, Sendable {
  var aiAgentId: String?
  var type: DashboardKnowledgeType
  var sourceUrl: URL?
  var sourceTitle: String?
  var origin: String
  var payload: JSONValue
  var metadata: DashboardMetadata?
}

enum DashboardKnowledgeIncludedFilter: String, CaseIterable, Identifiable, Sendable {
  case all
  case included
  case excluded

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      "All"
    case .included:
      "Included"
    case .excluded:
      "Excluded"
    }
  }

  var queryValue: String? {
    switch self {
    case .all:
      nil
    case .included:
      "true"
    case .excluded:
      "false"
    }
  }
}

struct DashboardKnowledgeHeading: Codable, Hashable, Sendable {
  var level: Int
  var text: String
}

struct DashboardKnowledgeImage: Codable, Hashable, Sendable {
  var src: URL
  var alt: String?
}

struct DashboardURLKnowledgePayload: Codable, Hashable, Sendable {
  var markdown: String
  var headings: [DashboardKnowledgeHeading]
  var links: [URL]
  var images: [DashboardKnowledgeImage]
  var estimatedTokens: Int?
}

struct DashboardFAQKnowledgePayload: Codable, Hashable, Sendable {
  var question: String
  var answer: String
  var categories: [String]
  var relatedQuestions: [String]
}

struct DashboardArticleKnowledgePayload: Codable, Hashable, Sendable {
  var title: String
  var summary: String?
  var markdown: String
  var keywords: [String]
  var heroImage: DashboardKnowledgeImage?
}

enum DashboardKnowledgeEditorError: LocalizedError {
  case invalidURL(String)
  case invalidEstimatedTokens
  case invalidMetadata
  case missingRequiredField(String)

  var errorDescription: String? {
    switch self {
    case .invalidURL(let label):
      "\(label) must be a valid absolute URL."
    case .invalidEstimatedTokens:
      "Estimated tokens must be a non-negative whole number."
    case .invalidMetadata:
      "Metadata must be a valid JSON object."
    case .missingRequiredField(let label):
      "\(label) is required."
    }
  }
}

struct DashboardKnowledgeEditorDraft: Equatable, Sendable {
  var id: String?
  var type: DashboardKnowledgeType
  var aiAgentID = ""
  var sourceURL = ""
  var sourceTitle = ""
  var origin = "manual"
  var metadataText = ""
  var faqQuestion = ""
  var faqAnswer = ""
  var faqCategoriesText = ""
  var faqRelatedQuestionsText = ""
  var articleTitle = ""
  var articleSummary = ""
  var articleMarkdown = ""
  var articleKeywordsText = ""
  var articleHeroImageURL = ""
  var articleHeroImageAlt = ""
  var urlMarkdown = ""
  var urlHeadingsText = ""
  var urlLinksText = ""
  var urlImagesText = ""
  var urlEstimatedTokensText = ""

  init(type: DashboardKnowledgeType) {
    self.type = type
  }

  init(item: DashboardKnowledge) {
    id = item.id
    type = item.type
    aiAgentID = item.aiAgentId ?? ""
    sourceURL = item.sourceUrl?.absoluteString ?? ""
    sourceTitle = item.sourceTitle ?? ""
    origin = item.origin
    metadataText = item.metadata?.dashboardPrettyPrintedJSONString ?? ""

    if let payload = item.faqPayload {
      faqQuestion = payload.question
      faqAnswer = payload.answer
      faqCategoriesText = payload.categories.joined(separator: ", ")
      faqRelatedQuestionsText = payload.relatedQuestions.joined(separator: "\n")
    }

    if let payload = item.articlePayload {
      articleTitle = payload.title
      articleSummary = payload.summary ?? ""
      articleMarkdown = payload.markdown
      articleKeywordsText = payload.keywords.joined(separator: ", ")
      articleHeroImageURL = payload.heroImage?.src.absoluteString ?? ""
      articleHeroImageAlt = payload.heroImage?.alt ?? ""
    }

    if let payload = item.urlPayload {
      urlMarkdown = payload.markdown
      urlHeadingsText = payload.headings
        .map { "\($0.level)|\($0.text)" }
        .joined(separator: "\n")
      urlLinksText = payload.links
        .map(\.absoluteString)
        .joined(separator: "\n")
      urlImagesText = payload.images
        .map { image in
          let alt = image.alt ?? ""
          return "\(image.src.absoluteString)|\(alt)"
        }
        .joined(separator: "\n")
      if let estimatedTokens = payload.estimatedTokens {
        urlEstimatedTokensText = String(estimatedTokens)
      }
    }
  }

  var editorTitle: String {
    if id == nil {
      return "New \(type.label)"
    }

    return "Edit \(type.label)"
  }

  func makeRequest() throws -> DashboardKnowledgeDraft {
    DashboardKnowledgeDraft(
      aiAgentId: aiAgentID.dashboardNilIfEmpty,
      type: type,
      sourceUrl: try parsedURL(sourceURL, label: "Source URL"),
      sourceTitle: sourceTitle.dashboardNilIfEmpty,
      origin: origin.dashboardTrimmedNonEmpty(fallback: "manual"),
      payload: try payloadValue(),
      metadata: try parsedMetadata()
    )
  }

  private func payloadValue() throws -> JSONValue {
    switch type {
    case .faq:
      guard let question = faqQuestion.dashboardNilIfEmpty else {
        throw DashboardKnowledgeEditorError.missingRequiredField("Question")
      }
      guard let answer = faqAnswer.dashboardNilIfEmpty else {
        throw DashboardKnowledgeEditorError.missingRequiredField("Answer")
      }
      return .object([
        "question": .string(question),
        "answer": .string(answer),
        "categories": .array(faqCategoriesText.dashboardCommaSeparatedValues.map(JSONValue.string)),
        "relatedQuestions": .array(
          faqRelatedQuestionsText.dashboardLineSeparatedValues.map(JSONValue.string)
        ),
      ])
    case .article:
      guard let title = articleTitle.dashboardNilIfEmpty else {
        throw DashboardKnowledgeEditorError.missingRequiredField("Title")
      }
      guard let markdown = articleMarkdown.dashboardNilIfEmpty else {
        throw DashboardKnowledgeEditorError.missingRequiredField("Markdown")
      }

      var object: [String: JSONValue] = [
        "title": .string(title),
        "markdown": .string(markdown),
        "keywords": .array(articleKeywordsText.dashboardCommaSeparatedValues.map(JSONValue.string)),
      ]
      object["summary"] = articleSummary.dashboardNilIfEmpty.map(JSONValue.string) ?? .null

      if let heroImageURL = try parsedURL(articleHeroImageURL, label: "Hero image URL") {
        object["heroImage"] = .object([
          "src": .string(heroImageURL.absoluteString),
          "alt": articleHeroImageAlt.dashboardNilIfEmpty.map(JSONValue.string) ?? .null,
        ])
      }

      return .object(object)
    case .url:
      guard let markdown = urlMarkdown.dashboardNilIfEmpty else {
        throw DashboardKnowledgeEditorError.missingRequiredField("Markdown")
      }

      var object: [String: JSONValue] = [
        "markdown": .string(markdown),
        "headings": .array(try parsedHeadings().map { heading in
          .object([
            "level": .number(Double(heading.level)),
            "text": .string(heading.text),
          ])
        }),
        "links": .array(try parsedLinks().map { .string($0.absoluteString) }),
        "images": .array(try parsedImages().map { image in
          .object([
            "src": .string(image.src.absoluteString),
            "alt": image.alt.map(JSONValue.string) ?? .null,
          ])
        }),
      ]

      if !urlEstimatedTokensText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        guard let estimatedTokens = Int(urlEstimatedTokensText),
              estimatedTokens >= 0 else {
          throw DashboardKnowledgeEditorError.invalidEstimatedTokens
        }
        object["estimatedTokens"] = .number(Double(estimatedTokens))
      }

      return .object(object)
    }
  }

  private func parsedMetadata() throws -> DashboardMetadata? {
    let trimmed = metadataText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    guard let data = trimmed.data(using: .utf8),
          let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw DashboardKnowledgeEditorError.invalidMetadata
    }
    return try object.reduce(into: DashboardMetadata()) { result, entry in
      result[entry.key] = try JSONValue.dashboardValue(from: entry.value)
    }
  }

  private func parsedHeadings() throws -> [DashboardKnowledgeHeading] {
    try urlHeadingsText.dashboardLineSeparatedValues.compactMap { line in
      let segments = line.split(separator: "|", maxSplits: 1).map(String.init)
      guard segments.count == 2, let level = Int(segments[0]), (1...6).contains(level) else {
        throw DashboardKnowledgeEditorError.missingRequiredField(
          "Each heading must use `level|text` with a level from 1 to 6"
        )
      }
      let text = segments[1].trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else {
        throw DashboardKnowledgeEditorError.missingRequiredField("Heading text")
      }
      return DashboardKnowledgeHeading(level: level, text: text)
    }
  }

  private func parsedLinks() throws -> [URL] {
    try urlLinksText.dashboardLineSeparatedValues.map {
      guard let url = URL(string: $0), url.scheme != nil, url.host != nil else {
        throw DashboardKnowledgeEditorError.invalidURL("Page link")
      }
      return url
    }
  }

  private func parsedImages() throws -> [DashboardKnowledgeImage] {
    try urlImagesText.dashboardLineSeparatedValues.map { line in
      let segments = line.split(separator: "|", maxSplits: 1).map(String.init)
      guard let src = segments.first,
            let url = URL(string: src),
            url.scheme != nil,
            url.host != nil else {
        throw DashboardKnowledgeEditorError.invalidURL("Image URL")
      }
      let alt = segments.count > 1 ? segments[1].dashboardNilIfEmpty : nil
      return DashboardKnowledgeImage(src: url, alt: alt)
    }
  }

  private func parsedURL(_ value: String, label: String) throws -> URL? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else {
      throw DashboardKnowledgeEditorError.invalidURL(label)
    }
    return url
  }
}

extension DashboardKnowledgeEditorDraft {
  static func blank(type: DashboardKnowledgeType) -> Self {
    DashboardKnowledgeEditorDraft(type: type)
  }
}

extension String {
  var dashboardNilIfEmpty: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  func dashboardTrimmedNonEmpty(fallback: String) -> String {
    dashboardNilIfEmpty ?? fallback
  }

  var dashboardCommaSeparatedValues: [String] {
    split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  var dashboardLineSeparatedValues: [String] {
    split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}
