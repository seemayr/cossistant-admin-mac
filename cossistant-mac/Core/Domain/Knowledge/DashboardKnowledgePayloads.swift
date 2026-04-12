import Foundation

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
