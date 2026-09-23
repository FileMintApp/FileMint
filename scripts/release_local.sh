#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
read -r source_version source_build < <(python3 scripts/release_metadata.py show)
version="${APP_VERSION:-$source_version}"
build_number="${BUILD_NUMBER:-$source_build}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid release version' >&2; exit 2; }
[[ "$build_number" =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid build number' >&2; exit 2; }
python3 scripts/release_metadata.py check --version "$version" --build "$build_number"

tag="v$version"
[[ "$(git branch --show-current)" == main ]] || { echo 'Build public releases from the main branch' >&2; exit 2; }
head_commit="$(git rev-parse HEAD)"
tag_commit="$(git rev-parse --verify "refs/tags/$tag^{commit}" 2>/dev/null || true)"
[[ "$tag_commit" == "$head_commit" ]] || { echo "Create $tag at the current commit before building" >&2; exit 2; }
[[ -z "$(git status --porcelain --untracked-files=all)" ]] || { echo 'Commit all release changes before building' >&2; exit 2; }
latest_tag="$(gh release view --repo FileMintApp/FileMint --json tagName --jq .tagName)"
[[ "$latest_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Cannot validate the latest stable release' >&2; exit 2; }
latest_feed_directory="$(mktemp -d /private/tmp/filemint-latest-appcast.XXXXXX)"
trap 'rm -f "$latest_feed_directory/appcast.xml"; rmdir "$latest_feed_directory"' EXIT
gh release download "$latest_tag" --repo FileMintApp/FileMint --pattern appcast.xml --dir "$latest_feed_directory"
python3 scripts/release_metadata.py successor --version "$version" --build "$build_number" \
  --previous-version "${latest_tag#v}" --previous-feed "$latest_feed_directory/appcast.xml"
rm -f "$latest_feed_directory/appcast.xml"
rmdir "$latest_feed_directory"
trap - EXIT
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
if [[ -n "${FILEMINT_RESUME_STAGE:-}" ]]; then
  stage_directory="$(cd "$FILEMINT_RESUME_STAGE" && pwd -P)"
  [[ "$stage_directory" == "$PWD/build/local-release-work.noindex/run."* &&
     -f "$stage_directory/FileMint-$version.dmg.notary.json" ]] || {
    echo 'Resume only a retained FileMint notarization staging directory' >&2
    exit 2
  }
else
  stage_directory="$(mktemp -d "$PWD/build/local-release-work.noindex/run.XXXXXX")"
fi
cleanup_stage() {
  local status=$?
  trap - EXIT
  if [[ "$status" -ne 0 ]]; then
    printf 'Release preparation stopped; retained staging files at %s for diagnosis or notarization status checks.\n' "$stage_directory" >&2
    exit "$status"
  fi
  if [[ "$stage_directory" == "$PWD/build/local-release-work.noindex/run."* ]]; then
    rm -f "$stage_directory/FileMint-$version.dmg" "$stage_directory/FileMint-$version.dmg.sha256" \
      "$stage_directory/FileMint-$version.dmg.notary.json" "$stage_directory/appcast.xml"
    rmdir "$stage_directory" 2>/dev/null || true
  fi
  exit "$status"
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

if [[ -n "${FILEMINT_RESUME_STAGE:-}" ]]; then
  bash scripts/notarize_dmg.sh "$stage_directory/FileMint-$version.dmg"
  (cd "$stage_directory" && shasum -a 256 "FileMint-$version.dmg") > "$stage_directory/FileMint-$version.dmg.sha256"
else
  make verify
  bash scripts/sparkle_tools.sh > /dev/null
  FILEMINT_OUTPUT_DIR="$stage_directory" bash scripts/package_release.sh
fi
python3 scripts/update_appcast.py generate "$stage_directory/FileMint-$version.dmg" "$version" "$build_number" "$stage_directory/appcast.xml"
bash scripts/verify_release_artifact.sh "$stage_directory/FileMint-$version.dmg" "$version" "$build_number"

mv "$stage_directory/appcast.xml" "$final_feed"
mv "$stage_directory/FileMint-$version.dmg" "$final_dmg"
mv "$stage_directory/FileMint-$version.dmg.sha256" "$final_checksum"
dmg_sha256="$(shasum -a 256 "$final_dmg" | awk '{print $1}')"
feed_sha256="$(shasum -a 256 "$final_feed" | awk '{print $1}')"
certificate_sha256="$(shasum -a 256 Config/Signing/DeveloperIDApplication-8S66M2ZLD5.cer | awk '{print $1}')"
notary_submission_id="$(jq -r '.id' "$stage_directory/FileMint-$version.dmg.notary.json")"
jq -n --arg version "$version" --arg build "$build_number" --arg tag "$tag" \
  --arg commit "$head_commit" --arg sha256 "$dmg_sha256" --arg certificate "$certificate_sha256" --arg feed "$feed_sha256" \
  --arg notary "$notary_submission_id" \
  '{version: $version, build: $build, tag: $tag, commit: $commit, dmgSHA256: $sha256, certificateSHA256: $certificate, appcastSHA256: $feed, notarySubmissionID: $notary}' \
  > "$final_manifest"
echo "Local signed and notarized release is ready: $final_dmg"
echo 'After native candidate acceptance, run: make publish-local'
