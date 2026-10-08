#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

TEMPLATE_APP="${1:?Pass the bundle path returned by build_template_workflow_harness.sh}"
case "$TEMPLATE_APP" in
  "$PWD"/build/template-workflow-harness.*/TemplateWorkflowSmoke.app) ;;
  *) echo "Expected a disposable template workflow bundle in this checkout." >&2; exit 64 ;;
esac
TEMPLATE_RECEIVER="$TEMPLATE_APP/Contents/Resources/TemplateReceiver.app"
TEMPLATE_REGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# App Sandbox forbids explicit LaunchServices registration. Prepare the unique
# fixture type in the host, then remove only this test app's registration.
trap '"$TEMPLATE_REGISTER" -u "$TEMPLATE_RECEIVER" >/dev/null 2>&1' EXIT
"$TEMPLATE_REGISTER" -f "$TEMPLATE_RECEIVER"
FILEMINT_TEMPLATE_QA_MODE=opening "$TEMPLATE_APP/Contents/MacOS/TemplateWorkflowSmoke"
