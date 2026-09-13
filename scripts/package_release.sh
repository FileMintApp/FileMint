#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${APP_VERSION:-0.3.0}"
BUILD_NUMBER="${BUILD_NUMBER:-3}"
APP_PATH="$PWD/build/DerivedData/Build/Products/Release/FileMint.app"
DMG_PATH="$PWD/build/FileMint-$VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"
IDENTITY="${APPLE_CODESIGN_IDENTITY:-${CODESIGN_IDENTITY:--}}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid release version"; exit 2; }
if [[ "${NOTARIZE:-0}" == "1" && "$IDENTITY" == "-" ]]; then
  echo "Notarization needs a Developer ID identity; ad-hoc signing is not Apple certification."
  exit 2
fi
export MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
export CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
./scripts/build_release.sh
./scripts/sign_app.sh "$APP_PATH"
./scripts/verify_bundle.sh "$APP_PATH"
DMG_PATH="$DMG_PATH" ./scripts/make_dmg.sh "$APP_PATH"
if [[ "$IDENTITY" != "-" ]]; then codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"; fi
if [[ "${NOTARIZE:-0}" == "1" ]]; then ./scripts/notarize_dmg.sh "$DMG_PATH"; fi
# Basename-only checksums work in any user's download directory.
(cd "$(dirname "$DMG_PATH")" && shasum -a 256 "$(basename "$DMG_PATH")") > "$CHECKSUM_PATH"
hdiutil verify "$DMG_PATH"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "dmg_path=$DMG_PATH"
    echo "checksum_path=$CHECKSUM_PATH"
    echo "version=$VERSION"
  } >> "$GITHUB_OUTPUT"
fi
echo "Packaged $DMG_PATH"
