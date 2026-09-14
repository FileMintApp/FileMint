#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

FAILED=0

check_required() {
  local label="$1"
  local command_name="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    echo "OK required: $label"
  else
    echo "MISSING required: $label"
    FAILED=1
  fi
}

check_recommended() {
  local label="$1"
  local command_name="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    echo "OK recommended: $label"
  else
    echo "MISSING recommended: $label"
  fi
}

check_required "swift" swift
check_required "xcodebuild" xcodebuild
check_required "xcodegen" xcodegen
check_recommended "GitHub CLI" gh

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "OK required: git repository"
else
  echo "MISSING required: git repository"
  FAILED=1
fi

SELECTED_DEVELOPER_PATH="$(xcode-select -p 2>/dev/null || true)"
EFFECTIVE_DEVELOPER_PATH="${DEVELOPER_DIR:-$SELECTED_DEVELOPER_PATH}"
if [[ "$EFFECTIVE_DEVELOPER_PATH" == "/Applications/Xcode.app/Contents/Developer" ]]; then
  echo "OK required: full Xcode available"
else
  echo "MISSING required: full Xcode available"
  echo "  Current xcode-select path: ${SELECTED_DEVELOPER_PATH:-unknown}"
  echo "  Current DEVELOPER_DIR: ${DEVELOPER_DIR:-unset}"
  echo "  Run: export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer"
  FAILED=1
fi

if [[ "${RELEASE_CHECK:-0}" == "1" ]]; then
  check_required 'jq' jq
  check_required 'codesign' codesign
  check_required 'hdiutil' hdiutil
  check_required 'GitHub CLI' gh
  certificate_path="$PWD/Config/Signing/DeveloperIDApplication-8S66M2ZLD5.cer"
  if [[ -f "$certificate_path" ]]; then
    identity_sha1="$(openssl x509 -inform DER -in "$certificate_path" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d : | tr '[:lower:]' '[:upper:]')"
    identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
    if [[ "$identities" == *"$identity_sha1"* ]]; then
      echo 'OK release Developer ID identity in local Keychain'
    else
      echo 'MISSING release Developer ID identity in local Keychain'
      FAILED=1
    fi
  else
    echo 'MISSING release Developer ID public certificate'
    FAILED=1
  fi
  if xcrun notarytool history --keychain-profile "${APPLE_NOTARY_KEYCHAIN_PROFILE:-FileMint}" --output-format json > /dev/null 2>&1; then
    echo 'OK release notarization Keychain profile'
  else
    echo 'MISSING or invalid release notarization Keychain profile'
    FAILED=1
  fi
fi

exit "$FAILED"
