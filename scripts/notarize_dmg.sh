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

submission_record="$DMG_PATH.notary.json"
if [[ -f "$submission_record" ]]; then
  submission_id="$(jq -r '.id // empty' "$submission_record")"
  submitted_sha256="$(jq -r '.dmgSHA256 // empty' "$submission_record")"
  current_sha256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
  [[ "$submission_id" =~ ^[0-9a-fA-F-]{36}$ && "$submitted_sha256" == "$current_sha256" ]] || {
    echo 'The saved notarization submission does not match this signed DMG' >&2
    exit 1
  }
  echo "Resuming Apple notarization submission: $submission_id"
else
  submission="$(xcrun notarytool submit "$DMG_PATH" "${credentials[@]}" --output-format json)"
  submission_id="$(printf '%s' "$submission" | jq -r '.id // empty')"
  [[ "$submission_id" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo 'Apple did not return a notarization submission ID' >&2; exit 1; }
  submitted_sha256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
  jq -n --arg id "$submission_id" --arg sha "$submitted_sha256" \
    '{id: $id, dmgSHA256: $sha}' > "$submission_record"
  echo "Submitted to Apple notarization: $submission_id"
fi

if ! submission="$(xcrun notarytool wait "$submission_id" "${credentials[@]}" --timeout 30m --output-format json)"; then
  printf 'Apple notarization wait stopped for %s. Retain %s and resume this same submission.\n' \
    "$submission_id" "$DMG_PATH" >&2
  exit 1
fi
submission_status="$(printf '%s' "$submission" | jq -r '.status // empty')"
if [[ "$submission_status" != 'Accepted' ]]; then
  printf 'Notarization %s status: %s\n' "$submission_id" "${submission_status:-unknown}" >&2
  printf '%s\n' "$submission" >&2
  exit 1
fi
printf 'Notarization accepted: %s\n' "$submission_id"

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "Notarized DMG:"
echo "$DMG_PATH"
