#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

TEMPLATE_APP="${1:?Pass the bundle path returned by build_template_workflow_harness.sh}"
TEMPLATE_EXPECTED_APP="$(python3 scripts/native_qa.py path template-workflow)"
if [[ "$TEMPLATE_APP" != "$TEMPLATE_EXPECTED_APP" ]]; then
  echo "Expected the stable template workflow QA bundle in this checkout: $TEMPLATE_EXPECTED_APP" >&2
  exit 64
fi
TEMPLATE_RECEIVER="$TEMPLATE_APP/Contents/Resources/TemplateReceiver.app"
TEMPLATE_REGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# App Sandbox forbids explicit LaunchServices registration. Prepare the unique
# fixture type in the host, then remove only this QA receiver's registration.
trap '"$TEMPLATE_REGISTER" -u "$TEMPLATE_RECEIVER" >/dev/null 2>&1' EXIT
"$TEMPLATE_REGISTER" -f "$TEMPLATE_RECEIVER"
FILEMINT_TEMPLATE_QA_MODE=opening "$TEMPLATE_APP/Contents/MacOS/TemplateWorkflowSmoke"
