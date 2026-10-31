#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build --package-path CorePackage
CORE_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
work="$(mktemp -d /private/tmp/filemint-favorite-model.XXXXXX)"
trap 'rm -f "$work/smoke"; rmdir "$work"' EXIT
if [[ -f "$CORE_BUILD/libFileMintCore.a" ]]; then
  CORE_LINK=(-I "$CORE_BUILD" "$CORE_BUILD/libFileMintCore.a")
else
  CORE_LINK=(-I "$CORE_BUILD/Modules" "$CORE_BUILD"/FileMintCore.build/*.o)
fi
swiftc -swift-version 6 -parse-as-library \
  App/FileMint/FavoriteLocationsModel.swift SharedUI/ExternalDraftPresentation.swift scripts/favorite_model_smoke.swift \
  "${CORE_LINK[@]}" -o "$work/smoke"
"$work/smoke"
