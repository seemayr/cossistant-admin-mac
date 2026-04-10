import Foundation

enum DashboardIdentity {
  private static let adjectives = [
    "happy", "sunny", "cosmic", "stellar", "swift", "mighty", "clever", "brave",
    "gentle", "noble", "quick", "bright", "silver", "golden", "crystal", "mystic",
    "ancient", "modern", "electric", "magnetic", "dynamic", "static", "flying",
    "dancing", "singing", "laughing", "smiling", "glowing", "shining", "sparkling",
    "dazzling", "radiant", "peaceful", "serene", "tranquil", "vibrant", "energetic",
    "lively", "spirited", "bold", "fearless", "curious", "wise", "witty", "charming",
    "elegant", "graceful", "agile", "nimble", "speedy", "zippy", "bouncy", "jolly",
    "merry", "cheerful", "playful", "friendly", "loyal", "honest", "kind", "warm",
    "cool", "chill", "awesome", "amazing", "wonderful", "fantastic", "magnificent",
    "marvelous", "splendid", "brilliant", "genius", "super", "mega", "ultra", "hyper",
    "turbo", "quantum", "nano", "micro", "macro", "epic", "legendary", "mythic",
    "heroic", "royal", "imperial", "majestic",
  ]

  private static let nouns = [
    "panda", "dolphin", "eagle", "falcon", "hawk", "owl", "raven", "phoenix",
    "dragon", "unicorn", "griffin", "pegasus", "lion", "tiger", "leopard", "cheetah",
    "panther", "wolf", "fox", "bear", "koala", "kangaroo", "rabbit", "squirrel",
    "hedgehog", "otter", "seal", "whale", "shark", "octopus", "jellyfish", "starfish",
    "butterfly", "dragonfly", "firefly", "bee", "hummingbird", "peacock", "flamingo",
    "penguin", "mountain", "valley", "river", "ocean", "forest", "desert", "glacier",
    "volcano", "canyon", "meadow", "prairie", "savanna", "tundra", "rainforest",
    "waterfall", "geyser", "aurora", "comet", "meteor", "planet", "galaxy", "nebula",
    "constellation", "star", "moon", "sun", "eclipse", "horizon", "sunrise", "sunset",
    "rainbow", "thunder", "lightning", "storm", "breeze", "wind", "tornado",
    "hurricane", "blizzard", "avalanche", "rocket", "satellite", "spaceship",
    "explorer", "pioneer", "voyager", "wanderer", "nomad", "knight", "samurai",
    "ninja", "wizard", "sage", "oracle", "prophet", "champion", "guardian", "sentinel",
    "watcher", "keeper", "protector", "defender", "warrior", "hero", "artist",
    "painter", "sculptor", "musician", "composer", "poet", "writer", "dreamer",
    "thinker", "scholar", "scientist", "inventor", "creator", "builder", "architect",
    "engineer",
  ]

  static func stableHash(_ string: String) -> Int {
    var hash: Int32 = 0

    for codeUnit in string.utf16 {
      hash = (hash &* 31) &+ Int32(codeUnit)
    }

    return Int(abs(Int64(hash)))
  }

  static func emailUsername(_ email: String?) -> String? {
    guard let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmedEmail.isEmpty else {
      return nil
    }

    return trimmedEmail.split(separator: "@").first.map(String.init)
  }

  static func generateVisitorName(seed: String) -> String {
    let hash = stableHash(seed)
    let adjective = adjectives[hash % adjectives.count]
    let noun = nouns[(hash >> 8) % nouns.count]
    return "\(adjective.capitalized) \(noun.capitalized)"
  }

  static func visitorDisplayName(
    contactName: String?,
    email: String?,
    visitorID: String
  ) -> String {
    if let trimmedName = contactName?.trimmingCharacters(in: .whitespacesAndNewlines),
       !trimmedName.isEmpty {
      return trimmedName
    }

    return emailUsername(email) ?? generateVisitorName(seed: visitorID)
  }

  static func contactDisplayName(
    name: String?,
    email: String?,
    contactID: String
  ) -> String {
    if let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines),
       !trimmedName.isEmpty {
      return trimmedName
    }

    return emailUsername(email) ?? generateVisitorName(seed: contactID)
  }

  static func initials(for value: String) -> String {
    let words = value
      .split(whereSeparator: \.isWhitespace)
      .prefix(2)
      .compactMap { $0.first.map(String.init) }

    let joined = words.joined()
    if !joined.isEmpty {
      return joined.uppercased()
    }

    return String(value.prefix(1)).uppercased()
  }
}
