#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build --package-path CorePackage
RESOURCE_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
mkdir -p build/resource-tools-harness.noindex
RESOURCE_FIXTURE="$(mktemp -d "$PWD/build/resource-tools-harness.noindex/run.XXXXXX")"
RESOURCE_APP="$RESOURCE_FIXTURE/FileMintResourceQA.app"
mkdir -p "$RESOURCE_APP/Contents/MacOS" "$RESOURCE_APP/Contents/Resources"
cp Resources/SFSymbolNames.txt Resources/SFSymbolRestrictedNames.txt \
  Resources/SFSymbolCatalog-LICENSE.txt "$RESOURCE_APP/Contents/Resources/"
plutil -create xml1 "$RESOURCE_APP/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string io.github.daigua.filemint.resource-qa "$RESOURCE_APP/Contents/Info.plist"
plutil -insert CFBundleName -string 'FileMint Resource QA' "$RESOURCE_APP/Contents/Info.plist"
plutil -insert CFBundleExecutable -string FileMintResourceQA "$RESOURCE_APP/Contents/Info.plist"
plutil -insert CFBundlePackageType -string APPL "$RESOURCE_APP/Contents/Info.plist"
plutil -insert LSUIElement -bool YES "$RESOURCE_APP/Contents/Info.plist"
plutil -insert FixturePath -string "$RESOURCE_FIXTURE" "$RESOURCE_APP/Contents/Info.plist"
if [[ -f "$RESOURCE_BUILD/libFileMintCore.a" ]]; then
  RESOURCE_LINK=(-I "$RESOURCE_BUILD" "$RESOURCE_BUILD/libFileMintCore.a" "$RESOURCE_BUILD/libFileMintImages.a")
else
  RESOURCE_LINK=(-I "$RESOURCE_BUILD/Modules" "$RESOURCE_BUILD"/FileMintCore.build/*.o "$RESOURCE_BUILD"/FileMintImages.build/*.o)
fi
source scripts/image_compression_link.sh
RESOURCE_LINK+=("${FILEMINT_COMPRESSION_LINK[@]}")
filemint_embed_compression "$RESOURCE_APP"
swiftc -swift-version 6 -parse-as-library \
  App/FileMint/DesignSystem.swift App/FileMint/ResourceToolsController.swift App/FileMint/ResourceToolsView.swift \
  App/FileMint/MenuIconControl.swift App/FileMint/SystemSymbolCatalog.swift scripts/native_qa_preferences.swift \
  App/FileMint/PlainTextEditor.swift SharedUI/CustomFileSavePanelController.swift SharedUI/FolderAccess.swift \
  SharedUI/FileToolAppearance.swift \
  scripts/resource_tools_smoke.swift "${RESOURCE_LINK[@]}" \
  -o "$RESOURCE_APP/Contents/MacOS/FileMintResourceQA"
echo "$RESOURCE_APP"
