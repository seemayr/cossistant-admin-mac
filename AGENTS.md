# AGENTS.md

## Project Shape

- macOS SwiftUI app in `cossistant-admin-mac/`
- Xcode project: `cossistant-admin-mac.xcodeproj`
- Shared backend SDK lives in the sibling package `../cossistant-admin-swift`
- Main app layers:
  - `cossistant-admin-mac/App/` for scenes, workspace shell, app persistence, and mac-only AI wiring
  - `cossistant-admin-mac/Features/` for feature UI, feature stores, and app-side workflows
  - `cossistant-admin-mac/Platform/macOS/` for AppKit/macOS-only helpers
  - `cossistant-admin-mac/SharedUI/` for reusable UI primitives

## Where To Start

- App entry: `cossistant-admin-mac/App/CossistantAdminMacApp.swift`
- Workspace scene/root: `cossistant-admin-mac/App/Scenes/WorkspaceSceneView.swift`
- Workspace shell/state composition: `cossistant-admin-mac/App/Workspace/WorkspaceModel.swift`
- Shared SDK entrypoint: `../cossistant-admin-swift/Sources/CossistantAdmin/Client/CossistantAdminClient.swift`
- Conversation feature: `cossistant-admin-mac/Features/Conversation/`
- Inbox feature: `cossistant-admin-mac/Features/Inbox/`

## Working Rules

- Keep new code inside the current layer boundaries. Do not reintroduce generic `Views/`, `Stores/`, or `Services/` buckets.
- Prefer feature-owned UI/state and small dedicated files over broad monoliths.
- Keep backend logic in `cossistant-admin-swift`. Do not move `SwiftUI`, `AppKit`, `Observation`, prompts, or host-app persistence into the package.
- App-side code should depend on `CossistantAdminClient`, not construct `CossistantAPIClient` directly.
- Keep Google Translate, OpenAI, prompts, and local profile/settings persistence on the app side.
- Put macOS-only behavior in `Platform/macOS/`.

## Skills And Tools

- Always use `swift-style` for Swift/SwiftUI edits.
- Use `build-macos-apps:view-refactor` for scene/view restructuring.
- Use `build-macos-apps:swiftui-patterns` for macOS SwiftUI composition decisions.
- Use `build-macos-apps:appkit-interop` when touching file panels, clipboard, windows, or AppKit bridges.
- Use `build-macos-apps:build-run-debug` when verifying runtime/build issues.
- Use `sosumi` for Apple platform/API documentation instead of guessing framework behavior.

## Verification

- Preferred build check:
  - `xcodebuild -quiet -project 'cossistant-admin-mac.xcodeproj' -scheme 'cossistant-admin-mac' -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`
- Repo helper:
  - `./script/build_and_run.sh`
