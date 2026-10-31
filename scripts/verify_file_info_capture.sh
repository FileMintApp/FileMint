#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build --package-path CorePackage --target FileMintCore
FILE_INFO_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
FILE_INFO_WORK="$(mktemp -d /private/tmp/filemint-info-capture.XXXXXX)"
trap 'rm -rf "$FILE_INFO_WORK"' EXIT
if [[ -f "$FILE_INFO_BUILD/libFileMintCore.a" ]]; then
  FILE_INFO_LINK=(-I "$FILE_INFO_BUILD" "$FILE_INFO_BUILD/libFileMintCore.a")
else
  FILE_INFO_LINK=(-I "$FILE_INFO_BUILD/Modules" "$FILE_INFO_BUILD"/FileMintCore.build/*.o)
fi
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.3 \
  scripts/file_info_capture_smoke.swift "${FILE_INFO_LINK[@]}" -o "$FILE_INFO_WORK/smoke"
python3 - "$FILE_INFO_WORK" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
items = root / 'items'
(items / 'folder').mkdir(parents=True)
(items / 'file.txt').write_bytes(b'abc')
(items / 'folder' / 'keep').write_bytes(b'preserve')
(items / 'link').symlink_to('file.txt')
(root / 'capture.sb').write_text('(version 1)\n(allow default)\n'
    '(deny file-read-data file-write* (subpath ' + json.dumps(str(items)) + '))\n')
PY
sandbox-exec -f "$FILE_INFO_WORK/capture.sb" "$FILE_INFO_WORK/smoke" "$FILE_INFO_WORK/items"
python3 - "$FILE_INFO_WORK" <<'PY'
import pathlib, sys
items = pathlib.Path(sys.argv[1]) / 'items'
assert (items / 'file.txt').read_bytes() == b'abc'
assert (items / 'folder' / 'keep').read_bytes() == b'preserve'
assert (items / 'link').readlink() == pathlib.Path('file.txt')
assert set(p.name for p in items.iterdir()) == {'file.txt', 'folder', 'link'}
assert set(p.name for p in (items / 'folder').iterdir()) == {'keep'}
print('PASS file information metadata fixture preserved')
PY
