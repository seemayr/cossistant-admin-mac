#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="cossistant-admin-mac"
SCHEME="cossistant-admin-mac"
CONFIGURATION="Debug"
BUNDLE_ID="earth.mizo.cossistant-admin-mac"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/cossistant-admin-mac.xcodeproj"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

kill_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

build_app() {
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    DEVELOPMENT_TEAM="" \
    build
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

stream_logs() {
  /usr/bin/log stream --style compact --info --predicate "process == \"$APP_NAME\""
}

stream_telemetry() {
  /usr/bin/log stream --style compact --info --predicate "subsystem == \"$BUNDLE_ID\""
}

kill_app
build_app

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    stream_logs
    ;;
  --telemetry|telemetry)
    open_app
    stream_telemetry
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
