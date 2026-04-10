import Foundation

struct DashboardWebsite: Decodable, Sendable {
  struct HumanAgent: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String?
    let image: URL?
    let lastSeenAt: String?

    var displayName: String {
      if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return name
      }

      return "Team member"
    }
  }

  struct AIAgent: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String?
    let image: URL?

    var displayName: String {
      if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return name
      }

      return "AI agent"
    }
  }

  let id: String
  let name: String
  let domain: String?
  let description: String?
  let logoURL: URL?
  let organizationId: String
  let status: String
  let lastOnlineAt: String?
  let availableHumanAgents: [HumanAgent]
  let availableAIAgents: [AIAgent]

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case domain
    case description
    case logoURL = "logoUrl"
    case organizationId
    case status
    case lastOnlineAt
    case availableHumanAgents
    case availableAIAgents
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    domain = try container.decodeIfPresent(String.self, forKey: .domain)
    description = try container.decodeIfPresent(String.self, forKey: .description)
    logoURL = try container.decodeIfPresent(URL.self, forKey: .logoURL)
    organizationId = try container.decode(String.self, forKey: .organizationId)
    status = try container.decode(String.self, forKey: .status)
    lastOnlineAt = try container.decodeIfPresent(String.self, forKey: .lastOnlineAt)
    availableHumanAgents = try container.decodeIfPresent([HumanAgent].self, forKey: .availableHumanAgents) ?? []
    availableAIAgents = try container.decodeIfPresent([AIAgent].self, forKey: .availableAIAgents) ?? []
  }
}
