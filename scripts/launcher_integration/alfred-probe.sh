#!/bin/bash
# Alfred External Script, input as argv. Keep alfred_encode.js alongside this file.
# Synthetic input only. Does not install or modify an Alfred workflow.
set -eu
if [ "$#" -ne 1 ]; then
  printf '%s\n' 'Expected one synthetic argument from Alfred argv input.' >&2
  exit 2
fi
probe_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
url="$(/usr/bin/osascript -l JavaScript "$probe_dir/alfred_encode.js" "$1")"
printf 'QA_ALFRED_RAW_ARGV=%s\n' "$1"
printf 'QA_SYSTEM_ARGUMENT=%s\n' "$url"
if [ "${FILEMINT_QA_PROBE_PRINT_ONLY:-0}" = 1 ]; then
  printf '%s\n' 'No system dispatch: encoder check only, not an Alfred entry check.'
  exit 0
fi
/usr/bin/open -b io.github.daigua.filemint.launcher-integration-qa "$url"
printf '%s\n' 'System open returned. Check the QA receiver; this is not an acceptance result.'
