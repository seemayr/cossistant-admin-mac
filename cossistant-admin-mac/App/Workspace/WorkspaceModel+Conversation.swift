import Foundation
import CossistantAdmin

@MainActor
extension WorkspaceModel {
  func selectConversation(_ conversationID: DashboardConversation.ID?) {
    if conversationID == selectedConversationID,
       conversationStore.selectedConversationDetail?.id == conversationID,
       conversationStore.selectedConversationLoadState == .loaded {
      return
    }

    selectedConversationLoadTask?.cancel()
    selectedConversationLoadTask = nil
    selectedConversationID = conversationID

    guard let conversationID else {
      clearSelectedConversationState()
      return
    }

    let listSnapshot = inboxStore.conversation(withID: conversationID)
    conversationStore.prepareSelection(listSnapshot)
    guard website != nil else { return }

    selectedConversationLoadTask = Task { [weak self] in
      guard let self else { return }
      await self.loadSelectedConversation(showsLoadingState: false)
    }
  }

  func loadSelectedConversation(
    force: Bool = false,
    showsLoadingState: Bool = true
  ) async {
    guard let conversationID = selectedConversationID else {
      clearSelectedConversationState()
      return
    }

    let listSnapshot = inboxStore.conversation(withID: conversationID)

    if !force,
       conversationStore.selectedConversationDetail?.id == conversationID,
       conversationStore.selectedConversationLoadState == .loaded {
      return
    }

    if showsLoadingState {
      clearSelectedConversationState()
      conversationStore.selectedConversationListSnapshot = listSnapshot
      conversationStore.selectedConversationLoadState = .loading
    } else if conversationStore.selectedConversationListSnapshot?.id != conversationID {
      conversationStore.selectedConversationListSnapshot = listSnapshot
    }

    if DashboardReadDebug.isTargetConversation(conversationID) {
      DashboardReadDebug.log(
        "WorkspaceModel.loadSelectedConversation",
        "start force=\(force) showsLoadingState=\(showsLoadingState) selectedLoadState=\(conversationStore.selectedConversationLoadState)"
      )
    }

    do {
      let configuration = self.configuration
      let visitorID = selectedConversation?.visitorId
      async let detail: DashboardConversationDetail = {
        let client = CossistantAdminClient(configuration: configuration)
        return try await client.conversations.fetchConversation(id: conversationID)
      }()
      async let timeline: DashboardTimelinePage = {
        let client = CossistantAdminClient(configuration: configuration)
        return try await client.conversations.fetchTimeline(conversationID: conversationID)
      }()
      async let seenData: [DashboardConversationSeen] = {
        let client = CossistantAdminClient(configuration: configuration)
        return try await client.conversations.fetchConversationSeenData(
          conversationID: conversationID
        )
      }()
      let resolvedVisitor: DashboardVisitor?
      if let visitorID {
        let client = CossistantAdminClient(configuration: configuration)
        resolvedVisitor = try await client.visitors.fetchVisitor(id: visitorID)
      } else {
        resolvedVisitor = nil
      }
      let (resolvedDetail, resolvedTimeline, resolvedSeenData) = try await (
        detail,
        timeline,
        seenData
      )

      guard selectedConversationID == conversationID else { return }

      conversationStore.applyLoadedSelection(
        detail: resolvedDetail,
        visitor: resolvedVisitor,
        seenData: resolvedSeenData,
        timelinePage: resolvedTimeline
      )
      cacheSearchVisitor(resolvedVisitor)
      syncConversationSeenState(
        conversationID: conversationID,
        with: resolvedSeenData,
        fallbackCurrentActorSeenAt: nil
      )

      if DashboardReadDebug.isTargetConversation(conversationID),
         let trackedConversation = conversations.first(where: { $0.id == conversationID }) {
        DashboardReadDebug.log(
          "WorkspaceModel.loadSelectedConversation",
          "loaded \(DashboardReadDebug.conversationSummary(trackedConversation)) seenData=\(DashboardReadDebug.seenDataSummary(resolvedSeenData)) timelineCount=\(resolvedTimeline.items.count)"
        )
      }

      if conversationStore.showTranslations {
        await loadTranslationsForSelectedConversationIfNeeded(force: true)
      }
    } catch {
      guard selectedConversationID == conversationID else { return }
      guard !isIgnorableCancellation(error) else { return }
      if showsLoadingState {
        clearSelectedConversationState()
      }
      conversationStore.markSelectionFailed(error.localizedDescription)
      setGlobalErrorMessage(error)
    }
  }

