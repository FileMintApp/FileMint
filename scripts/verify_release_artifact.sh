#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
dmg_path="${1:?Provide the notarized FileMint DMG}"
version="${2:?Provide its version}"
build_number="${3:-}"
checksum_path="$dmg_path.sha256"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid version' >&2; exit 2; }
[[ -f "$dmg_path" && -f "$checksum_path" ]] || { echo 'Missing DMG or checksum' >&2; exit 2; }

dmg_directory="$(cd "$(dirname "$dmg_path")" && pwd)"
dmg_path="$dmg_directory/$(basename "$dmg_path")"
checksum_path="$dmg_path.sha256"
dmg_name="FileMint-$version.dmg"
[[ "$(basename "$dmg_path")" == "$dmg_name" ]] || { echo 'DMG filename/version mismatch' >&2; exit 2; }

expected_checksum="$(cd "$dmg_directory" && shasum -a 256 "$dmg_name")"
[[ "$(sed -n '1p' "$checksum_path")" == "$expected_checksum" &&
   "$(wc -l < "$checksum_path")" -eq 1 ]] || { echo 'DMG checksum mismatch' >&2; exit 1; }
hdiutil verify "$dmg_path" > /dev/null
bash scripts/verify_developer_id_signature.sh "$dmg_path"
xcrun stapler validate "$dmg_path"

mount_directory="$(mktemp -d /private/tmp/filemint-release-verify.XXXXXX)"
mounted=0
cleanup_mount() {
  if [[ "$mounted" == 1 ]]; then hdiutil detach -quiet "$mount_directory" || true; fi
  rmdir "$mount_directory" 2>/dev/null || true
}
trap cleanup_mount EXIT
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$mount_directory" "$dmg_path"
mounted=1
app_path="$mount_directory/FileMint.app"
extension_path="$app_path/Contents/PlugIns/FileMintFinderSync.appex"
bash scripts/verify_bundle.sh "$app_path"
bash scripts/verify_developer_id_signature.sh "$extension_path"
bash scripts/verify_developer_id_signature.sh "$app_path"

app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
app_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Contents/Info.plist")"
extension_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$extension_path/Contents/Info.plist")"
[[ "$app_version" == "$version" && "$app_build" == "$extension_build" ]] || {
  echo 'App or extension version mismatch' >&2
  exit 1
}
if [[ -n "$build_number" && "$app_build" != "$build_number" ]]; then
  echo 'Release build number mismatch' >&2
  exit 1
fi

hdiutil detach -quiet "$mount_directory"
mounted=0
rmdir "$mount_directory"
trap - EXIT
printf 'Verified notarized FileMint %s (%s): %s\n' "$version" "$app_build" "$dmg_path"
