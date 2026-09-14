#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
version="${APP_VERSION:?Set APP_VERSION for this release}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid release version' >&2; exit 2; }
tag="v$version"
manifest_path="$PWD/build/FileMint-$version.release.json"
dmg_path="$PWD/build/FileMint-$version.dmg"
checksum_path="$dmg_path.sha256"
[[ -f "$manifest_path" && -f "$dmg_path" && -f "$checksum_path" ]] || {
  echo "First build this version locally with: APP_VERSION=$version BUILD_NUMBER=<number> make release-local" >&2
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
actual_certificate="$(shasum -a 256 Config/Signing/DeveloperIDApplication-8S66M2ZLD5.cer | awk '{print $1}')"
[[ "$manifest_version" == "$version" && "$manifest_tag" == "$tag" &&
   "$manifest_commit" == "$head_commit" && "$manifest_sha256" == "$actual_sha256" &&
   "$manifest_certificate" == "$actual_certificate" ]] || {
  echo 'The built artifact no longer matches its source or certificate manifest' >&2
  exit 1
}

export APPLE_TEAM_ID=8S66M2ZLD5
export APPLE_CODESIGN_IDENTITY='Developer ID Application: Guangzhou Guangbei Vertex Technology co.,Ltd (8S66M2ZLD5)'
bash scripts/verify_release_artifact.sh "$dmg_path" "$version" "$manifest_build"

remote_ref="$(git ls-remote --tags origin "refs/tags/$tag" | awk -v ref="refs/tags/$tag" '$2 == ref {print $1}')"
local_ref="$(git rev-parse "refs/tags/$tag")"
if [[ -n "$remote_ref" && "$remote_ref" != "$local_ref" ]]; then
  echo 'The remote version tag differs from the locally verified tag' >&2
  exit 1
fi
git push origin main
if [[ -z "$remote_ref" ]]; then git push origin "refs/tags/$tag"; fi

if gh release view "$tag" --repo FileMintApp/FileMint > /dev/null 2>&1; then
  echo 'GitHub Release already exists; verifying its assets without replacing them.'
else
  gh release create "$tag" "$dmg_path" "$checksum_path" \
    --repo FileMintApp/FileMint --verify-tag --latest \
    --title "FileMint $version" --notes-file docs/RELEASE_NOTES.md
fi

download_directory="$(mktemp -d /private/tmp/filemint-release-download.XXXXXX)"
cleanup_download() {
  rm -f "$download_directory/FileMint-$version.dmg" "$download_directory/FileMint-$version.dmg.sha256"
  rmdir "$download_directory" 2>/dev/null || true
}
trap cleanup_download EXIT
gh release download "$tag" --repo FileMintApp/FileMint \
  --pattern "FileMint-$version.dmg" --pattern "FileMint-$version.dmg.sha256" \
  --dir "$download_directory"
cmp "$dmg_path" "$download_directory/FileMint-$version.dmg"
cmp "$checksum_path" "$download_directory/FileMint-$version.dmg.sha256"
echo "Published and verified the downloaded GitHub Release: $tag"