  func loadMoreTimeline() async {
    guard let conversationID = selectedConversationID,
          let cursor = conversationStore.selectedTimelineNextCursor,
          !conversationStore.isLoadingMoreTimeline else {
      return
    }

    conversationStore.isLoadingMoreTimeline = true
    defer { conversationStore.isLoadingMoreTimeline = false }

    do {
      let page = try await backendClient.conversations.fetchTimeline(
        conversationID: conversationID,
        cursor: cursor
      )

      guard selectedConversationID == conversationID else { return }

      conversationStore.appendTimelinePage(page)

      if conversationStore.showTranslations {
        await loadTranslationsForSelectedConversationIfNeeded()
      }
    } catch {
      setGlobalErrorMessage(error)
    }
  }

  func setShowMessageTranslations(_ isEnabled: Bool) async {
    conversationStore.setShowTranslations(isEnabled)

    guard isEnabled else { return }

    await loadTranslationsForSelectedConversationIfNeeded(force: true)
  }

  func loadTranslationsForSelectedConversationIfNeeded(
    force: Bool = false
  ) async {
    guard conversationStore.showTranslations else { return }

    let messages = conversationStore.selectedTimelineItems
      .filter { $0.type == .message }
      .filter { $0.deletedAt == nil }
      .filter { ($0.renderedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) == false }

    seedStoredTranslations(for: messages, force: force)
    conversationStore.translationErrorMessage = nil

    let untranslated = messages.filter { item in
      storedTeamTranslation(for: item) == nil
        && (force || conversationStore.translatedMessagesByID[item.id] == nil)
    }
    let clarificationQuestion = selectedConversation?.activeClarification?.question?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if clarificationQuestion?.isEmpty != false {
      conversationStore.translatedClarification = nil
    }
    let shouldTranslateClarification = (clarificationQuestion?.isEmpty == false)
      && (force || conversationStore.translatedClarification == nil)

    guard !untranslated.isEmpty || shouldTranslateClarification else { return }
    guard globalSettings.hasGoogleCloudTranslateAPIKey else {
      conversationStore.translationErrorMessage = "Add a Google Cloud Translate API key in settings to translate messages that do not already include a stored translation."
      return
    }

    conversationStore.isTranslatingMessages = true
    conversationStore.translationErrorMessage = nil
    defer { conversationStore.isTranslatingMessages = false }

    do {
      let client = GoogleCloudTranslateClient(apiKey: globalSettings.trimmedGoogleCloudTranslateAPIKey)
      var texts = untranslated.compactMap(\.renderedText)
      if let clarificationQuestion, !clarificationQuestion.isEmpty, shouldTranslateClarification {
        texts.append(clarificationQuestion)
      }
      let translations = try await client.translate(
        texts: texts,
        targetLanguageCode: Self.preferredTranslationLanguageCode
      )

      for (item, translation) in zip(untranslated, translations) {
        conversationStore.translatedMessagesByID[item.id] = translation
      }

      if shouldTranslateClarification,
         translations.count > untranslated.count {
        conversationStore.translatedClarification = translations[untranslated.count]
      }
    } catch {
      conversationStore.translationErrorMessage = error.localizedDescription
    }
  }

  static var preferredTranslationLanguageCode: String {
    if let preferred = Locale.preferredLanguages.first {
      let locale = Locale(identifier: preferred)
      if #available(macOS 13.0, *) {
        if let code = locale.language.languageCode?.identifier {
          return code
        }
      }

      if let code = preferred.split(separator: "-").first {
        return String(code)
      }
    }

    return "en"
  }

  private func seedStoredTranslations(
    for messages: [DashboardTimelineItem],
    force: Bool
  ) {
    for item in messages {
      guard let translation = storedTeamTranslation(for: item) else { continue }
      if force || conversationStore.translatedMessagesByID[item.id] == nil {
        conversationStore.translatedMessagesByID[item.id] = translation
      }
    }
  }

  func hasStoredTeamTranslation(for item: DashboardTimelineItem) -> Bool {
    storedTeamTranslation(for: item) != nil
  }

  private func storedTeamTranslation(
    for item: DashboardTimelineItem
  ) -> DashboardMessageTranslation? {
    let teamTranslations = item.translationParts
      .filter { $0.audience == "team" }
      .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    guard !teamTranslations.isEmpty else { return nil }

    let preferredLanguage = Self.preferredTranslationLanguageCode
    let exactMatch = teamTranslations.last {
      languageTagsMatch($0.targetLanguage, preferredLanguage)
    }

    let resolved = exactMatch ?? teamTranslations.last!
    return DashboardMessageTranslation(
      text: resolved.text,
      detectedSourceLanguage: resolved.sourceLanguage
    )
  }

  private func languageTagsMatch(_ lhs: String?, _ rhs: String?) -> Bool {
    normalizedLanguageTag(lhs) == normalizedLanguageTag(rhs)
  }

  private func normalizedLanguageTag(_ value: String?) -> String? {
    guard let value else { return nil }
    return value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: "_", with: "-")
      .split(separator: "-")
      .first
      .map(String.init)
  }
}
