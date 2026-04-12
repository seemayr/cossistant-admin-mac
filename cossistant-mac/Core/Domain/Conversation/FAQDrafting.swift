import Foundation

struct FAQDraft: Hashable, Sendable {
  static let targetChunkSize = 1_000
  static let chunkOverlap = 200
  static let recommendedSingleChunkBudget = 900

  var question = ""
  var categoriesText = ""
  var relatedQuestionsText = ""
  var answer = ""

  var normalizedQuestion: String {
    question.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var normalizedAnswer: String {
    answer.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var normalizedCategories: [String] {
    categoriesText
      .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == ";" })
      .map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
      }
      .filter { !$0.isEmpty }
  }

  var normalizedRelatedQuestions: [String] {
    relatedQuestionsText
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
      }
      .filter { !$0.isEmpty }
  }

  var hasMeaningfulContent: Bool {
    !normalizedQuestion.isEmpty
      || !normalizedAnswer.isEmpty
      || !normalizedCategories.isEmpty
      || !normalizedRelatedQuestions.isEmpty
  }

  var questionCharacterCount: Int {
    normalizedQuestion.count
  }

  var answerCharacterCount: Int {
    normalizedAnswer.count
  }

  var relatedQuestionsCharacterCount: Int {
    normalizedRelatedQuestions.joined(separator: "\n").count
  }

  var categoriesCharacterCount: Int {
    normalizedCategories.joined(separator: ", ").count
  }

  var embeddedTrainingCharacterCount: Int {
    guard !normalizedQuestion.isEmpty || !normalizedAnswer.isEmpty else {
      return 0
    }

    return 3 + normalizedQuestion.count + 4 + normalizedAnswer.count
  }

  var embeddedTrainingText: String {
    guard embeddedTrainingCharacterCount > 0 else { return "" }
    return "Q: \(normalizedQuestion)\n\nA: \(normalizedAnswer)"
  }

  var estimatedChunkCount: Int {
    let count = embeddedTrainingCharacterCount
    guard count > 0 else { return 0 }
    guard count > Self.targetChunkSize else { return 1 }

    let stride = Self.targetChunkSize - Self.chunkOverlap
    let overflow = count - Self.targetChunkSize
    return 1 + Int(ceil(Double(overflow) / Double(stride)))
  }

  var chunkStatusLabel: String {
    let embeddedCount = embeddedTrainingCharacterCount

    guard embeddedCount > 0 else { return "No embedded text yet" }
    if embeddedCount <= Self.recommendedSingleChunkBudget {
      return "Ideal single chunk"
    }
    if embeddedCount <= Self.targetChunkSize {
      return "Single chunk, near split threshold"
    }
    return "\(estimatedChunkCount) chunks estimated"
  }

  var categoriesDisplayText: String {
    normalizedCategories.joined(separator: ", ")
  }

  var relatedQuestionsDisplayText: String {
    normalizedRelatedQuestions.joined(separator: "\n")
  }

  init(
    question: String = "",
    categoriesText: String = "",
    relatedQuestionsText: String = "",
    answer: String = ""
  ) {
    self.question = question
    self.categoriesText = categoriesText
    self.relatedQuestionsText = relatedQuestionsText
    self.answer = answer
  }

  init(payload: FAQDraftModelPayload) {
    self.init(
      question: payload.question,
      categoriesText: payload.categories.joined(separator: ", "),
      relatedQuestionsText: payload.relatedQuestions.joined(separator: "\n"),
      answer: payload.answer
    )
  }
}

struct FAQDraftSuggestion: Hashable, Sendable {
  let draft: FAQDraft
  let notes: String?
  let generatedAt: Date
  let sourceConversationId: String?
  let sourceConversationTitle: String?
  let sourceMessageCount: Int?

  init(
    draft: FAQDraft,
    notes: String? = nil,
    generatedAt: Date = .now,
    sourceConversationId: String? = nil,
    sourceConversationTitle: String? = nil,
    sourceMessageCount: Int? = nil
  ) {
    self.draft = draft
    self.notes = FAQTextNormalization.nilIfEmpty(notes)
    self.generatedAt = generatedAt
    self.sourceConversationId = sourceConversationId
    self.sourceConversationTitle = sourceConversationTitle
    self.sourceMessageCount = sourceMessageCount
  }
}

struct FAQDraftModelPayload: Codable, Hashable, Sendable {
  let question: String
  let categories: [String]
  let relatedQuestions: [String]
  let answer: String
  let notes: String?

  var normalized: FAQDraftModelPayload {
    FAQDraftModelPayload(
      question: question.trimmingCharacters(in: .whitespacesAndNewlines),
      categories: categories.normalizedDistinctItems,
      relatedQuestions: relatedQuestions.normalizedDistinctItems,
      answer: answer.trimmingCharacters(in: .whitespacesAndNewlines),
      notes: FAQTextNormalization.nilIfEmpty(notes)
    )
  }
}

extension String {
  var jsonQuoted: String {
    let data = try? JSONEncoder().encode(self)
    guard let data, let string = String(data: data, encoding: .utf8) else {
      return "\"\""
    }
    return string
  }

  var strippingCodeFenceIfPresent: String {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("```") else { return trimmed }

    let lines = trimmed.components(separatedBy: "\n")
    guard lines.count >= 3 else { return trimmed }

    let body = lines.dropFirst().dropLast().joined(separator: "\n")
    return body.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

private enum FAQTextNormalization {
  static func nilIfEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

extension Array where Element == String {
  var jsonArrayLiteral: String {
    let data = try? JSONEncoder().encode(self)
    guard let data, let string = String(data: data, encoding: .utf8) else {
      return "[]"
    }
    return string
  }

  var normalizedDistinctItems: [String] {
    var seen = Set<String>()
    var result: [String] = []

    for item in self {
      let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }

      let key = trimmed.localizedLowercase
      guard seen.insert(key).inserted else { continue }
      result.append(trimmed)
    }

    return result
  }
}
