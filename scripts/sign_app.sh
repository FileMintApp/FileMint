#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP_PATH="${1:-$PWD/build/DerivedData/Build/Products/Release/FileMint.app}"
IDENTITY="${APPLE_CODESIGN_IDENTITY:-${CODESIGN_IDENTITY:--}}"
EXTENSION_PATH="$APP_PATH/Contents/PlugIns/FileMintFinderSync.appex"
[[ -d "$EXTENSION_PATH" ]] || { echo "Missing Finder extension: $EXTENSION_PATH"; exit 2; }
SIGN_ARGS=(--force --options runtime --sign "$IDENTITY")
if [[ "$IDENTITY" == "-" ]]; then
  SIGN_ARGS+=(--timestamp=none)
  # An old local development build may have left profiles in DerivedData.
  rm -f "$APP_PATH/Contents/embedded.provisionprofile" "$EXTENSION_PATH/Contents/embedded.provisionprofile"
else
  SIGN_ARGS+=(--timestamp)
fi
# Sign from the inside out. Code Sign on Copy does not re-sign nested helpers.
SPARKLE="$APP_PATH/Contents/Frameworks/Sparkle.framework"
[[ -d "$SPARKLE" ]] || { echo 'Missing Sparkle framework' >&2; exit 2; }
for component in XPCServices/Installer.xpc XPCServices/Downloader.xpc Autoupdate Updater.app; do
  codesign "${SIGN_ARGS[@]}" --preserve-metadata=entitlements "$SPARKLE/Versions/B/$component"
done
codesign "${SIGN_ARGS[@]}" "$SPARKLE"
codesign "${SIGN_ARGS[@]}" --entitlements Config/FileMintFinderSync.entitlements "$EXTENSION_PATH"
codesign "${SIGN_ARGS[@]}" --entitlements Config/FileMint.entitlements "$APP_PATH"
codesign --verify --strict --deep --verbose=2 "$APP_PATH"
echo "Signed bundle ($IDENTITY): $APP_PATH"
