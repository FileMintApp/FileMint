#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build --package-path CorePackage
CORE_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
mkdir -p build/move-sandbox-harness.noindex
SMOKE_DIRECTORY="$(mktemp -d "$PWD/build/move-sandbox-harness.noindex/run.XXXXXX")"
APP_PATH="$SMOKE_DIRECTORY/FileMintMoveSandboxSmoke.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$SMOKE_DIRECTORY/fixtures/source/Demo.app/Contents" "$SMOKE_DIRECTORY/fixtures/target"
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
  CORE_LINK=(-I "$CORE_BUILD" "$CORE_BUILD/libFileMintCore.a")
else
  CORE_LINK=(-I "$CORE_BUILD/Modules" "$CORE_BUILD"/FileMintCore.build/*.o)
fi
swiftc -swift-version 6 -parse-as-library \
  App/FileMint/FileOperationCoordinator.swift scripts/move_sandbox_smoke.swift \
  "${CORE_LINK[@]}" -o "$APP_PATH/Contents/MacOS/FileMintMoveSandboxSmoke"
codesign --force --options runtime --sign - --timestamp=none \
  --entitlements "$SMOKE_DIRECTORY/entitlements.plist" "$APP_PATH"
codesign --verify --strict "$APP_PATH"
echo "Built isolated sandbox harness (interactive authorization checks required):"
echo "$APP_PATH"
