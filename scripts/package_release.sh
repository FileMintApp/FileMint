#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${APP_VERSION:-${MARKETING_VERSION:-0.1.0}}"
BUILD_NUMBER="${BUILD_NUMBER:-${CURRENT_PROJECT_VERSION:-1}}"
APP_PATH="$PWD/build/DerivedData/Build/Products/Release/FileMint.app"
DMG_PATH="$PWD/build/FileMint-$VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"
IDENTITY="${APPLE_CODESIGN_IDENTITY:-${CODESIGN_IDENTITY:-}}"

if [[ "${RELEASE_REQUIRE_SIGNING:-0}" == "1" && -z "$IDENTITY" ]]; then
  echo "Release packaging requires APPLE_CODESIGN_IDENTITY or CODESIGN_IDENTITY."
  exit 2
fi

export MARKETING_VERSION="$VERSION"
export CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
export CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"
export CODE_SIGNING_REQUIRED="${CODE_SIGNING_REQUIRED:-NO}"

./scripts/build_release.sh

if [[ -n "$IDENTITY" ]]; then
  ./scripts/sign_app.sh "$APP_PATH"
else
  echo "Skipping code signing; the DMG will be suitable for development only."
fi

DMG_PATH="$DMG_PATH" ./scripts/make_dmg.sh "$APP_PATH"

if [[ -n "$IDENTITY" ]]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"
fi

if [[ "${NOTARIZE:-0}" == "1" ]]; then
  ./scripts/notarize_dmg.sh "$DMG_PATH"
fi

shasum -a 256 "$DMG_PATH" > "$CHECKSUM_PATH"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "dmg_path=$DMG_PATH"
    echo "checksum_path=$CHECKSUM_PATH"
    echo "version=$VERSION"
    echo "build_number=$BUILD_NUMBER"
  } >> "$GITHUB_OUTPUT"
fi

echo "Packaged release:"
echo "$DMG_PATH"
echo "$CHECKSUM_PATH"
