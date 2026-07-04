#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/bootstrap_project.sh

DERIVED_DATA="$PWD/build/DerivedData"

XCODEBUILD_ARGS=(
  -project FileMint.xcodeproj \
  -scheme FileMint \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}" \
  CODE_SIGNING_REQUIRED="${CODE_SIGNING_REQUIRED:-NO}" \
  MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}" \
  CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-1}"
)

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  XCODEBUILD_ARGS+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
fi

XCODEBUILD_ARGS+=(build)

xcodebuild "${XCODEBUILD_ARGS[@]}"

echo "Built app:"
echo "$DERIVED_DATA/Build/Products/Release/FileMint.app"
