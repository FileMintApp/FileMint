#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
version="${APP_VERSION:?Set APP_VERSION for this release}"
build_number="${BUILD_NUMBER:?Set BUILD_NUMBER for this release}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid release version' >&2; exit 2; }
[[ "$build_number" =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid build number' >&2; exit 2; }

tag="v$version"
head_commit="$(git rev-parse HEAD)"
tag_commit="$(git rev-parse --verify "refs/tags/$tag^{commit}" 2>/dev/null || true)"
[[ "$tag_commit" == "$head_commit" ]] || { echo "Create $tag at the current commit before building" >&2; exit 2; }
[[ -z "$(git status --porcelain --untracked-files=all)" ]] || { echo 'Commit all release changes before building' >&2; exit 2; }
rg -Fq "$version" docs/RELEASE_NOTES.md || { echo 'Update release notes for this version first' >&2; exit 2; }
openssl x509 -inform DER -in Config/Signing/DeveloperIDApplication-8S66M2ZLD5.cer \
  -checkend 2592000 -noout || { echo 'Renew the Developer ID certificate before this release' >&2; exit 2; }

export APPLE_TEAM_ID=8S66M2ZLD5
export APPLE_CODESIGN_IDENTITY='Developer ID Application: Guangzhou Guangbei Vertex Technology co.,Ltd (8S66M2ZLD5)'
export NOTARIZE=1

# A local Keychain profile is the preferred way to keep Apple credentials off disk.
if [[ -z "${APPLE_NOTARY_KEYCHAIN_PROFILE:-}" &&
      -z "${APPLE_NOTARY_KEY_PATH:-}" && -z "${APPLE_ID:-}" ]]; then
  export APPLE_NOTARY_KEYCHAIN_PROFILE=FileMint
fi
if [[ -n "${APPLE_NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  xcrun notarytool history --keychain-profile "$APPLE_NOTARY_KEYCHAIN_PROFILE" --output-format json > /dev/null
fi

mkdir -p build/local-release-work.noindex
stage_directory="$(mktemp -d "$PWD/build/local-release-work.noindex/run.XXXXXX")"
cleanup_stage() {
  if [[ "$stage_directory" == "$PWD/build/local-release-work.noindex/run."* ]]; then
    rm -f "$stage_directory/FileMint-$version.dmg" "$stage_directory/FileMint-$version.dmg.sha256" "$stage_directory/appcast.xml"
    rmdir "$stage_directory" 2>/dev/null || true
  fi
}
trap cleanup_stage EXIT

final_dmg="$PWD/build/FileMint-$version.dmg"
final_checksum="$final_dmg.sha256"
final_manifest="$PWD/build/FileMint-$version.release.json"
final_feed="$PWD/build/FileMint-$version.appcast.xml"
[[ ! -e "$final_dmg" && ! -e "$final_checksum" && ! -e "$final_manifest" && ! -e "$final_feed" ]] || {
  echo 'Release output already exists; use a new version or handle it explicitly' >&2
  exit 2
}

make verify
bash scripts/sparkle_tools.sh > /dev/null
FILEMINT_OUTPUT_DIR="$stage_directory" bash scripts/package_release.sh
python3 scripts/update_appcast.py generate "$stage_directory/FileMint-$version.dmg" "$version" "$build_number" "$stage_directory/appcast.xml"
bash scripts/verify_release_artifact.sh "$stage_directory/FileMint-$version.dmg" "$version" "$build_number"

mv "$stage_directory/appcast.xml" "$final_feed"
mv "$stage_directory/FileMint-$version.dmg" "$final_dmg"
mv "$stage_directory/FileMint-$version.dmg.sha256" "$final_checksum"
dmg_sha256="$(shasum -a 256 "$final_dmg" | awk '{print $1}')"
feed_sha256="$(shasum -a 256 "$final_feed" | awk '{print $1}')"
certificate_sha256="$(shasum -a 256 Config/Signing/DeveloperIDApplication-8S66M2ZLD5.cer | awk '{print $1}')"
jq -n --arg version "$version" --arg build "$build_number" --arg tag "$tag" \
  --arg commit "$head_commit" --arg sha256 "$dmg_sha256" --arg certificate "$certificate_sha256" --arg feed "$feed_sha256" \
  '{version: $version, build: $build, tag: $tag, commit: $commit, dmgSHA256: $sha256, certificateSHA256: $certificate, appcastSHA256: $feed}' \
  > "$final_manifest"
echo "Local signed and notarized release is ready: $final_dmg"
echo "Review it, then run: APP_VERSION=$version make publish-local"
