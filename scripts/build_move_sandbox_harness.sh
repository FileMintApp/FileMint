#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
python3 scripts/native_qa.py check-stopped move-sandbox
swift build --package-path CorePackage
CORE_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
mkdir -p build/move-sandbox-harness.noindex
SMOKE_DIRECTORY="$(mktemp -d "$PWD/build/move-sandbox-harness.noindex/run.XXXXXX")"
APP_PATH="$SMOKE_DIRECTORY/FileMintMoveSandboxSmoke.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$SMOKE_DIRECTORY/fixtures/source/Demo.app/Contents" "$SMOKE_DIRECTORY/fixtures/target"
mkdir -p "$APP_PATH/Contents/Resources"
cp Resources/SFSymbolNames.txt Resources/SFSymbolRestrictedNames.txt \
  Resources/SFSymbolCatalog-LICENSE.txt "$APP_PATH/Contents/Resources/"
python3 - "$APP_PATH" "$SMOKE_DIRECTORY" <<'PY'
import pathlib, plistlib, sys
app, root = map(pathlib.Path, sys.argv[1:])
info = dict(CFBundleIdentifier="io.github.daigua.filemint.move-smoke", CFBundleName="FileMint Move Smoke",
            CFBundleExecutable="FileMintMoveSandboxSmoke", CFBundlePackageType="APPL", CFBundleVersion="1",
            NSPrincipalClass="NSApplication", FixturePath=str(root / "fixtures"))
(app / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
(root / "entitlements.plist").write_bytes(plistlib.dumps({"com.apple.security.app-sandbox": True,
    "com.apple.security.files.user-selected.read-write": True, "com.apple.security.files.bookmarks.app-scope": True}))
(root / "fixtures/source/图片.png").write_bytes(bytes([0, 255, 14, 0]))
(root / "fixtures/source/Demo.app/Contents/data").write_text("sandbox fixture")
PY
if [[ -f "$CORE_BUILD/libFileMintCore.a" ]]; then
  CORE_LINK=(-I "$CORE_BUILD" "$CORE_BUILD/libFileMintCore.a" "$CORE_BUILD/libFileMintImages.a")
else
  CORE_LINK=(-I "$CORE_BUILD/Modules" "$CORE_BUILD"/FileMintCore.build/*.o "$CORE_BUILD"/FileMintImages.build/*.o)
fi
source scripts/image_compression_link.sh
CORE_LINK+=("${FILEMINT_COMPRESSION_LINK[@]}")
filemint_embed_compression "$APP_PATH"
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.0 \
  App/FileMint/DesignSystem.swift App/FileMint/ResourceToolsController.swift App/FileMint/ResourceToolsView.swift \
  App/FileMint/MenuIconControl.swift App/FileMint/SystemSymbolCatalog.swift scripts/native_qa_preferences.swift \
  App/FileMint/PlainTextEditor.swift SharedUI/CustomFileSavePanelController.swift SharedUI/FolderAccess.swift \
  SharedUI/FileToolAppearance.swift \
  App/FileMint/FavoriteLocationsModel.swift App/FileMint/FavoriteQuickPanelController.swift \
  App/FileMint/FavoriteFeedbackController.swift \
  App/FileMint/FileOperationCoordinator.swift App/FileMint/OpenWithApplicationAccess.swift App/FileMint/OpenWithFolderAccess.swift \
  App/FileMint/TerminalDirectoryLauncher.swift scripts/move_sandbox_smoke.swift \
  "${CORE_LINK[@]}" -o "$APP_PATH/Contents/MacOS/FileMintMoveSandboxSmoke"
codesign --force --options runtime --sign - --timestamp=none \
  --entitlements "$SMOKE_DIRECTORY/entitlements.plist" "$APP_PATH"
codesign --verify --strict "$APP_PATH"
echo "Built isolated sandbox harness (interactive authorization checks required):"
python3 scripts/native_qa.py publish move-sandbox "$APP_PATH" "$SMOKE_DIRECTORY"
