#!/usr/bin/env bash
# Compile only. The owning native-QA builder signs and publishes the staged app.
set -euo pipefail
PROBE_SOURCE="$(cd "$(dirname "$0")" && pwd)"
PROBE_RUN="${1:?Pass a fresh absolute QA run directory}"
PROBE_MODE="${2:-delegate}"
[[ "$PROBE_RUN" = /* ]] || { echo 'QA run directory must be absolute' >&2; exit 2; }
[[ "$PROBE_MODE" = delegate || "$PROBE_MODE" = raw ]] || { echo 'URL mode must be delegate or raw' >&2; exit 2; }
PROBE_APP="$PROBE_RUN/products/FileMintLauncherIntegrationQA.app"
[[ ! -e "$PROBE_APP" ]] || { echo 'Refusing to rebuild a pre-existing staged QA app' >&2; exit 2; }

# Xcode registers macOS app products even when CODE_SIGNING_ALLOWED=NO. Keeping
# that unsigned registration makes Shortcuts cold-launch the staging copy instead
# of the published Developer ID app. Clean only this invocation's exact product;
# the owning publisher registers the stable, verified app after publication.
unregister_probe_product() {
  local probe_result=$?
  trap - EXIT
  # Info.plist can exist before compilation succeeds. Without the executable,
  # Xcode has not reached its product-registration task; preserve that original
  # compilation error instead of emitting a second missing-app cleanup failure.
  if [[ -f "$PROBE_APP/Contents/Info.plist" && -x "$PROBE_APP/Contents/MacOS/FileMintLauncherIntegrationQA" ]]; then
    local probe_identifier
    probe_identifier="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$PROBE_APP/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$probe_identifier" = io.github.daigua.filemint.launcher-integration-qa ]]; then
      if ! /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$PROBE_APP"; then
        echo 'Could not unregister this staged QA product; do not use it for runtime evidence' >&2
        [[ "$probe_result" != 0 ]] || probe_result=1
      fi
    else
      echo 'Refusing registration cleanup for an unexpected staged bundle identity' >&2
      [[ "$probe_result" != 0 ]] || probe_result=1
    fi
  fi
  exit "$probe_result"
}
trap unregister_probe_product EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# Freeze all compilation inputs together. A concurrent edit must not combine an
# older deployment target with newer Swift sources in one evidence build.
PROBE_INPUT="$PROBE_RUN/source"
mkdir -p "$PROBE_RUN"
mkdir "$PROBE_INPUT"
for PROBE_FILE in ProbeApp.swift project.yml Info.plist Probe.entitlements; do
  cp "$PROBE_SOURCE/$PROBE_FILE" "$PROBE_INPUT/$PROBE_FILE"
done
python3 - "$PROBE_INPUT" "$PROBE_SOURCE" <<'PY'
import hashlib, json, sys
from pathlib import Path
source, original = map(Path, sys.argv[1:])
files = ('ProbeApp.swift', 'project.yml', 'Info.plist', 'Probe.entitlements')
manifest = {'schemaVersion': 1, 'files': {
    name: hashlib.sha256((source / name).read_bytes()).hexdigest() for name in files
}}
if any(hashlib.sha256((original / name).read_bytes()).hexdigest() != manifest['files'][name] for name in files):
    raise SystemExit('Probe source changed while capturing inputs; rebuild from a settled checkout')
with (source / 'manifest.json').open('x') as output:
    json.dump(manifest, output, indent=2)
    output.write('\n')
PY
mkdir -p "$PROBE_RUN/project"
xcodegen generate --spec "$PROBE_INPUT/project.yml" --project "$PROBE_RUN/project"
xcodebuild -project "$PROBE_RUN/project/FileMintLauncherIntegrationQA.xcodeproj" \
  -scheme FileMintLauncherIntegrationQA -configuration Release \
  -derivedDataPath "$PROBE_RUN/DerivedData" \
  CONFIGURATION_BUILD_DIR="$PROBE_RUN/products" \
  INFOPLIST_FILE="$PROBE_INPUT/Info.plist" \
  CODE_SIGN_ENTITLEMENTS="$PROBE_INPUT/Probe.entitlements" \
  FILEMINT_FIXTURE_RUN_ID="$(basename "$PROBE_RUN")" FILEMINT_FIXTURE_URL_MODE="$PROBE_MODE" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
