#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

python3 scripts/native_qa.py check-stopped launcher-integration
mkdir -p build/launcher-integration-harness.noindex
LAUNCHER_RUN="$(mktemp -d "$PWD/build/launcher-integration-harness.noindex/run.XXXXXX")"
bash scripts/launcher_integration/build_probe.sh "$LAUNCHER_RUN" "${1:-delegate}" \
  >"$LAUNCHER_RUN/build.log" 2>&1 || {
    python3 - "$LAUNCHER_RUN/build.log" <<'PY'
from pathlib import Path
import sys
lines = Path(sys.argv[1]).read_text(errors='replace').splitlines()
diagnostics = [line for line in lines if 'error:' in line or 'warning:' in line or 'BUILD FAILED' in line]
print('\n'.join(line[:800] for line in (diagnostics[-20:] or lines[-10:])))
print('Full build log:', sys.argv[1])
PY
    exit 1
  }
LAUNCHER_APP="$LAUNCHER_RUN/products/FileMintLauncherIntegrationQA.app"
test -f "$LAUNCHER_APP/Contents/Resources/Metadata.appintents/extract.actionsdata" || {
  echo "App Intents metadata missing; see $LAUNCHER_RUN/build.log" >&2
  exit 1
}
python3 - "$LAUNCHER_RUN/entitlements.plist" <<'PY'
import plistlib, sys
from pathlib import Path
Path(sys.argv[1]).write_bytes(plistlib.dumps({
    'com.apple.security.app-sandbox': True,
    'com.apple.security.files.user-selected.read-write': True,
}))
PY
codesign --force --options runtime --sign - --timestamp=none \
  --entitlements "$LAUNCHER_RUN/entitlements.plist" "$LAUNCHER_APP"
LAUNCHER_PUBLISHED="$(python3 scripts/native_qa.py publish launcher-integration "$LAUNCHER_APP" "$LAUNCHER_RUN")"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f "$LAUNCHER_PUBLISHED"
printf '%s\n' "$LAUNCHER_PUBLISHED"
