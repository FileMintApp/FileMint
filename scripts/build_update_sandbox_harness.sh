#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
python3 scripts/native_qa.py check-stopped update-sandbox
swift build --package-path CorePackage
CORE_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
if [[ -f "$CORE_BUILD/libFileMintCore.a" ]]; then
  CORE_LINK=(-I "$CORE_BUILD" "$CORE_BUILD/libFileMintCore.a")
else
  CORE_LINK=(-I "$CORE_BUILD/Modules" "$CORE_BUILD"/FileMintCore.build/*.o)
fi
mkdir -p "$PWD/build/update-sandbox-harness.noindex"
SMOKE_DIRECTORY="$(mktemp -d "$PWD/build/update-sandbox-harness.noindex/run.XXXXXX")"
APP_PATH="$SMOKE_DIRECTORY/FileMintUpdateSandboxSmoke.app"
mkdir -p "$APP_PATH/Contents/MacOS"
cp scripts/update-sandbox-smoke/Info.plist "$APP_PATH/Contents/Info.plist"
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.0 \
  App/FileMint/UpdateClient.swift scripts/update_sandbox_smoke.swift \
  "${CORE_LINK[@]}" -o "$APP_PATH/Contents/MacOS/FileMintUpdateSandboxSmoke"
codesign --force --options runtime --sign - --timestamp=none \
  --entitlements scripts/update-sandbox-smoke/entitlements.plist "$APP_PATH"
codesign --verify --strict "$APP_PATH"
echo "Built sandboxed harness (interactive checks still required):"
python3 scripts/native_qa.py publish update-sandbox "$APP_PATH" "$SMOKE_DIRECTORY"
