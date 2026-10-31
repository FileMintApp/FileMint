#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build --package-path CorePackage
RENAME_CAPTURE_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
RENAME_CAPTURE_WORK="$(mktemp -d /private/tmp/filemint-rename-capture.XXXXXX)"
trap 'rm -rf "$RENAME_CAPTURE_WORK"' EXIT
if [[ -f "$RENAME_CAPTURE_BUILD/libFileMintCore.a" ]]; then
  RENAME_CAPTURE_LINK=(-I "$RENAME_CAPTURE_BUILD" "$RENAME_CAPTURE_BUILD/libFileMintCore.a")
else
  RENAME_CAPTURE_LINK=(-I "$RENAME_CAPTURE_BUILD/Modules" "$RENAME_CAPTURE_BUILD"/FileMintCore.build/*.o)
fi
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.3 \
  scripts/batch_rename_capture_smoke.swift "${RENAME_CAPTURE_LINK[@]}" -o "$RENAME_CAPTURE_WORK/smoke"
python3 - "$RENAME_CAPTURE_WORK" <<'PY'
import hashlib, json, os, pathlib, sys
root = pathlib.Path(sys.argv[1])
items = root / 'items'
(items / 'Photos').mkdir(parents=True)
for name, content in {'IMG_2.JPG': b'two', 'IMG_10.JPG': b'ten', 'Photos/keep': b'nested'}.items():
    (items / name).write_bytes(content)
(items / 'link.JPG').symlink_to('IMG_2.JPG')
os.link(items / 'IMG_2.JPG', items / 'hardlink.JPG')
expected = {name: {'inode': (items / name).stat().st_ino,
                   'sha256': hashlib.sha256((items / name).read_bytes()).hexdigest()}
            for name in ['IMG_2.JPG', 'IMG_10.JPG', 'Photos/keep', 'hardlink.JPG']}
(root / 'expected.json').write_text(json.dumps(expected))
(root / 'capture.sb').write_text('(version 1)\n(allow default)\n'
    '(deny file-read-data file-write* (subpath ' + json.dumps(str(items)) + '))\n')
PY
sandbox-exec -f "$RENAME_CAPTURE_WORK/capture.sb" "$RENAME_CAPTURE_WORK/smoke" \
  "$RENAME_CAPTURE_WORK/items" "$RENAME_CAPTURE_WORK/control"
python3 - "$RENAME_CAPTURE_WORK" <<'PY'
import hashlib, json, os, pathlib, sys
root = pathlib.Path(sys.argv[1])
items = root / 'items'
for name, value in json.loads((root / 'expected.json').read_text()).items():
    assert (items / name).stat().st_ino == value['inode'], 'Fixture identity changed'
    assert hashlib.sha256((items / name).read_bytes()).hexdigest() == value['sha256'], 'Fixture content changed'
assert os.readlink(items / 'link.JPG') == 'IMG_2.JPG'
assert set(p.name for p in items.iterdir()) == {'IMG_2.JPG', 'IMG_10.JPG', 'Photos', 'link.JPG', 'hardlink.JPG'}
print('PASS sandbox capture fixture identities, contents and complete namespace preserved')
PY
