#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE_NAME="${RIVER_SIMULATOR_NAME:-Poker iPhone 16}"
DEVICE_ID="${RIVER_SIMULATOR_UDID:-}"
DERIVED_DATA="${RIVER_DERIVED_DATA_PATH:-/tmp/river-messages-derived-data}"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/RiverMessages.app"

find_device() {
    local state="$1"
    xcrun simctl list devices available | awk -v name="$DEVICE_NAME" -v state="$state" '
        index($0, name " (") && (!state || index($0, "(" state ")")) {
            if (match($0, /\([0-9A-F-]+\)/)) {
                print substr($0, RSTART + 1, RLENGTH - 2)
                exit
            }
        }
    '
}

if [[ -z "$DEVICE_ID" ]]; then
    DEVICE_ID="$(find_device Booted)"
    [[ -n "$DEVICE_ID" ]] || DEVICE_ID="$(find_device "")"
fi

if [[ -z "$DEVICE_ID" ]]; then
    print -u2 "No available '$DEVICE_NAME' simulator. Set RIVER_SIMULATOR_UDID."
    exit 1
fi

xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || :
xcrun simctl bootstatus "$DEVICE_ID" -b

xcodebuild \
    -project "$ROOT/River.xcodeproj" \
    -scheme RiverMessages \
    -destination "platform=iOS Simulator,id=$DEVICE_ID" \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet \
    build-for-testing

if [[ ! -d "$APP_PATH" ]]; then
    print -u2 "RiverMessages build not found at $APP_PATH"
    exit 1
fi

xcrun simctl terminate "$DEVICE_ID" com.apple.MobileSMS >/dev/null 2>&1 || :
xcrun simctl uninstall "$DEVICE_ID" com.dewylabs.river >/dev/null 2>&1 || :
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

xcodebuild \
    -project "$ROOT/River.xcodeproj" \
    -scheme RiverMessages \
    -destination "platform=iOS Simulator,id=$DEVICE_ID" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:RiverMessagesInteractionTests \
    -quiet \
    test-without-building
