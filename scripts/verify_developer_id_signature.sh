#!/usr/bin/env bash
set -euo pipefail

target="${1:?Provide a signed app, extension or DMG}"
expected_identity="${APPLE_CODESIGN_IDENTITY:?APPLE_CODESIGN_IDENTITY is required}"
expected_team="${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"

codesign --verify --strict "$target"
metadata="$(codesign --display --verbose=4 "$target" 2>&1)"
if [[ "$metadata" != *"Authority=$expected_identity"* ||
      "$metadata" != *"TeamIdentifier=$expected_team"* ||
      "$metadata" != *"Timestamp="* ]]; then
  printf 'Unexpected Developer ID signature or missing secure timestamp: %s\n' "$target" >&2
  printf '%s\n' "$metadata" >&2
  exit 1
fi
if [[ "$target" == *.app || "$target" == *.appex ]] &&
   [[ "$metadata" != *'flags=0x10000(runtime)'* ]]; then
  printf 'Hardened runtime is missing: %s\n' "$target" >&2
  exit 1
fi
printf 'Verified Developer ID signature: %s\n' "$target"
