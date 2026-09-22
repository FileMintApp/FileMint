#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p build/sparkle-installation-harness.noindex
SPARKLE_QA_ROOT="$(mktemp -d "$PWD/build/sparkle-installation-harness.noindex/run.XXXXXX")"
SPARKLE_QA_FRAMEWORK="$PWD/build/SourcePackages/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
swiftc -swift-version 6 -parse-as-library -target "$(uname -m)-apple-macos13.0" \
  scripts/sparkle_installation_smoke.swift -F "$SPARKLE_QA_FRAMEWORK" -framework Sparkle \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks -o "$SPARKLE_QA_ROOT/UpgradeQA"
python3 - "$SPARKLE_QA_ROOT" "$SPARKLE_QA_FRAMEWORK" <<'PY'
import json, pathlib, plistlib, shutil, socket, subprocess, sys
root, framework = map(pathlib.Path, sys.argv[1:])
identifier = 'io.github.daigua.filemint.upgrade-qa.' + root.name.split('.')[-1].lower()
with socket.socket() as listener:
    listener.bind(('127.0.0.1', 0))
    port = listener.getsockname()[1]
(root / 'fixture.json').write_text(json.dumps(dict(identifier=identifier, port=port), indent=2)+'\n')
(root / 'server').mkdir()
for folder, build, version in [('installation', '1', '1.0.0'), ('payload', '2', '1.0.1')]:
    app = root / folder / 'UpgradeQA.app'
    (app / 'Contents/MacOS').mkdir(parents=True)
    (app / 'Contents/Frameworks').mkdir()
    shutil.copyfile(root / 'UpgradeQA', app / 'Contents/MacOS/UpgradeQA')
    (app / 'Contents/MacOS/UpgradeQA').chmod(0o755)
    subprocess.run(['ditto', str(framework / 'Sparkle.framework'), str(app / 'Contents/Frameworks/Sparkle.framework')], check=True)
    info = dict(CFBundleIdentifier=identifier, CFBundleName='FileMint Update QA', CFBundleExecutable='UpgradeQA',
                CFBundlePackageType='APPL', CFBundleVersion=build, CFBundleShortVersionString=version,
                SUFeedURL=f'http://127.0.0.1:{port}/appcast.xml', SUEnableInstallerLauncherService=True,
                SUEnableDownloaderService=False, SUEnableAutomaticChecks=False, SUAutomaticallyUpdate=False,
                SUEnableSystemProfiling=False, SUVerifyUpdateBeforeExtraction=True,
                NSAppTransportSecurity=dict(NSAllowsLocalNetworking=True))
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    # An inert signed bundle exercises the production extension-signing branch;
    # it declares no Finder extension point and never registers Finder callbacks.
    extension = app / 'Contents/PlugIns/FileMintFinderSync.appex'
    (extension / 'Contents/MacOS').mkdir(parents=True)
    shutil.copyfile(root / 'UpgradeQA', extension / 'Contents/MacOS/UnusedExtension')
    (extension / 'Contents/MacOS/UnusedExtension').chmod(0o755)
    (extension / 'Contents/Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier=identifier+'.finder',
        CFBundleExecutable='UnusedExtension', CFBundleName='Unused QA extension', CFBundlePackageType='XPC!', CFBundleVersion=build)))
PY
swift scripts/sign_update_fixture.swift "$SPARKLE_QA_ROOT"
echo "Isolated installer fixture: $SPARKLE_QA_ROOT"
echo "Serve its server directory on the loopback port in fixture.json, then launch installation/UpgradeQA.app."
