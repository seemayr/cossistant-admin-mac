# AGENTS.md

## Project Shape

- macOS SwiftUI app in `cossistant-mac/`
- Xcode project: `cossistant-mac.xcodeproj`
- Main architecture layers:
  - `cossistant-mac/App/` for scenes and workspace shell
  - `cossistant-mac/Features/` for feature UI and feature stores
  - `cossistant-mac/Core/Domain/` for portable Foundation-first models
  - `cossistant-mac/Core/Application/` for reusable workflows/coordinators
  - `cossistant-mac/Core/Infrastructure/` for API, persistence, realtime, secrets, prompting
  - `cossistant-mac/Platform/macOS/` for AppKit/macOS-only helpers
  - `cossistant-mac/SharedUI/` for reusable UI primitives

## Where To Start

- App entry: `cossistant-mac/App/CossistantMacApp.swift`
- Workspace scene/root: `cossistant-mac/App/Scenes/WorkspaceSceneView.swift`
- Workspace shell/state composition: `cossistant-mac/App/Workspace/WorkspaceModel.swift`
- Conversation feature: `cossistant-mac/Features/Conversation/`
- Inbox feature: `cossistant-mac/Features/Inbox/`

## Working Rules

- Keep new code inside the current layer boundaries. Do not reintroduce generic `Views/`, `Stores/`, or `Services/` buckets.
- Prefer feature-owned UI/state and small dedicated files over broad monoliths.
- Keep `Core/Domain` and `Core/Application` portable. Avoid `SwiftUI`, `AppKit`, and macOS-only APIs there.
- Put macOS-only behavior in `Platform/macOS/`.
- Treat naming cleanup as product-language cleanup, not arbitrary churn.

## Skills And Tools

- Always use `swift-style` for Swift/SwiftUI edits.
- Use `build-macos-apps:view-refactor` for scene/view restructuring.
- Use `build-macos-apps:swiftui-patterns` for macOS SwiftUI composition decisions.
- Use `build-macos-apps:appkit-interop` when touching file panels, clipboard, windows, or AppKit bridges.
- Use `build-macos-apps:build-run-debug` when verifying runtime/build issues.
- Use `sosumi` for Apple platform/API documentation instead of guessing framework behavior.

## Verification

- Preferred build check:
  - `xcodebuild -quiet -project 'cossistant-mac.xcodeproj' -scheme 'cossistant-mac' -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`
- Repo helper:
  - `./script/build_and_run.sh`
