#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tools="$PWD/build/SourcePackages/artifacts/sparkle/Sparkle/bin"
if [[ ! -x "$tools/sign_update" || ! -x "$tools/generate_keys" ]]; then
  make project >&2
  xcodebuild -resolvePackageDependencies -project FileMint.xcodeproj -scheme FileMint \
    -clonedSourcePackagesDirPath "$PWD/build/SourcePackages" >&2
fi
[[ -x "$tools/sign_update" && -x "$tools/generate_keys" ]] || exit 2
printf '%s\n' "$tools"
