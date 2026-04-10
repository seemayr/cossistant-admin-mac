import Foundation

enum JSONValue: Codable, Hashable, Sendable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case object([String: JSONValue])
  case array([JSONValue])
  case null

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unsupported JSON value."
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case .string(let value):
      try container.encode(value)
    case .number(let value):
      try container.encode(value)
    case .bool(let value):
      try container.encode(value)
    case .object(let value):
      try container.encode(value)
    case .array(let value):
      try container.encode(value)
    case .null:
      try container.encodeNil()
    }
  }
}

extension JSONValue {
  func dashboardDecoded<Value: Decodable>(as type: Value.Type) -> Value? {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    guard let data = try? encoder.encode(self) else {
      return nil
    }

    return try? decoder.decode(type, from: data)
  }

  var dashboardPrettyPrintedJSONString: String? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(self) else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  nonisolated static func dashboardValue(from foundationValue: Any) throws -> JSONValue {
    switch foundationValue {
    case let value as String:
      return .string(value)
    case let value as Bool:
      return .bool(value)
    case let value as NSNumber:
      return .number(value.doubleValue)
    case let value as [String: Any]:
      return .object(
        try value.reduce(into: [String: JSONValue]()) { result, entry in
          result[entry.key] = try dashboardValue(from: entry.value)
        }
      )
    case let value as [Any]:
      return .array(try value.map(dashboardValue(from:)))
    case _ as NSNull:
      return .null
    default:
      throw JSONValueConversionError.unsupportedType
    }
  }

  var dashboardDisplayText: String {
    switch self {
    case .string(let value):
      return value
    case .number(let value):
      if value.rounded(.towardZero) == value {
        return String(Int(value))
      }
      return value.formatted()
    case .bool(let value):
      return value ? "true" : "false"
    case .object(let value):
      return value
        .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        .map { "\($0.key): \($0.value.dashboardDisplayText)" }
        .joined(separator: ", ")
    case .array(let value):
      return value
        .map(\.dashboardDisplayText)
        .joined(separator: ", ")
    case .null:
      return "null"
    }
  }

  var dashboardSearchText: String {
    switch self {
    case .object(let value):
      return value
        .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        .flatMap { [$0.key, $0.value.dashboardSearchText] }
        .joined(separator: " ")
    case .array(let value):
      return value
        .map(\.dashboardSearchText)
        .joined(separator: " ")
    default:
      return dashboardDisplayText
    }
  }
}

private enum JSONValueConversionError: Error {
  case unsupportedType
}

extension Dictionary where Key == String, Value == JSONValue {
  var dashboardSortedEntries: [(String, JSONValue)] {
    sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
  }

  var dashboardSearchText: String {
    dashboardSortedEntries
      .flatMap { [$0.0, $0.1.dashboardSearchText] }
      .joined(separator: " ")
  }

  var dashboardPrettyPrintedJSONString: String? {
    JSONValue.object(self).dashboardPrettyPrintedJSONString
  }
}
