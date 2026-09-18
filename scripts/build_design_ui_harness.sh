#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build --package-path CorePackage
DESIGN_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
mkdir -p build/design-ui-harness.noindex
DESIGN_FIXTURE="$(mktemp -d "$PWD/build/design-ui-harness.noindex/run.XXXXXX")"
DESIGN_APP="$DESIGN_FIXTURE/FileMintDesignQA.app"
DESIGN_FRAMEWORKS="$PWD/build/SourcePackages/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
mkdir -p "$DESIGN_APP/Contents/MacOS"
plutil -create xml1 "$DESIGN_APP/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string io.github.daigua.filemint.design-qa "$DESIGN_APP/Contents/Info.plist"
plutil -insert CFBundleName -string 'FileMint Design QA' "$DESIGN_APP/Contents/Info.plist"
plutil -insert CFBundleExecutable -string FileMintDesignQA "$DESIGN_APP/Contents/Info.plist"
plutil -insert CFBundlePackageType -string APPL "$DESIGN_APP/Contents/Info.plist"
plutil -insert CFBundleShortVersionString -string 0.5.6 "$DESIGN_APP/Contents/Info.plist"
plutil -insert CFBundleVersion -string 14 "$DESIGN_APP/Contents/Info.plist"
plutil -insert FixturePath -string "$DESIGN_FIXTURE" "$DESIGN_APP/Contents/Info.plist"
cp Resources/IconSource/FileMint-AppIcon-1024.png "$DESIGN_FIXTURE/AppIcon.png"
DESIGN_SOURCES=()
for source in App/FileMint/*.swift; do
  case "$source" in */FileMintApp.swift|*/AppDelegate.swift) ;; *) DESIGN_SOURCES+=("$source") ;; esac
done
if [[ -f "$DESIGN_BUILD/libFileMintCore.a" ]]; then
  DESIGN_LINK=(-I "$DESIGN_BUILD" "$DESIGN_BUILD/libFileMintCore.a" "$DESIGN_BUILD/libFileMintImages.a")
else
  DESIGN_LINK=(-I "$DESIGN_BUILD/Modules" "$DESIGN_BUILD"/FileMintCore.build/*.o "$DESIGN_BUILD"/FileMintImages.build/*.o)
fi
swiftc -swift-version 6 -parse-as-library -target "$(uname -m)-apple-macos13.0" \
  "${DESIGN_SOURCES[@]}" SharedUI/*.swift FinderSyncExtension/FileMintFinderSync/FinderIntegrationStatus.swift \
  scripts/design_ui_smoke.swift "${DESIGN_LINK[@]}" -F "$DESIGN_FRAMEWORKS" -framework Sparkle \
  -Xlinker -rpath -Xlinker "$DESIGN_FRAMEWORKS" -o "$DESIGN_APP/Contents/MacOS/FileMintDesignQA"
echo "$DESIGN_APP"
