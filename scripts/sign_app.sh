#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_PATH="${1:-$PWD/build/DerivedData/Build/Products/Release/FileMint.app}"
IDENTITY="${APPLE_CODESIGN_IDENTITY:-${CODESIGN_IDENTITY:-}}"
TIMESTAMP="${CODESIGN_TIMESTAMP:---timestamp}"

if [[ -z "$IDENTITY" ]]; then
  echo "APPLE_CODESIGN_IDENTITY or CODESIGN_IDENTITY is required."
  exit 2
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH"
  exit 2
fi

FINDER_SYNC_PATH="$APP_PATH/Contents/PlugIns/FileMintFinderSync.appex"

if [[ ! -d "$FINDER_SYNC_PATH" ]]; then
  echo "Finder Sync extension not found: $FINDER_SYNC_PATH"
  exit 2
fi

codesign \
  --force \
  $TIMESTAMP \
  --options runtime \
  --entitlements Config/FileMintFinderSync.entitlements \
  --sign "$IDENTITY" \
  "$FINDER_SYNC_PATH"

codesign \
  --force \
  $TIMESTAMP \
  --options runtime \
  --entitlements Config/FileMint.entitlements \
  --sign "$IDENTITY" \
  "$APP_PATH"

codesign --verify --strict --deep --verbose=2 "$APP_PATH"

echo "Signed app:"
echo "$APP_PATH"
