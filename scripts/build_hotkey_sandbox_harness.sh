#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
python3 scripts/native_qa.py check-stopped hotkey-sandbox
swift build --package-path CorePackage >/dev/null
HOTKEY_CORE="$(swift build --package-path CorePackage --show-bin-path)"
if [[ -f "$HOTKEY_CORE/libFileMintCore.a" ]]; then
  HOTKEY_LINK=(-I "$HOTKEY_CORE" "$HOTKEY_CORE/libFileMintCore.a")
else
  HOTKEY_LINK=(-I "$HOTKEY_CORE/Modules" "$HOTKEY_CORE"/FileMintCore.build/*.o)
fi
mkdir -p build/hotkey-sandbox-harness.noindex
HOTKEY_RUN="$(mktemp -d "$PWD/build/hotkey-sandbox-harness.noindex/run.XXXXXX")"
HOTKEY_APP="$HOTKEY_RUN/FileMintHotKeyQA.app"
HOTKEY_PEER="$HOTKEY_APP/Contents/Resources/FileMintHotKeyPeer.app"
mkdir -p "$HOTKEY_APP/Contents/MacOS" "$HOTKEY_PEER/Contents/MacOS"
python3 - "$HOTKEY_APP" "$HOTKEY_PEER" "$HOTKEY_RUN" <<'PY'
import pathlib, plistlib, sys
host, peer, root = map(pathlib.Path, sys.argv[1:])
for app, name, identifier in [(host, 'FileMintHotKeyQA', 'io.github.daigua.filemint.hotkey-qa'),
                               (peer, 'FileMintHotKeyPeer', 'io.github.daigua.filemint.hotkey-peer')]:
    info = dict(CFBundleIdentifier=identifier, CFBundleName=name,
                CFBundleExecutable=name, CFBundlePackageType='APPL', CFBundleVersion='1',
                NSPrincipalClass='NSApplication', LSMinimumSystemVersion='13.0',
                FixtureRunID=root.name, LSUIElement=app == host)
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
(root / 'entitlements.plist').write_bytes(plistlib.dumps({'com.apple.security.app-sandbox': True}))
PY
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.3 \
  App/FileMint/GlobalShortcutService.swift scripts/hotkey_sandbox/HotKeyService.swift scripts/hotkey_sandbox/Peer.swift "${HOTKEY_LINK[@]}" \
  -o "$HOTKEY_PEER/Contents/MacOS/FileMintHotKeyPeer"
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.3 \
  App/FileMint/GlobalShortcutService.swift App/FileMint/GlobalShortcutController.swift \
  scripts/hotkey_sandbox/HotKeyService.swift scripts/hotkey_sandbox/Host.swift "${HOTKEY_LINK[@]}" \
  -o "$HOTKEY_APP/Contents/MacOS/FileMintHotKeyQA"
for HOTKEY_BUNDLE in "$HOTKEY_PEER" "$HOTKEY_APP"; do
  codesign --force --options runtime --sign - --timestamp=none \
    --entitlements "$HOTKEY_RUN/entitlements.plist" "$HOTKEY_BUNDLE"
done
python3 scripts/native_qa.py publish hotkey-sandbox "$HOTKEY_APP" "$HOTKEY_RUN"
