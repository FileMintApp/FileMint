#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --package-path CorePackage
CORE_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
mkdir -p "$PWD/build/update-sandbox-harness.noindex"
SMOKE_DIRECTORY="$(mktemp -d "$PWD/build/update-sandbox-harness.noindex/run.XXXXXX")"
APP_PATH="$SMOKE_DIRECTORY/FileMintUpdateSandboxSmoke.app"
mkdir -p "$APP_PATH/Contents/MacOS"
cp scripts/update-sandbox-smoke/Info.plist "$APP_PATH/Contents/Info.plist"
swiftc -swift-version 6 -parse-as-library -I "$CORE_BUILD/Modules" \
  App/FileMint/UpdateClient.swift scripts/update_sandbox_smoke.swift \
  "$CORE_BUILD"/FileMintCore.build/*.o -o "$APP_PATH/Contents/MacOS/FileMintUpdateSandboxSmoke"
codesign --force --options runtime --sign - --timestamp=none \
  --entitlements scripts/update-sandbox-smoke/entitlements.plist "$APP_PATH"
codesign --verify --strict "$APP_PATH"
echo "Built sandboxed harness (interactive checks still required):"
echo "$APP_PATH"
