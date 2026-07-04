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
  for name in \
    APPLE_DEVELOPER_ID_CERTIFICATE_BASE64 \
    APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD \
    APPLE_BUILD_KEYCHAIN_PASSWORD \
    APPLE_CODESIGN_IDENTITY \
    APPLE_ID \
    APPLE_APP_SPECIFIC_PASSWORD \
    APPLE_TEAM_ID
  do
    if [[ -n "${!name:-}" ]]; then
      echo "OK release secret env: $name"
    else
      echo "MISSING release secret env: $name"
      FAILED=1
    fi
  done
fi

exit "$FAILED"
