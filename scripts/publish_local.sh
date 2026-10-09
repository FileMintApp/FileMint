#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
read -r source_version source_build < <(python3 scripts/release_metadata.py show)
version="${APP_VERSION:-$source_version}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid release version' >&2; exit 2; }
python3 scripts/release_metadata.py check --version "$version"
tag="v$version"
manifest_path="$PWD/build/FileMint-$version.release.json"
dmg_path="$PWD/build/FileMint-$version.dmg"
checksum_path="$dmg_path.sha256"
feed_path="$PWD/build/FileMint-$version.appcast.xml"
[[ -f "$manifest_path" && -f "$dmg_path" && -f "$checksum_path" && -f "$feed_path" ]] || {
  echo 'First build this version locally with: make release-local' >&2
  exit 2
}
[[ -z "$(git status --porcelain --untracked-files=all)" ]] || { echo 'Commit release changes before publishing' >&2; exit 2; }
[[ "$(git branch --show-current)" == main ]] || { echo 'Publish from the main branch' >&2; exit 2; }
origin_url="$(git remote get-url origin)"
case "$origin_url" in
  'https://github.com/FileMintApp/FileMint.git'|'git@github.com:FileMintApp/FileMint.git') ;;
  *) echo "Unexpected origin remote: $origin_url" >&2; exit 2 ;;
esac
head_commit="$(git rev-parse HEAD)"
tag_commit="$(git rev-parse --verify "refs/tags/$tag^{commit}" 2>/dev/null || true)"
[[ "$tag_commit" == "$head_commit" ]] || { echo 'The release tag does not point at HEAD' >&2; exit 2; }

manifest_version="$(jq -r '.version' "$manifest_path")"
manifest_build="$(jq -r '.build' "$manifest_path")"
manifest_tag="$(jq -r '.tag' "$manifest_path")"
manifest_commit="$(jq -r '.commit' "$manifest_path")"
manifest_sha256="$(jq -r '.dmgSHA256' "$manifest_path")"
manifest_certificate="$(jq -r '.certificateSHA256' "$manifest_path")"
actual_sha256="$(shasum -a 256 "$dmg_path" | awk '{print $1}')"
actual_feed="$(shasum -a 256 "$feed_path" | awk '{print $1}')"
manifest_feed="$(jq -r '.appcastSHA256' "$manifest_path")"
actual_certificate="$(shasum -a 256 Config/Signing/DeveloperIDApplication-8S66M2ZLD5.cer | awk '{print $1}')"
[[ "$manifest_version" == "$version" && "$manifest_tag" == "$tag" &&
   "$manifest_build" == "$source_build" && "$manifest_commit" == "$head_commit" &&
   "$manifest_sha256" == "$actual_sha256" &&
   "$manifest_certificate" == "$actual_certificate" && "$manifest_feed" == "$actual_feed" ]] || {
  echo 'The built artifact no longer matches its source or certificate manifest' >&2
  exit 1
}

python3 scripts/update_appcast.py verify "$dmg_path" "$version" "$manifest_build" "$feed_path"

export APPLE_TEAM_ID=8S66M2ZLD5
export APPLE_CODESIGN_IDENTITY='Developer ID Application: Guangzhou Guangbei Vertex Technology co.,Ltd (8S66M2ZLD5)'
bash scripts/verify_release_artifact.sh "$dmg_path" "$version" "$manifest_build" "$feed_path"

python3 scripts/release_publication.py local "$manifest_path"
