#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
dmg_path="${1:?Provide the FileMint DMG or ZIP}"
version="${2:?Provide its version}"
build_number="${3:-}"
archive_format="${dmg_path##*.}"
case "$archive_format" in
  dmg) feed_name=appcast.xml ;;
  zip) feed_name=appcast-zip.xml ;;
  *) echo 'Unsupported release archive format' >&2; exit 2 ;;
esac
feed_path="${4:-$(dirname "$dmg_path")/$feed_name}"
fingerprint_path="${5:-}"
pending_053=0
if [[ "${FILEMINT_ALLOW_PENDING_053:-0}" == 1 ]]; then
  [[ "$version" == 0.5.3 && "$archive_format" == dmg ]] || { echo 'Pending notarization is allowed only for the 0.5.3 DMG' >&2; exit 2; }
  pending_053=1
fi
checksum_path="$dmg_path.sha256"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid version' >&2; exit 2; }
[[ -f "$dmg_path" && -f "$checksum_path" ]] || { echo 'Missing archive or checksum' >&2; exit 2; }

dmg_directory="$(cd "$(dirname "$dmg_path")" && pwd)"
dmg_path="$dmg_directory/$(basename "$dmg_path")"
checksum_path="$dmg_path.sha256"
dmg_name="FileMint-$version.$archive_format"
[[ "$(basename "$dmg_path")" == "$dmg_name" ]] || { echo 'Archive filename/version mismatch' >&2; exit 2; }

expected_checksum="$(cd "$dmg_directory" && shasum -a 256 "$dmg_name")"
[[ "$(sed -n '1p' "$checksum_path")" == "$expected_checksum" &&
   "$(wc -l < "$checksum_path")" -eq 1 ]] || { echo 'Archive checksum mismatch' >&2; exit 1; }
if [[ "$archive_format" == dmg ]]; then
  hdiutil verify "$dmg_path" > /dev/null
  bash scripts/verify_developer_id_signature.sh "$dmg_path"
  if [[ "$pending_053" == 0 ]]; then
    xcrun stapler validate "$dmg_path"
  elif xcrun stapler validate "$dmg_path" > /dev/null 2>&1; then
    echo 'The 0.5.3 DMG has a ticket; verify it as a notarized release instead.' >&2
    exit 1
  fi
else
  [[ "$build_number" =~ ^[1-9][0-9]*$ && -f "$feed_path" ]] || { echo 'ZIP verification requires its expected build and appcast' >&2; exit 2; }
  python3 scripts/update_appcast.py verify "$dmg_path" "$version" "$build_number" "$feed_path"
  python3 scripts/verify_release_zip.py "$dmg_path"
fi

mount_directory="$(mktemp -d /private/tmp/filemint-release-verify.XXXXXX)"
mounted=0
cleanup_mount() {
  if [[ "$mounted" == 1 ]]; then hdiutil detach -quiet "$mount_directory" || true; fi
  rm -rf "$mount_directory"
}
trap cleanup_mount EXIT
if [[ "$archive_format" == dmg ]]; then
  hdiutil attach -quiet -readonly -nobrowse -mountpoint "$mount_directory" "$dmg_path"
  mounted=1
else
  ditto -x -k "$dmg_path" "$mount_directory"
  xcrun stapler validate "$mount_directory/FileMint.app"
fi
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

if [[ "$pending_053" == 0 ]]; then
  [[ -f "$feed_path" ]] || { echo 'Missing release appcast.xml' >&2; exit 1; }
  configured_key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' Config/AppInfo.plist)"
  bundled_key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$app_path/Contents/Info.plist")"
  [[ -n "$configured_key" && "$bundled_key" == "$configured_key" ]] || { echo 'Update public key mismatch' >&2; exit 1; }
  sparkle="$app_path/Contents/Frameworks/Sparkle.framework/Versions/B"
  for component in XPCServices/Installer.xpc XPCServices/Downloader.xpc Autoupdate Updater.app; do
    bash scripts/verify_developer_id_signature.sh "$sparkle/$component"
  done
  bash scripts/verify_developer_id_signature.sh "$app_path/Contents/Frameworks/Sparkle.framework"
  if [[ "$archive_format" == dmg ]]; then
    python3 scripts/update_appcast.py verify "$dmg_path" "$version" "$app_build" "$feed_path"
  fi
fi

if [[ -n "$fingerprint_path" ]]; then
  fingerprint="$(codesign -d --verbose=4 "$app_path" 2>&1 | sed -n 's/^CDHash=//p')"
  [[ "$fingerprint" =~ ^[0-9a-f]{40}$ ]] || { echo 'Cannot read the verified app code hash' >&2; exit 1; }
  printf '%s\n' "$fingerprint" > "$fingerprint_path"
fi

if [[ "$mounted" == 1 ]]; then hdiutil detach -quiet "$mount_directory"; fi
mounted=0
rm -rf "$mount_directory"
trap - EXIT
if [[ "$pending_053" == 1 ]]; then
  printf 'Verified signed FileMint %s (%s), without Apple notarization ticket: %s\n' "$version" "$app_build" "$dmg_path"
else
  printf 'Verified notarized FileMint %s (%s): %s\n' "$version" "$app_build" "$dmg_path"
fi
