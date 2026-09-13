#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/bootstrap_project.sh

DERIVED_DATA="${FILEMINT_DERIVED_DATA_PATH:-$PWD/build/DerivedData}"

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  DEFAULT_CODE_SIGNING_ALLOWED=YES
  DEFAULT_CODE_SIGNING_REQUIRED=YES
else
  DEFAULT_CODE_SIGNING_ALLOWED=NO
  DEFAULT_CODE_SIGNING_REQUIRED=NO
fi

XCODEBUILD_ARGS=(
  -project FileMint.xcodeproj \
  -scheme FileMint \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-$DEFAULT_CODE_SIGNING_ALLOWED}" \
  CODE_SIGNING_REQUIRED="${CODE_SIGNING_REQUIRED:-$DEFAULT_CODE_SIGNING_REQUIRED}" \
  MARKETING_VERSION="${MARKETING_VERSION:-0.4.0}" \
  CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-4}"
)

if [[ -n "${DEVELOPMENT_TEAM:-}" && "${CODE_SIGNING_ALLOWED:-$DEFAULT_CODE_SIGNING_ALLOWED}" == "YES" ]]; then
  XCODEBUILD_ARGS+=(
    -allowProvisioningUpdates
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
  )
fi

XCODEBUILD_ARGS+=(build)

xcodebuild "${XCODEBUILD_ARGS[@]}"

echo "Built app:"
echo "$DERIVED_DATA/Build/Products/Release/FileMint.app"
