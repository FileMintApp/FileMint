#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_PATH="${1:-$PWD/build/DerivedData/Build/Products/Release/FileMint.app}"
DMG_ROOT="$PWD/build/dmg-root"
DMG_PATH="${DMG_PATH:-$PWD/build/FileMint.dmg}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH"
  echo "Run: make build"
  exit 2
fi

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"
ditto "$APP_PATH" "$DMG_ROOT/FileMint.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "FileMint" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "$DMG_PATH"
