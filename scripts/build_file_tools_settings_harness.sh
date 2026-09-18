#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build --package-path CorePackage
CORE_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
mkdir -p build/file-tools-settings-harness.noindex
FIXTURE_DIRECTORY="$(mktemp -d "$PWD/build/file-tools-settings-harness.noindex/run.XXXXXX")"
APP_PATH="$FIXTURE_DIRECTORY/FileMintToolsUIQA.app"
mkdir -p "$APP_PATH/Contents/MacOS"
python3 - "$APP_PATH" "$FIXTURE_DIRECTORY" <<'PY'
import pathlib, plistlib, sys
app, root = map(pathlib.Path, sys.argv[1:])
info = dict(CFBundleIdentifier="io.github.daigua.filemint.tools-ui-qa", CFBundleName="FileMint Tools UI QA",
            CFBundleExecutable="FileMintToolsUIQA", CFBundlePackageType="APPL", CFBundleVersion="1",
            NSPrincipalClass="NSApplication", FixturePath=str(root))
(app / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
PY
if [[ -f "$CORE_BUILD/libFileMintCore.a" ]]; then
  CORE_LINK=(-I "$CORE_BUILD" "$CORE_BUILD/libFileMintCore.a")
else
  CORE_LINK=(-I "$CORE_BUILD/Modules" "$CORE_BUILD"/FileMintCore.build/*.o)
fi
swiftc -swift-version 6 -parse-as-library \
  App/FileMint/FileToolsSettingsView.swift SharedUI/FileToolAppearance.swift \
  scripts/file_tools_settings_smoke.swift "${CORE_LINK[@]}" \
  -o "$APP_PATH/Contents/MacOS/FileMintToolsUIQA"
echo "Built isolated native settings fixture:"
echo "$APP_PATH"
