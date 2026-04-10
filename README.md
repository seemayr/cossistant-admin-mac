# cossistant-mac

Native macOS client for working with Cossistant inbox conversations.

## Requirements

- macOS with Xcode 26 or newer

## Running locally

### Option 1: Xcode

1. Open `cossistant-mac.xcodeproj` in Xcode.
2. Build and run the `cossistant-mac` scheme.

### Option 2: Script

```bash
./script/build_and_run.sh
```

The script builds with code signing disabled and writes build output to `build/DerivedData/`.

## First launch setup

Create a profile in the app and provide:

- API base URL, for example `https://api.cossistant.com/v1`
- A private API key for the target Cossistant environment

Optional global settings:

- Google Cloud Translate API key for message translation
- OpenAI API key for reply drafting and analytics summaries

Secrets are stored locally in the macOS Keychain and are not read from the repository.

## Open source hygiene

This repository ignores local Xcode user data, local Codex state, and build artifacts by default.
Do not commit real API keys, local environment exports, or generated `build/` contents.

