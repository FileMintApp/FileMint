#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP_PATH="${1:-$PWD/build/DerivedData/Build/Products/Release/FileMint.app}"
IDENTITY="${APPLE_CODESIGN_IDENTITY:-${CODESIGN_IDENTITY:--}}"
EXTENSION_PATH="$APP_PATH/Contents/PlugIns/FileMintFinderSync.appex"
[[ -d "$EXTENSION_PATH" ]] || { echo "Missing Finder extension: $EXTENSION_PATH"; exit 2; }
ENTITLEMENTS_WORK="$(mktemp -d /private/tmp/filemint-signing-entitlements.XXXXXX)"
trap 'rm -f "$ENTITLEMENTS_WORK/app.plist" "$ENTITLEMENTS_WORK/finder.plist"; rmdir "$ENTITLEMENTS_WORK"' EXIT
python3 scripts/prepare_signing_entitlements.py Config/FileMint.entitlements \
  "$APP_PATH/Contents/Info.plist" "$ENTITLEMENTS_WORK/app.plist"
python3 scripts/prepare_signing_entitlements.py Config/FileMintFinderSync.entitlements \
  "$EXTENSION_PATH/Contents/Info.plist" "$ENTITLEMENTS_WORK/finder.plist"
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
# Xcode embeds Sparkle's universal XCFramework slice. Strip Intel code from the
# copied bundle before signing so the shipped app contains arm64 executables only.
thin_arm64() {
  local executable="$1" architectures temporary
  architectures="$(lipo -archs "$executable")"
  if [[ "$architectures" == arm64 ]]; then return; fi
  [[ " $architectures " == *" arm64 "* ]] || {
    echo "Missing arm64 code: $executable ($architectures)" >&2
    return 1
  }
  temporary="$(mktemp "${executable}.arm64.XXXXXX")"
  if ! lipo "$executable" -thin arm64 -output "$temporary"; then
    rm -f "$temporary"
    return 1
  fi
  mv -f "$temporary" "$executable"
}
for executable in "$SPARKLE/Versions/B/Sparkle" "$SPARKLE/Versions/B/Autoupdate" \
  "$SPARKLE/Versions/B/Updater.app/Contents/MacOS/Updater" \
  "$SPARKLE/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer" \
  "$SPARKLE/Versions/B/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"; do
  thin_arm64 "$executable"
done
for component in XPCServices/Installer.xpc XPCServices/Downloader.xpc Autoupdate Updater.app; do
  codesign "${SIGN_ARGS[@]}" --preserve-metadata=entitlements "$SPARKLE/Versions/B/$component"
done
codesign "${SIGN_ARGS[@]}" "$SPARKLE"
codesign "${SIGN_ARGS[@]}" --entitlements "$ENTITLEMENTS_WORK/finder.plist" "$EXTENSION_PATH"
codesign "${SIGN_ARGS[@]}" --entitlements "$ENTITLEMENTS_WORK/app.plist" "$APP_PATH"
codesign --verify --strict --deep --verbose=2 "$APP_PATH"
xcrun swift scripts/verify_signed_entitlements.swift "$APP_PATH"
echo "Signed bundle ($IDENTITY): $APP_PATH"
