#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
python3 scripts/native_qa.py check-stopped launcher-product
mkdir -p build/launcher-product-harness.noindex
PRODUCT_RUN="$(mktemp -d "$PWD/build/launcher-product-harness.noindex/run.XXXXXX")"
PRODUCT_HOST="$(mktemp -d /private/tmp/FileMint-Launchers-QA.XXXXXX)"
PRODUCT_APP="$PRODUCT_RUN/products/FileMintLauncherProductQA.app"
cleanup_staging_registration() {
  local result=$?
  trap - EXIT
  if [[ -x "$PRODUCT_APP/Contents/MacOS/FileMintLauncherProductQA" ]]; then
    local identifier
    identifier="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$PRODUCT_APP/Contents/Info.plist")"
    if [[ "$identifier" = io.github.daigua.filemint.launcher-product-qa ]]; then
      /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$PRODUCT_APP" || result=1
    else
      echo 'Unexpected staged product QA identity; no registration cleanup performed' >&2
      result=1
    fi
  fi
  exit "$result"
}
trap cleanup_staging_registration EXIT
python3 - "$PRODUCT_RUN" "$PRODUCT_HOST" <<'PY'
import hashlib,json,os,shutil,sys
from pathlib import Path
run,host=map(Path,sys.argv[1:])
root=Path.cwd()
source=run/'source'
source.mkdir()
directories=['App/FileMint','SharedUI','CorePackage/Sources','CorePackage/Tests','CorePackage/Artifacts','Resources/Assets.xcassets']
files=['CorePackage/Package.swift','Resources/SFSymbolNames.txt','Resources/SFSymbolRestrictedNames.txt']
for name in directories:
    shutil.copytree(root/name,source/name,symlinks=True)
for name in files:
    (source/name).parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(root/name,source/name)
extra={'scripts/launcher_product/FixtureApp.swift':'FixtureApp.swift','scripts/launcher_product/project.yml':'project.yml',
       'scripts/launcher_product/verify_metadata.py':'verify_metadata.py',
       'FinderSyncExtension/FileMintFinderSync/FinderIntegrationStatus.swift':'FinderIntegrationStatus.swift'}
for name,target in extra.items():shutil.copy2(root/name,source/target)
manifest={}
for path in sorted(source.rglob('*')):
    if path.is_symlink():
        if not path.resolve().is_relative_to(source.resolve()):raise SystemExit('Snapshot link escapes owned sources')
        payload=os.readlink(path).encode()
    elif path.is_file():payload=path.read_bytes()
    else:continue
    relative=str(path.relative_to(source))
    original=next((root/name for name,target in extra.items() if target==relative),root/relative)
    expected=os.readlink(original).encode() if original.is_symlink() else original.read_bytes()
    if payload!=expected:raise SystemExit('Source changed while capturing QA build')
    manifest[relative]=hashlib.sha256(payload).hexdigest()
(source/'manifest.json').write_text(json.dumps({'schemaVersion':1,'files':manifest},indent=2)+'\n')
metadata=host.stat()
(run/'host-fixture.json').write_text(json.dumps({'path':str(host),'device':str(metadata.st_dev),'inode':str(metadata.st_ino)},indent=2)+'\n')
PY
mkdir -p "$PRODUCT_RUN/project"
if ! xcodegen generate --spec "$PRODUCT_RUN/source/project.yml" --project "$PRODUCT_RUN/project" >"$PRODUCT_RUN/build.log" 2>&1; then
  tail -n 15 "$PRODUCT_RUN/build.log" >&2
  exit 1
fi
if ! xcodebuild -project "$PRODUCT_RUN/project/FileMintLauncherProductQA.xcodeproj" \
  -scheme FileMintLauncherProductQA -configuration Release -derivedDataPath "$PRODUCT_RUN/DerivedData" \
  -clonedSourcePackagesDirPath "$PWD/build/SourcePackages" CONFIGURATION_BUILD_DIR="$PRODUCT_RUN/products" \
  INFOPLIST_FILE="$PRODUCT_RUN/source/Info.plist" \
  FILEMINT_FIXTURE_RUN_ID="$(basename "$PRODUCT_RUN")" FILEMINT_FIXTURE_HOST_DIRECTORY="$PRODUCT_HOST" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build >>"$PRODUCT_RUN/build.log" 2>&1; then
  python3 - "$PRODUCT_RUN/build.log" <<'PY'
from pathlib import Path
import sys
lines=Path(sys.argv[1]).read_text(errors='replace').splitlines()
print('\n'.join(line[:700] for line in lines if ('error:' in line and 'CoreSimulator' not in line) or 'BUILD FAILED' in line))
print('Full build log:',sys.argv[1])
PY
  exit 1
fi
test -f "$PRODUCT_APP/Contents/Resources/Metadata.appintents/extract.actionsdata"
python3 "$PRODUCT_RUN/source/verify_metadata.py" "$PRODUCT_APP/Contents/Resources/Metadata.appintents/extract.actionsdata"
python3 - "$PRODUCT_RUN/entitlements.plist" <<'PY'
import plistlib,sys
from pathlib import Path
Path(sys.argv[1]).write_bytes(plistlib.dumps({'com.apple.security.app-sandbox':True,
    'com.apple.security.files.user-selected.read-write':True,'com.apple.security.files.bookmarks.app-scope':True}))
PY
codesign --force --options runtime --sign - --timestamp=none --entitlements "$PRODUCT_RUN/entitlements.plist" "$PRODUCT_APP"
PRODUCT_PUBLISHED="$(python3 scripts/native_qa.py publish launcher-product "$PRODUCT_APP" "$PRODUCT_RUN")"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$PRODUCT_PUBLISHED"
printf '%s\n' "$PRODUCT_PUBLISHED"
printf 'Reserved host fixture: %s\n' "$PRODUCT_HOST"
