#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build --package-path CorePackage >/dev/null
TEMPLATE_CORE="$(swift build --package-path CorePackage --show-bin-path)"
TEMPLATE_RUN="$(mktemp -d "$PWD/build/template-workflow-harness.XXXXXX")"
TEMPLATE_APP="$TEMPLATE_RUN/TemplateWorkflowSmoke.app"
TEMPLATE_RECEIVER="$TEMPLATE_APP/Contents/Resources/TemplateReceiver.app"
mkdir -p "$TEMPLATE_APP/Contents/MacOS" "$TEMPLATE_RECEIVER/Contents/MacOS"
cp -R CorePackage/Sources/FileMintCore/Resources/OfficeTemplates "$TEMPLATE_APP/Contents/Resources/"
cp Resources/SFSymbolNames.txt Resources/SFSymbolRestrictedNames.txt "$TEMPLATE_APP/Contents/Resources/"
python3 - "$TEMPLATE_APP" "$TEMPLATE_RECEIVER" "$TEMPLATE_RUN" <<'PY'
import pathlib, plistlib, sys
app, receiver, root=map(pathlib.Path,sys.argv[1:])
for path,identifier,executable in [(app,'io.github.daigua.filemint.template-workflow-smoke','TemplateWorkflowSmoke'),(receiver,'io.github.daigua.filemint.template-receiver','TemplateReceiver')]:
 info=dict(CFBundleIdentifier=identifier,CFBundleName=executable,CFBundleExecutable=executable,CFBundlePackageType='APPL',CFBundleVersion='1',LSUIElement=True)
 if path==receiver: info['CFBundleDocumentTypes']=[dict(CFBundleTypeRole='Viewer',LSHandlerRank='None',LSItemContentTypes=['public.item'])]
 (path/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
(root/'entitlements.plist').write_bytes(plistlib.dumps({'com.apple.security.app-sandbox':True,'com.apple.security.files.user-selected.read-write':True,'com.apple.security.files.bookmarks.app-scope':True}))
PY
if [[ -f "$TEMPLATE_CORE/libFileMintCore.a" ]]; then
 TEMPLATE_LINK=(-I "$TEMPLATE_CORE" "$TEMPLATE_CORE/libFileMintCore.a" "$TEMPLATE_CORE/libFileMintImages.a")
else
 TEMPLATE_LINK=(-I "$TEMPLATE_CORE/Modules" "$TEMPLATE_CORE"/FileMintCore.build/*.o "$TEMPLATE_CORE"/FileMintImages.build/*.o)
fi
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.0 -D TEMPLATE_RECEIVER scripts/template_workflow_smoke.swift "${TEMPLATE_LINK[@]}" -o "$TEMPLATE_RECEIVER/Contents/MacOS/TemplateReceiver"
codesign --force --sign - --timestamp=none "$TEMPLATE_RECEIVER"
TEMPLATE_SOURCES=()
while IFS= read -r TEMPLATE_SOURCE; do TEMPLATE_SOURCES+=("$TEMPLATE_SOURCE"); done < <(rg --files App/FileMint SharedUI | rg '\.swift$' | rg -v '/(FileMintApp|AppDelegate)\.swift$')
TEMPLATE_SPARKLE="$PWD/build/SourcePackages/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.0 "${TEMPLATE_SOURCES[@]}" FinderSyncExtension/FileMintFinderSync/FinderIntegrationStatus.swift scripts/template_workflow_smoke.swift "${TEMPLATE_LINK[@]}" -F "$TEMPLATE_SPARKLE" -framework Sparkle -Xlinker -rpath -Xlinker "$TEMPLATE_SPARKLE" -o "$TEMPLATE_APP/Contents/MacOS/TemplateWorkflowSmoke"
codesign --force --sign - --timestamp=none --entitlements "$TEMPLATE_RUN/entitlements.plist" "$TEMPLATE_APP"
codesign --verify --strict "$TEMPLATE_APP"
echo "$TEMPLATE_APP"
