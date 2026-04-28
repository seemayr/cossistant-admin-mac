import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  var searchText: String {
    get { inboxStore.searchText }
    set { inboxStore.searchText = newValue }
  }

  var inboxSortMode: InboxSortMode {
    get { inboxStore.sortMode }
    set { inboxStore.sortMode = newValue }
  }

  var inboxPriorityFilter: InboxPriorityFilter {
    get { inboxStore.priorityFilter }
    set { inboxStore.priorityFilter = newValue }
  }

  var inboxSentimentFilter: InboxSentimentFilter {
    get { inboxStore.sentimentFilter }
    set { inboxStore.sentimentFilter = newValue }
  }

  var inboxChannelFilter: String? {
    get { inboxStore.channelFilter }
    set { inboxStore.channelFilter = newValue }
  }

  var inboxMetadataFilters: [InboxMetadataFilterKey: JSONValue] {
    get { inboxStore.metadataFilters }
    set { inboxStore.metadataFilters = newValue }
  }

  var inboxHideEmptyConversations: Bool {
    get { inboxStore.hideEmptyConversations }
    set { inboxStore.hideEmptyConversations = newValue }
  }

  var inboxHideSeenConversations: Bool {
    get { inboxStore.hideSeenConversations }
    set { inboxStore.hideSeenConversations = newValue }
  }

  var conversations: [DashboardConversation] {
    get { inboxStore.conversations }
    set { inboxStore.conversations = newValue }
  }

  var nextCursor: String? {
    get { inboxStore.nextCursor }
    set { inboxStore.nextCursor = newValue }
  }

  var loadedInboxPageCount: Int {
    get { inboxStore.loadedPageCount }
    set { inboxStore.loadedPageCount = newValue }
  }

  var visitorSearchIndex: [String: String] {
    get { inboxStore.visitorSearchIndex }
    set { inboxStore.visitorSearchIndex = newValue }
  }

  var isLoadingMore: Bool {
    get { inboxStore.isLoadingMore }
    set { inboxStore.isLoadingMore = newValue }
  }

  var filteredConversations: [DashboardConversation] {
    inboxStore.filteredConversations
  }

  var hasActiveConversationFilters: Bool {
    inboxStore.hasActiveConversationFilters
  }

  var availableInboxMetadataFilters: [InboxMetadataFilterSection] {
    inboxStore.availableMetadataFilters
  }

  var availableInboxChannelFilters: [InboxChannelFilterOption] {
    inboxStore.availableChannelFilters
  }

  var canLoadMore: Bool {
    inboxStore.canLoadMore
  }
}
