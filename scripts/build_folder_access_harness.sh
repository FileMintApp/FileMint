#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
python3 scripts/native_qa.py check-stopped folder-access
swift build --package-path CorePackage --product filemint-harness
core="$(swift build --package-path CorePackage --show-bin-path)"
mkdir -p build/folder-access-harness.noindex
run="$(mktemp -d "$PWD/build/folder-access-harness.noindex/run.XXXXXXXX")"
app="$run/FileMintFolderAccessQA.app"
mkdir -p "$app/Contents/MacOS"
python3 - "$app" "$run" <<'PY'
import pathlib, plistlib, sys
app, run = map(pathlib.Path, sys.argv[1:])
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps(dict(
    CFBundleIdentifier='io.github.daigua.filemint.folder-access-qa',
    CFBundleName='FileMint Folder Access QA', CFBundleDisplayName='FileMint Folder Access QA',
    CFBundleExecutable='FileMintFolderAccessQA', CFBundlePackageType='APPL',
    CFBundleVersion='1', CFBundleShortVersionString='1.0', NSPrincipalClass='NSApplication')))
(run / 'entitlements.plist').write_bytes(plistlib.dumps({
    'com.apple.security.app-sandbox': True,
    'com.apple.security.files.user-selected.read-write': True,
    'com.apple.security.files.bookmarks.app-scope': True,
    'com.apple.security.temporary-exception.files.home-relative-path.read-write': [
        '/Library/Application Support/FileMintFolderAccessQA/'],
}))
PY
if [[ -f "$core/libFileMintCore.a" ]]; then
  link=(-I "$core" "$core/libFileMintCore.a")
else
  link=(-I "$core/Modules" "$core"/FileMintCore.build/*.o)
fi
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.0 \
  scripts/folder_access_smoke.swift SharedUI/FolderAccess.swift SharedUI/ExternalDraftPresentation.swift \
  "${link[@]}" -o "$app/Contents/MacOS/FileMintFolderAccessQA"
codesign --force --sign - --timestamp=none --options runtime --entitlements "$run/entitlements.plist" "$app"
python3 scripts/native_qa.py publish folder-access "$app" "$run"
printf 'Fixture run: %s\n' "${run##*/}"
