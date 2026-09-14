#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export APPLE_TEAM_ID=8S66M2ZLD5
export APPLE_CODESIGN_IDENTITY='Developer ID Application: Guangzhou Guangbei Vertex Technology co.,Ltd (8S66M2ZLD5)'

version=0.5.3
build_number=11
tag=v0.5.3
submission_id=11ed351a-020e-4107-bfae-72d0a8daec52
pending="$PWD/build/notary-pending-0.5.3"
source_manifest="$pending/source.json"
submitted_dmg="$pending/FileMint-0.5.3.dmg"
certificate=Config/Signing/DeveloperIDApplication-8S66M2ZLD5.cer
final_dmg="$PWD/build/FileMint-0.5.3.dmg"
final_checksum="$final_dmg.sha256"
final_manifest="$PWD/build/FileMint-0.5.3.release.json"

[[ "$(git branch --show-current)" == main ]] || { echo 'Publish from main' >&2; exit 2; }
[[ -z "$(git status --porcelain --untracked-files=all)" ]] || { echo 'Commit release changes first' >&2; exit 2; }
[[ "$(git remote get-url origin)" == 'https://github.com/FileMintApp/FileMint.git' ||
   "$(git remote get-url origin)" == 'git@github.com:FileMintApp/FileMint.git' ]] || {
  echo 'Unexpected GitHub remote' >&2; exit 2
}
tag_commit="$(git rev-parse "$tag^{commit}")"
[[ "$tag_commit" == "$(git rev-parse HEAD)" ]] || { echo 'Release tag must point at HEAD' >&2; exit 2; }
source_commit="$(jq -r '.commit' "$source_manifest")"
[[ "$source_commit" == c3d924a81eeb5e2efdb0b637eefe405947593dde ]] || {
  echo 'Unexpected original source commit' >&2; exit 2
}
jq -e '.version == "0.5.3" and .build == "11" and .tag == "v0.5.3"' "$source_manifest" > /dev/null
git merge-base --is-ancestor "$source_commit" "$tag_commit"
# The already-submitted binary came from the original commit. The tag may add
# release documentation and verification scripts, but no app or package code.
while IFS= read -r changed_path; do
  case "$changed_path" in
    README.md|README.en.md|specs/SPEC.md|docs/*|.github/workflows/release.yml|scripts/verify_release_artifact.sh|scripts/publish_053_early.sh) ;;
    *) printf 'App source changed since the submitted DMG: %s\n' "$changed_path" >&2; exit 1 ;;
  esac
done < <(git diff --name-only "$source_commit" "$tag_commit")

submitted_sha256="$(shasum -a 256 "$submitted_dmg" | awk '{print $1}')"
certificate_sha256="$(shasum -a 256 "$certificate" | awk '{print $1}')"
[[ "$submitted_sha256" == "$(jq -r '.submittedSHA256' "$source_manifest")" ]]
[[ "$certificate_sha256" == "$(jq -r '.certificateSHA256' "$source_manifest")" ]]
openssl x509 -inform DER -in "$certificate" -checkend 2592000 -noout

# Check Apple, but never turn In Progress into an asserted acceptance.
xcrun notarytool info "$submission_id" --keychain-profile FileMint --output-format json \
  > "$pending/notary-status-at-publication.json"
[[ "$(jq -r '.status' "$pending/notary-status-at-publication.json")" == 'In Progress' ]] || {
  echo 'Apple status changed; re-evaluate whether a notarized release is now possible' >&2
  exit 1
}

if [[ -e "$final_dmg" || -e "$final_checksum" || -e "$final_manifest" ]]; then
  [[ -f "$final_dmg" && -f "$final_checksum" && -f "$final_manifest" ]] || {
    echo 'Incomplete final release files exist; inspect before retrying' >&2
    exit 1
  }
else
  cp "$submitted_dmg" "$final_dmg"
  (cd build && shasum -a 256 FileMint-0.5.3.dmg) > "$final_checksum"
  jq -n --arg version "$version" --arg build "$build_number" --arg tag "$tag" \
    --arg tagCommit "$tag_commit" --arg sourceCommit "$source_commit" \
    --arg sha256 "$submitted_sha256" --arg certificate "$certificate_sha256" \
    --arg submissionId "$submission_id" \
    '{version:$version,build:$build,tag:$tag,tagCommit:$tagCommit,sourceCommit:$sourceCommit,dmgSHA256:$sha256,certificateSHA256:$certificate,notarizationAtPublication:"In Progress",submissionId:$submissionId}' \
    > "$final_manifest"
fi

[[ "$(shasum -a 256 "$final_dmg" | awk '{print $1}')" == "$submitted_sha256" ]]
[[ "$(jq -r '.tagCommit' "$final_manifest")" == "$tag_commit" ]]
[[ "$(jq -r '.sourceCommit' "$final_manifest")" == "$source_commit" ]]
[[ "$(jq -r '.dmgSHA256' "$final_manifest")" == "$submitted_sha256" ]]
[[ "$(jq -r '.certificateSHA256' "$final_manifest")" == "$certificate_sha256" ]]
[[ "$(jq -r '.submissionId' "$final_manifest")" == "$submission_id" ]]
FILEMINT_ALLOW_PENDING_053=1 bash scripts/verify_release_artifact.sh "$final_dmg" "$version" "$build_number"

remote_ref="$(git ls-remote --tags origin "refs/tags/$tag" | awk -v ref="refs/tags/$tag" '$2 == ref {print $1}')"
local_ref="$(git rev-parse "refs/tags/$tag")"
[[ -z "$remote_ref" || "$remote_ref" == "$local_ref" ]] || {
  echo 'Remote release tag differs from the verified local tag' >&2; exit 1
}
if gh release view "$tag" --repo FileMintApp/FileMint > /dev/null 2>&1; then
  echo 'A release already exists; refusing to replace or relabel its assets' >&2
  exit 1
fi

git push origin main
if [[ -z "$remote_ref" ]]; then git push origin "refs/tags/$tag"; fi
gh release create "$tag" "$final_dmg" "$final_checksum" \
  --repo FileMintApp/FileMint --verify-tag --latest \
  --title 'FileMint 0.5.3 (Apple notarization pending)' \
  --notes-file docs/RELEASE_NOTES.md

download_directory="$(mktemp -d /private/tmp/filemint-053-download.XXXXXX)"
cleanup_download() {
  rm -f "$download_directory/FileMint-0.5.3.dmg" "$download_directory/FileMint-0.5.3.dmg.sha256"
  rmdir "$download_directory" 2>/dev/null || true
}
trap cleanup_download EXIT
gh release download "$tag" --repo FileMintApp/FileMint \
  --pattern 'FileMint-0.5.3.dmg' --pattern 'FileMint-0.5.3.dmg.sha256' \
  --dir "$download_directory"
cmp "$final_dmg" "$download_directory/FileMint-0.5.3.dmg"
cmp "$final_checksum" "$download_directory/FileMint-0.5.3.dmg.sha256"
[[ "$(gh api repos/FileMintApp/FileMint/releases/latest --jq '.tag_name')" == "$tag" ]]
gh release view "$tag" --repo FileMintApp/FileMint \
  --json tagName,isDraft,isPrerelease,publishedAt,url,assets
echo 'Published and byte-verified the explicitly early, signed 0.5.3 GitHub Release.'
