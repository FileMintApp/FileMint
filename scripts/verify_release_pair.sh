#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
dmg="${1:?Provide the release DMG}"
version="${2:?Provide its version}"
build="${3:?Provide its build}"
dmg_feed="${4:-$(dirname "$dmg")/appcast.xml}"
zip_feed="${5:-$(dirname "$dmg")/appcast-zip.xml}"
work="$(mktemp -d /private/tmp/filemint-release-pair.XXXXXX)"
trap 'rm -rf "$work"' EXIT
bash scripts/verify_release_artifact.sh "$dmg" "$version" "$build" "$dmg_feed" "$work/dmg.cdhash"
bash scripts/verify_release_artifact.sh "${dmg%.dmg}.zip" "$version" "$build" "$zip_feed" "$work/zip.cdhash"
[[ -s "$work/dmg.cdhash" && -s "$work/zip.cdhash" ]] && cmp -s "$work/dmg.cdhash" "$work/zip.cdhash" || {
  echo 'DMG and ZIP contain different signed applications' >&2; exit 1;
}
echo 'Verified DMG and ZIP contain the same sealed application and preserve both update feeds.'
