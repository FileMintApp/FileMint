#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP_PATH="${1:-$PWD/build/DerivedData/Build/Products/Release/FileMint.app}"
ZIP_PATH="${ZIP_PATH:-$PWD/build/FileMint.zip}"
[[ -d "$APP_PATH" && "$(basename "$APP_PATH")" == FileMint.app ]] || { echo 'Provide FileMint.app' >&2; exit 2; }
[[ ! -e "$ZIP_PATH" ]] || { echo 'ZIP output already exists' >&2; exit 2; }
mkdir -p "$(dirname "$ZIP_PATH")"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
python3 scripts/verify_release_zip.py "$ZIP_PATH"
echo "$ZIP_PATH"
