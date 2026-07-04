#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required to generate FileMint.xcodeproj."
  echo "Install it with: brew install xcodegen"
  exit 2
fi

xcodegen generate
