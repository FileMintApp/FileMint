#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build --package-path CorePackage
OPEN_WITH_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
mkdir -p build/open-with-harness.noindex
OPEN_WITH_FIXTURE="$(mktemp -d "$PWD/build/open-with-harness.noindex/run.XXXXXX")"
OPEN_WITH_APP="$OPEN_WITH_FIXTURE/OpenWithSmoke.app"
OPEN_WITH_RECEIVER="$OPEN_WITH_APP/Contents/Resources/OpenWithReceiver.app"
mkdir -p "$OPEN_WITH_APP/Contents/MacOS" "$OPEN_WITH_RECEIVER/Contents/MacOS"
python3 - "$OPEN_WITH_APP" "$OPEN_WITH_RECEIVER" "$OPEN_WITH_FIXTURE" <<'PY'
import pathlib, plistlib, sys
app, receiver, root = map(pathlib.Path, sys.argv[1:])
for path, identifier, executable in [(app, 'io.github.daigua.filemint.open-with-smoke', 'OpenWithSmoke'),
                                      (receiver, 'io.github.daigua.filemint.open-with-receiver', 'OpenWithReceiver')]:
    info = dict(CFBundleIdentifier=identifier, CFBundleName=executable, CFBundleExecutable=executable,
                CFBundlePackageType='APPL', CFBundleVersion='1', LSUIElement=True)
    if path == receiver:
        info['CFBundleDocumentTypes'] = [dict(CFBundleTypeRole='Viewer', LSHandlerRank='None',
                                            LSItemContentTypes=['public.item', 'public.folder'])]
    (path / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
(root / 'entitlements.plist').write_bytes(plistlib.dumps({
    'com.apple.security.app-sandbox': True,
    'com.apple.security.files.user-selected.read-write': True,
    'com.apple.security.files.bookmarks.app-scope': True}))
PY
if [[ -f "$OPEN_WITH_BUILD/libFileMintCore.a" ]]; then
  OPEN_WITH_LINK=(-I "$OPEN_WITH_BUILD" "$OPEN_WITH_BUILD/libFileMintCore.a" "$OPEN_WITH_BUILD/libFileMintImages.a")
else
  OPEN_WITH_LINK=(-I "$OPEN_WITH_BUILD/Modules" "$OPEN_WITH_BUILD"/FileMintCore.build/*.o "$OPEN_WITH_BUILD"/FileMintImages.build/*.o)
fi
swiftc -swift-version 6 -parse-as-library -target "arm64-apple-macos13.0" -D OPEN_WITH_RECEIVER \
  scripts/open_with_smoke.swift "${OPEN_WITH_LINK[@]}" \
  -o "$OPEN_WITH_RECEIVER/Contents/MacOS/OpenWithReceiver"
codesign --force --sign - --timestamp=none "$OPEN_WITH_RECEIVER"
swiftc -swift-version 6 -parse-as-library -target "arm64-apple-macos13.0" \
  App/FileMint/DesignSystem.swift App/FileMint/ResourceToolsController.swift App/FileMint/ResourceToolsView.swift \
  App/FileMint/PlainTextEditor.swift SharedUI/CustomFileSavePanelController.swift SharedUI/FolderAccess.swift \
  App/FileMint/PreferencesModel.swift App/FileMint/LoginItemService.swift SharedUI/FileToolAppearance.swift \
  FinderSyncExtension/FileMintFinderSync/FinderIntegrationStatus.swift \
  App/FileMint/OpenWithApplicationAccess.swift App/FileMint/FileOperationCoordinator.swift \
  scripts/open_with_smoke.swift "${OPEN_WITH_LINK[@]}" \
  -o "$OPEN_WITH_APP/Contents/MacOS/OpenWithSmoke"
codesign --force --sign - --timestamp=none --entitlements "$OPEN_WITH_FIXTURE/entitlements.plist" "$OPEN_WITH_APP"
codesign --verify --strict "$OPEN_WITH_APP"
echo "$OPEN_WITH_APP"
