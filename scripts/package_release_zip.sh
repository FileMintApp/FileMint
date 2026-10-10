#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
dmg_path="${1:?Provide the signed release DMG}"
zip_path="${dmg_path%.dmg}.zip"
[[ "$dmg_path" == *.dmg && -f "$dmg_path" ]] || { echo 'Missing release DMG' >&2; exit 2; }
source_hash="$(shasum -a 256 "$dmg_path" | awk '{print $1}')"
record="$zip_path.source.json"
if [[ -e "$zip_path" ]]; then
  zip_hash="$(shasum -a 256 "$zip_path" | awk '{print $1}')"
  [[ -f "$record" && ! -L "$record" ]] &&
    jq -e --arg source "$source_hash" --arg zip "$zip_hash" \
      '.dmgSHA256 == $source and .zipSHA256 == $zip' "$record" > /dev/null || {
    echo 'Retained ZIP does not match its recorded DMG source or archive hash' >&2; exit 1;
  }
  python3 scripts/verify_release_zip.py "$zip_path"
else
  work="$(mktemp -d "$zip_path.stage.XXXXXX")"
  mounted=0
  cleanup_zip_stage() {
    if [[ "$mounted" == 1 ]]; then hdiutil detach -quiet "$work/mount" || true; fi
    rm -rf "$work"
  }
  trap cleanup_zip_stage EXIT
  mkdir "$work/mount"
  if [[ "${NOTARIZE:-0}" == 1 ]]; then xcrun stapler validate "$dmg_path"; fi
  hdiutil attach -quiet -readonly -nobrowse -mountpoint "$work/mount" "$dmg_path"
  mounted=1
  ditto "$work/mount/FileMint.app" "$work/FileMint.app"
  hdiutil detach -quiet "$work/mount"
  mounted=0
  if [[ "${NOTARIZE:-0}" == 1 ]]; then
    xcrun stapler staple "$work/FileMint.app"
    xcrun stapler validate "$work/FileMint.app"
  fi
  bash scripts/verify_bundle.sh "$work/FileMint.app"
  ZIP_PATH="$work/$(basename "$zip_path")" bash scripts/make_zip.sh "$work/FileMint.app"
  zip_hash="$(shasum -a 256 "$work/$(basename "$zip_path")" | awk '{print $1}')"
  jq -n --arg source "$source_hash" --arg zip "$zip_hash" \
    '{dmgSHA256: $source, zipSHA256: $zip}' > "$work/source.json"
  mv "$work/source.json" "$record"
  mv "$work/$(basename "$zip_path")" "$zip_path"
fi
checksum="$(cd "$(dirname "$zip_path")" && shasum -a 256 "$(basename "$zip_path")")"
if [[ -e "$zip_path.sha256" ]]; then
  [[ "$(cat "$zip_path.sha256")" == "$checksum" && "$(wc -l < "$zip_path.sha256")" -eq 1 ]] || {
    echo 'Retained ZIP checksum differs from its archive' >&2; exit 1;
  }
else
  printf '%s\n' "$checksum" > "$zip_path.sha256"
fi
echo "Packaged ZIP from the same signed DMG application: $zip_path"
