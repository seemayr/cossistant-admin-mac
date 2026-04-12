import Foundation

struct DashboardVisitorPresence: Equatable, Sendable {
  enum State: String, Sendable {
    case active
    case inactive
  }

  let visitorId: String
  let state: State
  let lastSeenAt: String?

  var isActive: Bool {
    state == .active
  }
}
