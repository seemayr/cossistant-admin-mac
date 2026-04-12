import Foundation

enum DashboardTimestampParser {
  static func date(from value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }

    for formatter in formatters {
      if let date = formatter.date(from: value) {
        return date
      }
    }

    return nil
  }

  static func relativeString(from value: String?) -> String? {
    guard let date = date(from: value) else { return value }
    return RelativeDateTimeFormatter.dashboard.localizedString(for: date, relativeTo: .now)
  }

  static func absoluteString(from value: String?) -> String? {
    guard let date = date(from: value) else { return value }
    return DateFormatter.dashboardDateTime.string(from: date)
  }

  private static let formatters: [ISO8601DateFormatter] = [
    .withFractionalSeconds,
    .internetDateTime,
  ]
}

extension DateFormatter {
  static let dashboardDateTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()
}
