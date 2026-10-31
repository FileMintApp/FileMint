#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
python3 scripts/native_qa.py check-stopped file-info
swift build --package-path CorePackage
FILE_INFO_CORE="$(swift build --package-path CorePackage --show-bin-path)"
mkdir -p build/file-info-harness.noindex
FILE_INFO_RUN="$(mktemp -d "$PWD/build/file-info-harness.noindex/run.XXXXXX")"
FILE_INFO_APP="$FILE_INFO_RUN/FileInfoSmoke.app"
mkdir -p "$FILE_INFO_APP/Contents/MacOS" "$FILE_INFO_APP/Contents/Resources"
cp Resources/SFSymbolNames.txt Resources/SFSymbolRestrictedNames.txt "$FILE_INFO_APP/Contents/Resources/"
python3 - "$FILE_INFO_APP" "$FILE_INFO_RUN" <<'PY'
import pathlib, plistlib, sys
app, root = map(pathlib.Path, sys.argv[1:])
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps(dict(
    CFBundleIdentifier='io.github.daigua.filemint.file-info-smoke', CFBundleName='FileMint File Info QA',
    CFBundleExecutable='FileInfoSmoke', CFBundlePackageType='APPL', CFBundleVersion='1',
    NSPrincipalClass='NSApplication', LSUIElement=True, FixturePath=str(root))))
(root / 'entitlements.plist').write_bytes(plistlib.dumps({
    'com.apple.security.app-sandbox': True,
    'com.apple.security.files.user-selected.read-only': True,
    'com.apple.security.files.bookmarks.app-scope': True}))
PY
if [[ -f "$FILE_INFO_CORE/libFileMintCore.a" ]]; then
  FILE_INFO_LINK=(-I "$FILE_INFO_CORE" "$FILE_INFO_CORE/libFileMintCore.a" "$FILE_INFO_CORE/libFileMintImages.a")
else
  FILE_INFO_LINK=(-I "$FILE_INFO_CORE/Modules" "$FILE_INFO_CORE"/FileMintCore.build/*.o "$FILE_INFO_CORE"/FileMintImages.build/*.o)
fi
source scripts/image_compression_link.sh
FILE_INFO_LINK+=("${FILEMINT_COMPRESSION_LINK[@]}")
filemint_embed_compression "$FILE_INFO_APP"
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.3 \
  App/FileMint/DesignSystem.swift App/FileMint/ResourceToolsController.swift App/FileMint/ResourceToolsView.swift \
  App/FileMint/MenuIconControl.swift App/FileMint/SystemSymbolCatalog.swift scripts/native_qa_preferences.swift \
  App/FileMint/PlainTextEditor.swift SharedUI/CustomFileSavePanelController.swift SharedUI/FolderAccess.swift SharedUI/ExternalDraftPresentation.swift \
  SharedUI/FileToolAppearance.swift App/FileMint/FavoriteLocationsModel.swift \
  App/FileMint/FavoriteQuickPanelController.swift App/FileMint/FavoriteFeedbackController.swift \
  App/FileMint/ClipboardTextReader.swift App/FileMint/OpenWithApplicationAccess.swift App/FileMint/OpenWithFolderAccess.swift \
  App/FileMint/TerminalDirectoryLauncher.swift App/FileMint/BatchRenameController.swift \
  App/FileMint/BatchRenameView.swift App/FileMint/BatchRenameText.swift App/FileMint/BatchRenameAccess.swift \
  App/FileMint/BatchRenameOperations.swift App/FileMint/FileOperationCoordinator.swift \
  App/FileMint/FileInfoController.swift App/FileMint/FileInfoView.swift \
  App/FileMint/FileContentCopyController.swift App/FileMint/FileContentClipboard.swift \
  scripts/file_info_smoke.swift scripts/file_content_copy_checks.swift "${FILE_INFO_LINK[@]}" -o "$FILE_INFO_APP/Contents/MacOS/FileInfoSmoke"
codesign --force --sign - --timestamp=none --options runtime \
  --entitlements "$FILE_INFO_RUN/entitlements.plist" "$FILE_INFO_APP"
python3 scripts/native_qa.py publish file-info "$FILE_INFO_APP" "$FILE_INFO_RUN"
