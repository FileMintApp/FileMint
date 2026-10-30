# P0 synthetic URL transport probe

These tools target only `io.github.daigua.filemint.launcher-integration-qa` and
`filemint-launcher-qa`. They never call the production `filemint` scheme, create
user documents, install launchers, or edit launcher preferences. Complete URLs
are synthetic QA evidence only. Do not enter personal content.

`url_probe.py prepare` creates a fresh manifest with 30 fixed cases, including
raw/invalid percent, invalid UTF-8, Unicode, delimiters, double encoding, empty
text, duplicate/unknown fields and exact 16 KiB URL / 8 KiB decoded-text boundaries.
An edited manifest cannot be sent. The manifest records the crafted caller URL,
the sender's encoding step (none), and the exact string passed as one `open` argv.
The app records the representation it actually receives. Internal transformations
inside `open` and LaunchServices remain unobserved; differences cannot be assigned
to a particular system component.

## System delivery

Use a fresh output directory under the project's ignored `build` directory:

```sh
python3 scripts/launcher_integration/url_probe.py prepare --output build/launcher-url-run-001.noindex
python3 scripts/launcher_integration/url_probe.py send \
  --manifest build/launcher-url-run-001.noindex/manifest.json \
  --case bare-percent --mode delegate
```

`send` checks the stable QA bundle path, bundle ID, `FixtureURLMode`, and code
signature before opening it. It does not build, sign, close, or replace an app.
Build separately for `FixtureURLMode=delegate` and `FixtureURLMode=raw`. Close the
owned QA app normally before changing that build; never force-quit another app.
Run the same case once in each mode. A repeated case/mode needs a fresh manifest,
so evidence cannot silently overwrite a previous attempt.

In delegate mode, only `source=appkit` records count as AppKit delivery. In raw
mode, only `source=gurl` records count as the raw Apple event representation.
`source=foundation-derived` is an explicit in-app conversion, never evidence of
an additional system callback. A custom GURL handler replaces the default event
handler, so the two modes are separate experiments. Receiving a GURL string does
not prove preservation of the original caller's spelling before `open`.

The receiver event contract is NDJSON:

```json
{"event":"url-received","source":"gurl","representation":"filemint-launcher-qa://draft?...","requestID":"<UUID>","buildRunID":"<FixtureRunID>","invocationID":"<run>","parserStatus":"not-evaluated"}
```

Every synthetic request includes `probe=filemint-p0`; only this QA marker permits
full representation logging. Put `id` before the test `text`, so malformed text
does not prevent evidence correlation. Receiver logs are exported through the QA
UI or captured from the owned process's stdout. After export:

```sh
python3 scripts/launcher_integration/url_probe.py compare \
  --manifest build/launcher-url-run-001.noindex/manifest.json \
  --events build/launcher-url-run-001.noindex/receiver.ndjson \
  --output build/launcher-url-run-001.noindex/comparison.json
```

The comparison matches request ID, build ID and actual callback source, reports
all matching deliveries, and compares exact strings. `open` returning 0 is only
dispatch evidence. Missing receiver evidence is **unknown**, never automatically
“system rejected” or “FileMint rejected”. Receiver parse results remain separate
from transport results; this P0 tool is not the future production URL parser.

## Real Raycast entry

Manually copy `raycast-probe.sh` to a user-selected test script directory and add
that directory through Raycast. Do not change the user's existing scripts.
Search for **FileMint P0 URL Probe**, then enter this exact synthetic name:

```text
FileMint-QA 中文 & # + % ? =
```

Record that typed input alongside Raycast's actual version, script output and QA
receiver events. Raycast supplies `percentEncoded` argv; the script logs that
argv and the exact URL passed to `/usr/bin/open -b`. It does not encode the value
again. The UI input is not readable by the script, so never label script argv as
the pre-encoding raw input. The test request ID is fixed
`ab0531ef-2faf-4bdf-86e1-da409f28412b`; separate runs by receiver invocation ID.
This fixed ID belongs only to the P0 probe, not future exported product commands.

Terminal execution with `FILEMINT_QA_PROBE_PRINT_ONLY=1` verifies shell argument
handling only. It does not prove Raycast's encoding or real command dispatch.
The probe prints its argv for observation even if an unexpected Raycast encoding
contains reserved delimiters; the receiver performs no file creation.

## Real Alfred entry

Deferred to phase two by the user's 2026-10-29 scope decision. The encoder and
script below are retained as isolated preparatory material; they do not count
toward this version's Shortcuts/Raycast acceptance. No real Alfred run is claimed.

Requires an installed Alfred with Workflow support. Create an isolated test
workflow manually. Add a Keyword input with an argument and connect it to Run
Script configured as **External Script**, input **argv**, script
`./alfred-probe.sh`. Place `alfred-probe.sh` and `alfred_encode.js` together in that
new workflow folder. Do not substitute `{query}` into script source. Enter the
same synthetic name and capture Alfred's debugger output plus receiver events.

The shell logs raw argv and the system URL. The fixed, pure JXA encoder uses
`encodeURIComponent` with RFC 3986 exceptions encoded; it imports no libraries,
reads no files, and sends no Apple events to another application. The subsequent
system `open` is a separate shell command. Its fixed P0 request ID is
`fbe0125f-01c2-4d32-9ec8-5fc586680e56`. Real Alfred acceptance remains **deferred**;
successful `osascript` execution proves only encoder availability.

## Offline verification

```sh
python3 scripts/launcher_integration/test_url_probe.py
bash -n scripts/launcher_integration/raycast-probe.sh scripts/launcher_integration/alfred-probe.sh
```

Tests verify independently measured byte boundaries, edited-manifest rejection,
unknown delivery despite successful `open`, separation of derived and real
callback evidence, and malicious shell characters remaining data. On macOS they
also run the actual system JXA encoder with Unicode and metacharacters, without
opening any application. macOS 13, real Raycast/Alfred, signed launch/cold-start,
and directory scope results remain separate acceptance records.

API references:

- [Apple URL initializer normalization](https://developer.apple.com/documentation/foundation/url/init(string:))
- [Apple AppKit URL delegate](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:))
- [Raycast Script Command arguments](https://github.com/raycast/script-commands/blob/master/documentation/ARGUMENTS.md)
- [Alfred Run Script argv input](https://www.alfredapp.com/help/workflows/actions/run-script/)
