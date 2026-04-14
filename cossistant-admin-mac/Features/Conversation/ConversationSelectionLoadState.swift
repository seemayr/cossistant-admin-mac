enum ConversationSelectionLoadState: Hashable {
  case idle
  case loading
  case loaded
  case failed(String)
}
