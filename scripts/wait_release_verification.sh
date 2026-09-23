#!/usr/bin/env bash
set -euo pipefail

tag="${1:?Provide the release tag}"
commit="${2:?Provide the release commit}"
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ && "$commit" =~ ^[0-9a-f]{40}$ ]] || {
  echo 'Invalid release tag or commit' >&2
  exit 2
}

run_id=''
for ((attempt=0; attempt<40; attempt++)); do
  runs="$(gh run list --repo FileMintApp/FileMint --workflow release.yml --event release \
    --commit "$commit" --json databaseId,headBranch,headSha --limit 30)"
  run_id="$(printf '%s' "$runs" | jq -r --arg tag "$tag" --arg commit "$commit" \
    '[.[] | select(.headBranch == $tag and .headSha == $commit)] | first | .databaseId // empty')"
  if [[ -n "$run_id" ]]; then break; fi
  sleep 15
done
[[ -n "$run_id" ]] || { echo "No published-release verification run found for $tag" >&2; exit 1; }
gh run watch "$run_id" --repo FileMintApp/FileMint --exit-status
echo "Published-release verification passed: $run_id"
