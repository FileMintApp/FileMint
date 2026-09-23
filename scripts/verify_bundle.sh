#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:-$PWD/build/DerivedData/Build/Products/Release/FileMint.app}"
EXT="$APP/Contents/PlugIns/FileMintFinderSync.appex"
codesign --verify --deep --strict "$APP"
xcrun swift scripts/verify_signed_entitlements.swift "$APP"
[[ -f "$APP/Contents/Resources/LICENSE" ]]
for executable in "$APP/Contents/MacOS/FileMint" "$EXT/Contents/MacOS/FileMintFinderSync"; do
  ARCHITECTURES="$(lipo -archs "$executable")"
  [[ " $ARCHITECTURES " == *" arm64 "* && " $ARCHITECTURES " == *" x86_64 "* ]]
done
POINT="$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$EXT/Contents/Info.plist")"
[[ "$POINT" == "com.apple.FinderSync" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$APP/Contents/Info.plist")" == "true" ]]
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
EXT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$EXT/Contents/Info.plist")"
[[ "$APP_VERSION" == "$EXT_VERSION" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :SUEnableInstallerLauncherService' "$APP/Contents/Info.plist")" == true ]] || {
  echo 'Release app is missing the Sparkle installer launcher configuration' >&2
  exit 1
}
[[ -f "$APP/Contents/Resources/Sparkle-LICENSE.txt" ]] || { echo 'Missing Sparkle license' >&2; exit 1; }
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for executable in "$SPARKLE/Sparkle" "$SPARKLE/Autoupdate" \
  "$SPARKLE/Updater.app/Contents/MacOS/Updater" \
  "$SPARKLE/XPCServices/Installer.xpc/Contents/MacOS/Installer" \
  "$SPARKLE/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"; do
  ARCHITECTURES="$(lipo -archs "$executable")"
  [[ " $ARCHITECTURES " == *" arm64 "* && " $ARCHITECTURES " == *" x86_64 "* ]] || {
    echo "Sparkle component is not universal: $executable" >&2
    exit 1
  }
done
echo "Verified universal app + Finder extension, version $APP_VERSION."
