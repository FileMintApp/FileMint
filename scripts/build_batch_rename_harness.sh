#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
python3 scripts/native_qa.py check-stopped batch-rename
swift build --package-path CorePackage
BATCH_RENAME_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
mkdir -p build/batch-rename-harness.noindex
BATCH_RENAME_FIXTURE="$(mktemp -d "$PWD/build/batch-rename-harness.noindex/run.XXXXXX")"
BATCH_RENAME_APP="$BATCH_RENAME_FIXTURE/BatchRenameSmoke.app"
mkdir -p "$BATCH_RENAME_APP/Contents/MacOS" "$BATCH_RENAME_APP/Contents/Resources"
cp Resources/SFSymbolNames.txt Resources/SFSymbolRestrictedNames.txt \
  Resources/SFSymbolCatalog-LICENSE.txt "$BATCH_RENAME_APP/Contents/Resources/"
python3 - "$BATCH_RENAME_APP" "$BATCH_RENAME_FIXTURE" <<'PY'
import pathlib, plistlib, sys
app, fixture = map(pathlib.Path, sys.argv[1:])
info = dict(CFBundleIdentifier="io.github.daigua.filemint.batch-rename-smoke",
            CFBundleName="FileMint Batch Rename QA", CFBundleExecutable="BatchRenameSmoke",
            CFBundlePackageType="APPL", CFBundleVersion="1", NSPrincipalClass="NSApplication",
            LSUIElement=True, FixturePath=str(fixture))
(app / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
entitlements = {"com.apple.security.app-sandbox": True,
                "com.apple.security.files.user-selected.read-write": True,
                "com.apple.security.files.bookmarks.app-scope": True}
(fixture / "entitlements.plist").write_bytes(plistlib.dumps(entitlements))
PY
if [[ -f "$BATCH_RENAME_BUILD/libFileMintCore.a" ]]; then
  BATCH_RENAME_LINK=(-I "$BATCH_RENAME_BUILD" "$BATCH_RENAME_BUILD/libFileMintCore.a" "$BATCH_RENAME_BUILD/libFileMintImages.a")
else
  BATCH_RENAME_LINK=(-I "$BATCH_RENAME_BUILD/Modules" "$BATCH_RENAME_BUILD"/FileMintCore.build/*.o "$BATCH_RENAME_BUILD"/FileMintImages.build/*.o)
fi
source scripts/image_compression_link.sh
BATCH_RENAME_LINK+=("${FILEMINT_COMPRESSION_LINK[@]}")
filemint_embed_compression "$BATCH_RENAME_APP"
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.3 \
  App/FileMint/DesignSystem.swift App/FileMint/ResourceToolsController.swift App/FileMint/ResourceToolsView.swift \
  App/FileMint/MenuIconControl.swift App/FileMint/SystemSymbolCatalog.swift scripts/native_qa_preferences.swift \
  App/FileMint/PlainTextEditor.swift SharedUI/CustomFileSavePanelController.swift SharedUI/FolderAccess.swift SharedUI/ExternalDraftPresentation.swift \
  SharedUI/FileToolAppearance.swift App/FileMint/FavoriteLocationsModel.swift \
  App/FileMint/FavoriteQuickPanelController.swift App/FileMint/FavoriteFeedbackController.swift \
  App/FileMint/ClipboardTextReader.swift App/FileMint/OpenWithApplicationAccess.swift App/FileMint/OpenWithFolderAccess.swift \
  App/FileMint/TerminalDirectoryLauncher.swift App/FileMint/BatchRenameController.swift \
  App/FileMint/BatchRenameView.swift App/FileMint/BatchRenameText.swift \
  App/FileMint/BatchRenameAccess.swift App/FileMint/BatchRenameOperations.swift App/FileMint/FileOperationCoordinator.swift \
  App/FileMint/FileInfoController.swift App/FileMint/FileInfoView.swift \
  App/FileMint/FileContentCopyController.swift App/FileMint/FileContentClipboard.swift \
  scripts/batch_rename_smoke.swift "${BATCH_RENAME_LINK[@]}" \
  -o "$BATCH_RENAME_APP/Contents/MacOS/BatchRenameSmoke"
codesign --force --sign - --timestamp=none --options runtime \
  --entitlements "$BATCH_RENAME_FIXTURE/entitlements.plist" "$BATCH_RENAME_APP"
codesign --verify --strict "$BATCH_RENAME_APP"
python3 scripts/native_qa.py publish batch-rename "$BATCH_RENAME_APP" "$BATCH_RENAME_FIXTURE"
