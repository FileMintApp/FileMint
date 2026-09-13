#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# This is deliberately separate from offline make verify: it downloads a real release.
swift build --package-path CorePackage
CORE_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
SMOKE_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/filemint-update-smoke.XXXXXX")"
trap 'rm -rf "$SMOKE_DIRECTORY"' EXIT
swiftc -swift-version 6 -parse-as-library -I "$CORE_BUILD/Modules" \
  App/FileMint/UpdateClient.swift scripts/update_smoke.swift \
  "$CORE_BUILD"/FileMintCore.build/*.o -o "$SMOKE_DIRECTORY/verify-updates"
"$SMOKE_DIRECTORY/verify-updates"
