#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build --package-path CorePackage --target FileMintCore
VISIBILITY_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
VISIBILITY_WORK="$(mktemp -d /private/tmp/filemint-visibility.XXXXXX)"
trap 'rm -rf "$VISIBILITY_WORK"' EXIT
if [[ -f "$VISIBILITY_BUILD/libFileMintCore.a" ]]; then
  VISIBILITY_LINK=(-I "$VISIBILITY_BUILD" "$VISIBILITY_BUILD/libFileMintCore.a")
else
  VISIBILITY_LINK=(-I "$VISIBILITY_BUILD/Modules" "$VISIBILITY_BUILD"/FileMintCore.build/*.o)
fi
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.0 \
  scripts/file_visibility_capture_smoke.swift "${VISIBILITY_LINK[@]}" -o "$VISIBILITY_WORK/smoke"
python3 - "$VISIBILITY_WORK" <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
items = root / 'items'
(items / 'folder').mkdir(parents=True)
for name in ['file.txt', 'folder/child.txt']:
    (items / name).write_bytes(b'untouched fixture')
expected = {name: {'inode': (items / name).stat().st_ino,
                   'sha256': hashlib.sha256((items / name).read_bytes()).hexdigest()}
            for name in ['file.txt', 'folder/child.txt']}
(root / 'expected.json').write_text(json.dumps(expected))
base = '(version 1)\n(allow default)\n'
target = ' (subpath ' + json.dumps(str(items)) + '))\n'
# macOS checks file-read-data even for O_EVTONLY. It is not an enforced
# byte-read prohibition; production uses metadata APIs only on these handles.
(root / 'capture.sb').write_text(base + '(deny file-read-data file-write*' + target)
(root / 'allow.sb').write_text(base + '(deny file-write-data' + target)
(root / 'deny.sb').write_text(base + '(deny file-write*' + target)
PY
for VISIBILITY_MODE in capture allow deny; do
  sandbox-exec -f "$VISIBILITY_WORK/$VISIBILITY_MODE.sb" "$VISIBILITY_WORK/smoke" \
    "$VISIBILITY_WORK/items" "$VISIBILITY_MODE"
done
python3 - "$VISIBILITY_WORK" <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
items = root / 'items'
for name, value in json.loads((root / 'expected.json').read_text()).items():
    assert (items / name).stat().st_ino == value['inode'], 'Fixture identity changed'
    assert hashlib.sha256((items / name).read_bytes()).hexdigest() == value['sha256'], 'Fixture content changed'
assert set(p.name for p in items.iterdir()) == {'file.txt', 'folder'}
assert set(p.name for p in (items / 'folder').iterdir()) == {'child.txt'}
assert all(p.stat().st_flags & 0x8000 == 0 for p in [items / 'file.txt', items / 'folder', items / 'folder/child.txt'])
print('PASS file visibility source identities, names, contents and descendant flags preserved')
PY
