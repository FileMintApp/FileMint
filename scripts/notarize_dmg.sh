#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

DMG_PATH="${1:-$PWD/build/FileMint.dmg}"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found: $DMG_PATH"
  exit 2
fi

if [[ -n "${APPLE_NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  credentials=(--keychain-profile "$APPLE_NOTARY_KEYCHAIN_PROFILE")
elif [[ -n "${APPLE_NOTARY_KEY_PATH:-}" && -n "${APPLE_NOTARY_KEY_ID:-}" && -n "${APPLE_NOTARY_ISSUER_ID:-}" ]]; then
  credentials=(--key "$APPLE_NOTARY_KEY_PATH" --key-id "$APPLE_NOTARY_KEY_ID" --issuer "$APPLE_NOTARY_ISSUER_ID")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  credentials=(--apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID")
else
  echo 'Notarization needs a local notarytool Keychain profile, Team API key or app-specific password.' >&2
  exit 2
fi

submission="$(xcrun notarytool submit "$DMG_PATH" "${credentials[@]}" --wait --timeout 30m --output-format json)"
submission_status="$(printf '%s' "$submission" | jq -r '.status // empty')"
if [[ "$submission_status" != 'Accepted' ]]; then
  printf 'Notarization status: %s\n' "${submission_status:-unknown}" >&2
  printf '%s\n' "$submission" >&2
  exit 1
fi
printf 'Notarization accepted: %s\n' "$(printf '%s' "$submission" | jq -r '.id // "unknown ID"')"

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "Notarized DMG:"
echo "$DMG_PATH"
