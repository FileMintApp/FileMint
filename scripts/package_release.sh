#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${APP_VERSION:-0.5.1}"
BUILD_NUMBER="${BUILD_NUMBER:-6}"
OUTPUT_DIR="${FILEMINT_OUTPUT_DIR:-$PWD/build}"
DMG_PATH="$OUTPUT_DIR/FileMint-$VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"
IDENTITY="${APPLE_CODESIGN_IDENTITY:-${CODESIGN_IDENTITY:--}}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid release version"; exit 2; }
mkdir -p "$OUTPUT_DIR"
if [[ "${NOTARIZE:-0}" == "1" && "$IDENTITY" == "-" ]]; then
  echo "Notarization needs a Developer ID identity; ad-hoc signing is not Apple certification."
  exit 2
fi

# Xcode registers macOS build products with LaunchServices. Keep packaging
# separate from runnable development builds and remove its registrations before
# discarding the products, including when signing or packaging fails.
mkdir -p "$PWD/build/package-work.noindex"
PACKAGE_WORK_DIR="$(mktemp -d "$PWD/build/package-work.noindex/run.XXXXXX")"
export FILEMINT_DERIVED_DATA_PATH="$PACKAGE_WORK_DIR/DerivedData"
APP_PATH="$FILEMINT_DERIVED_DATA_PATH/Build/Products/Release/FileMint.app"

cleanup_package_build() {
  local package_status=$?
  local cleanup_status=0
  local registrations extension_path
  trap - EXIT
  if [[ -d "$APP_PATH" ]]; then
    if registrations="$(/usr/bin/pluginkit -m -A -D -v -i io.github.daigua.filemint.findersync 2>&1)"; then
      for extension_path in \
        "$APP_PATH/Contents/PlugIns/FileMintFinderSync.appex" \
        "$FILEMINT_DERIVED_DATA_PATH/Build/Products/Release/FileMintFinderSync.appex"; do
        if [[ "$registrations" == *"$extension_path"* ]]; then
          /usr/bin/pluginkit -r "$extension_path" || cleanup_status=1
        fi
      done
    else
      printf 'Cannot inspect temporary extension registrations: %s\n' "$registrations" >&2
      cleanup_status=1
    fi
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
      -u "$APP_PATH" || cleanup_status=1
  fi
  if [[ "$PACKAGE_WORK_DIR" == "$PWD/build/package-work.noindex/run."* ]]; then
    rm -rf -- "$PACKAGE_WORK_DIR" || cleanup_status=1
  else
    echo "Refusing to clean an unexpected packaging directory." >&2
    cleanup_status=1
  fi
  if [[ "$package_status" -eq 0 && "$cleanup_status" -ne 0 ]]; then
    package_status="$cleanup_status"
  fi
  exit "$package_status"
}
trap cleanup_package_build EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

export MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
export CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
./scripts/build_release.sh
./scripts/sign_app.sh "$APP_PATH"
./scripts/verify_bundle.sh "$APP_PATH"
if [[ "$IDENTITY" != "-" ]]; then
  bash ./scripts/verify_developer_id_signature.sh "$APP_PATH/Contents/PlugIns/FileMintFinderSync.appex"
  bash ./scripts/verify_developer_id_signature.sh "$APP_PATH"
fi
DMG_PATH="$DMG_PATH" ./scripts/make_dmg.sh "$APP_PATH"
if [[ "$IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"
  bash ./scripts/verify_developer_id_signature.sh "$DMG_PATH"
fi
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
