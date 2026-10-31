#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build --package-path CorePackage --target FileMintCore
RENAME_ACCESS_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
RENAME_ACCESS_WORK="$(mktemp -d /private/tmp/filemint-rename-access.XXXXXX)"
trap 'rm -rf "$RENAME_ACCESS_WORK"' EXIT
if [[ -f "$RENAME_ACCESS_BUILD/libFileMintCore.a" ]]; then
  RENAME_ACCESS_LINK=(-I "$RENAME_ACCESS_BUILD" "$RENAME_ACCESS_BUILD/libFileMintCore.a")
else
  RENAME_ACCESS_LINK=(-I "$RENAME_ACCESS_BUILD/Modules" "$RENAME_ACCESS_BUILD"/FileMintCore.build/*.o)
fi
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.0 \
  scripts/batch_rename_access_smoke.swift "${RENAME_ACCESS_LINK[@]}" -o "$RENAME_ACCESS_WORK/smoke"
"$RENAME_ACCESS_WORK/smoke" setup "$RENAME_ACCESS_WORK"
python3 - "$RENAME_ACCESS_WORK" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
prefix = '(version 1)\n(allow default)\n(deny file-write-mode '
(root / 'final.sb').write_text(prefix + ' '.join(
    '(literal ' + json.dumps(str(root / 'final' / name)) + ')'
    for name in ['existing.json', 'new.json']) + ')\n')
(root / 'failure.sb').write_text(prefix + '(subpath ' + json.dumps(str(root / 'failure')) + '))\n')
PY
for RENAME_ACCESS_MODE in final failure; do
  sandbox-exec -f "$RENAME_ACCESS_WORK/$RENAME_ACCESS_MODE.sb" "$RENAME_ACCESS_WORK/smoke" \
    "$RENAME_ACCESS_MODE" "$RENAME_ACCESS_WORK"
done
