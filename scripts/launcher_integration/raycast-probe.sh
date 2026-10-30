#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title FileMint P0 URL Probe
# @raycast.mode fullOutput
# @raycast.packageName FileMint Isolated QA
# @raycast.argument1 {"type":"text","placeholder":"FileMint-QA 中文 & # + % ? =","percentEncoded":true}
# Synthetic input only. Import manually into Raycast; never use private text.
set -eu
if [ "$#" -ne 1 ]; then
  printf '%s\n' 'Expected one percent-encoded synthetic argument.' >&2
  exit 2
fi
case "$1" in
  FileMint-QA*) ;;
  *) printf '%s\n' 'Use the documented FileMint-QA synthetic sample.' >&2; exit 2 ;;
esac
if [ "${#1}" -gt 4096 ]; then
  printf '%s\n' 'Synthetic argument is too large.' >&2
  exit 2
fi
url="filemint-launcher-qa://draft?v=1&probe=filemint-p0&id=ab0531ef-2faf-4bdf-86e1-da409f28412b&name=$1&text=QA%20synthetic%20body"
printf 'QA_RAYCAST_PERCENT_ENCODED_ARGV=%s\n' "$1"
printf 'QA_SYSTEM_ARGUMENT=%s\n' "$url"
if [ "${FILEMINT_QA_PROBE_PRINT_ONLY:-0}" = 1 ]; then
  printf '%s\n' 'No system dispatch: offline script check only.'
  exit 0
fi
/usr/bin/open -b io.github.daigua.filemint.launcher-integration-qa "$url"
printf '%s\n' 'System open returned. Check the QA receiver; this is not an acceptance result.'
