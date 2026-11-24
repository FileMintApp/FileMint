#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP_PATH="${1:-$PWD/build/DerivedData/Build/Products/Release/FileMint.bundle}"
ZIP_PATH="${ZIP_PATH:-$PWD/build/FileMint.zip}"
[[ -d "$APP_PATH" ]] || { echo 'Provide a FileMint build or app bundle' >&2; exit 2; }
[[ ! -e "$ZIP_PATH" ]] || { echo 'ZIP output already exists' >&2; exit 2; }
case "$(basename "$APP_PATH")" in
  FileMint.app) ;;
  FileMint.bundle)
    work="$(mktemp -d "${TMPDIR:-/tmp}/filemint-zip.XXXXXX")"
    trap 'rm -rf "$work"' EXIT
    ditto "$APP_PATH" "$work/FileMint.app"
    APP_PATH="$work/FileMint.app"
    ;;
  *) echo 'Provide a FileMint build or app bundle' >&2; exit 2 ;;
esac
mkdir -p "$(dirname "$ZIP_PATH")"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
python3 scripts/verify_release_zip.py "$ZIP_PATH"
echo "$ZIP_PATH"
