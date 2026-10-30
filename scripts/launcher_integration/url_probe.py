#!/usr/bin/env python3
"""Synthetic P0 URL transport evidence. Never addresses the production app.

prepare and compare are offline. send explicitly opens the signed, stable QA app;
its exit code describes only /usr/bin/open, never receiver acceptance.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import plistlib
import re
import subprocess
import uuid
from urllib.parse import quote


ROOT = Path(__file__).resolve().parents[2]
BUNDLE_ID = "io.github.daigua.filemint.launcher-integration-qa"
SCHEME = "filemint-launcher-qa"
APP = ROOT / "build/native-qa.noindex/launcher-integration/FileMintLauncherIntegrationQA.app"
MARKER = "probe=filemint-p0"
MAX_EVIDENCE_BYTES = 8 * 1024 * 1024
REQUEST_ID = re.compile(r"(?:[?&])id=([0-9a-f-]{36})(?:&|$)", re.IGNORECASE)


def corpus(run_id):
    """Expected values are transport observations, not a second product parser."""
    samples = [
        ("ascii", "FileMint-QA", "FileMint-QA"),
        ("encoded-unicode", quote("合成 🧪", safe=""), "合成 🧪"),
        ("raw-unicode-space", "合成 QA", "合成 QA"),
        ("bare-percent", "%", None),
        ("incomplete-percent", "%2", None),
        ("nonhex-percent", "%GG", None),
        ("invalid-utf8-byte", "%FF", None),
        ("invalid-utf8-truncated", "%E4%B8", None),
        ("invalid-utf8-overlong", "%C0%AF", None),
        ("invalid-utf8-surrogate", "%ED%A0%80", None),
        ("literal-plus", "+", "+"),
        ("encoded-percent", "%25", "%"),
        ("encoded-slash", "%2F", "/"),
        ("double-encoded-slash", "%252F", "%2F"),
        ("encoded-delimiters", "%26%23%2B%25%3F%3D", "&#+%?="),
        ("literal-question-equals", "?=", "?="),
        ("literal-ampersand", "QA&extra=unexpected", None),
        ("fragment", "QA#synthetic", None),
        ("empty-text", "", ""),
        ("nul-text", "%00", "\0"),
        ("encoded-crlf", "QA%0D%0Aline", "QA\r\nline"),
        ("shell-metacharacters", quote("QA ' \" `literal` $(not-a-command)", safe=""),
         "QA ' \" `literal` $(not-a-command)"),
    ]
    cases = []
    for name, wire_text, decoded in samples:
        request_id = str(uuid.uuid5(uuid.UUID(run_id), name))
        prefix = f"{SCHEME}://draft?v=1&{MARKER}&id={request_id}&name=FileMint-QA.txt&text="
        cases.append(dict(case=name, requestID=request_id, callerTextRepresentation=wire_text,
                          systemArgument=prefix + wire_text, expectedSingleDecodedText=decoded))
    for name, suffix in [("duplicate-version", "&v=1"), ("unknown-field", "&unexpected=1")]:
        request_id = str(uuid.uuid5(uuid.UUID(run_id), name))
        cases.append(dict(case=name, requestID=request_id, callerTextRepresentation="QA",
                          systemArgument=f"{SCHEME}://draft?v=1&{MARKER}&id={request_id}&text=QA{suffix}",
                          expectedSingleDecodedText="QA"))
    for boundary, limit in [("url", 16_384), ("decoded-text", 8_192)]:
        for delta in [-1, 0, 1]:
            name = f"{boundary}-{limit + delta}"
            request_id = str(uuid.uuid5(uuid.UUID(run_id), name))
            prefix = f"{SCHEME}://draft?v=1&{MARKER}&id={request_id}&text="
            count = limit + delta - (len(prefix.encode()) if boundary == "url" else 0)
            text = "a" * count
            cases.append(dict(case=name, requestID=request_id, callerTextRepresentation=text,
                              systemArgument=prefix + text, expectedSingleDecodedText=text))
    for item in cases:
        item["callerURL"] = item["systemArgument"]
        item["senderEncoding"] = "none: deliberately crafted URL passed as one argv value"
    return cases


def read_json(path):
    if path.stat().st_size > MAX_EVIDENCE_BYTES:
        raise ValueError("Evidence exceeds the bounded input limit")
    return json.loads(path.read_text(encoding="utf-8"))


def write_new_json(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def load_manifest(path):
    value = read_json(path)
    if value.get("schemaVersion") != 1 or value.get("bundleID") != BUNDLE_ID:
        raise ValueError("Not a launcher QA manifest")
    # Never send arbitrary URLs or content supplied through an edited manifest.
    if value.get("cases") != corpus(value["runID"]):
        raise ValueError("Manifest differs from the fixed synthetic corpus")
    return value


def prepare(output):
    output.mkdir(parents=True, exist_ok=False)
    run_id = str(uuid.uuid4())
    manifest = dict(schemaVersion=1, bundleID=BUNDLE_ID, scheme=SCHEME, runID=run_id,
                    createdAt=datetime.now(timezone.utc).isoformat(), cases=corpus(run_id))
    write_new_json(output / "manifest.json", manifest)
    print(json.dumps(dict(status="prepared", cases=len(manifest["cases"]), manifest=str(output / "manifest.json"))))


def send(manifest_path, case_name, mode):
    manifest = load_manifest(manifest_path)
    case = next((item for item in manifest["cases"] if item["case"] == case_name), None)
    if case is None:
        raise ValueError("Unknown corpus case")
    if APP.is_symlink() or APP.resolve() != APP:
        raise ValueError("Stable QA application must not be redirected")
    with (APP / "Contents/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    if info.get("CFBundleIdentifier") != BUNDLE_ID or info.get("FixtureURLMode") != mode:
        raise ValueError("Build the stable QA application for the requested receiver mode first")
    subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(APP)], check=True,
                   capture_output=True, timeout=15)
    destination = manifest_path.parent / f"{case_name}-{mode}.attempt.json"
    # Reserve the evidence path before dispatch; retries require a fresh run.
    with destination.open("x", encoding="utf-8") as stream:
        attempt = dict(schemaVersion=1, case=case_name, runID=manifest["runID"],
                       requestID=case["requestID"], receiverMode=mode,
                       buildRunID=info.get("FixtureRunID"), transport="usr-bin-open",
                       callerURL=case["callerURL"], senderEncoding=case["senderEncoding"],
                       systemArgument=case["systemArgument"], systemInputRepresentation="known-argv",
                       receiverObservation="unknown", dispatchStatus="starting")
        json.dump(attempt, stream, ensure_ascii=False)
        stream.flush()
        try:
            result = subprocess.run(["/usr/bin/open", "-a", str(APP), case["systemArgument"]],
                                    capture_output=True, timeout=10)
            attempt.update(dispatchStatus="open-returned", openExitCode=result.returncode,
                           openStderr=result.stderr.decode("utf-8", errors="replace"))
        except subprocess.TimeoutExpired:
            attempt["dispatchStatus"] = "open-timeout"
        stream.seek(0)
        stream.truncate()
        json.dump(attempt, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print(json.dumps(dict(case=case_name, status=attempt["dispatchStatus"],
                          openExitCode=attempt.get("openExitCode"), receiverObservation="unknown")))


def read_events(path):
    if path.stat().st_size > MAX_EVIDENCE_BYTES:
        raise ValueError("Receiver evidence exceeds the bounded input limit")
    events = []
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue  # Console output may also contain system diagnostics.
        if isinstance(event, dict) and event.get("event") == "url-received":
            events.append(event)
    return events


def compare_attempt(attempt, events):
    expected_source = {"raw": "gurl", "delegate": "appkit"}[attempt["receiverMode"]]
    matches = []
    for event in events:
        representation = event.get("representation")
        if not isinstance(representation, str):
            continue
        match = REQUEST_ID.search(representation)
        request_id = event.get("requestID") or (match.group(1) if match else None)
        if request_id != attempt["requestID"] or event.get("source") != expected_source:
            continue
        if event.get("buildRunID") != attempt.get("buildRunID"):
            continue
        matches.append(event)
    return dict(case=attempt["case"], mode=attempt["receiverMode"],
                dispatchStatus=attempt["dispatchStatus"], openExitCode=attempt.get("openExitCode"),
                receiverObservation="observed" if matches else "unknown",
                deliveryCount=len(matches),
                representations=[dict(source=event["source"], representation=event["representation"],
                    unchangedFromSystemArgument=event["representation"] == attempt["systemArgument"],
                    parserStatus=event.get("parserStatus", "not-evaluated"),
                    decodedText=event.get("decodedText")) for event in matches],
                limit="No receiver event does not prove system rejection; sender/system transformations are not separately observable.")


def compare(manifest_path, events_path, output):
    manifest = load_manifest(manifest_path)
    events = read_events(events_path)
    attempts = [read_json(path) for path in sorted(manifest_path.parent.glob("*.attempt.json"))]
    if any(item.get("runID") != manifest["runID"] for item in attempts):
        raise ValueError("Attempt belongs to a different synthetic run")
    report = dict(schemaVersion=1, runID=manifest["runID"],
                  observations=[compare_attempt(item, events) for item in attempts],
                  productParser="not-implemented", realLaunchers="not-proven-by-system-open")
    write_new_json(output, report)
    print(json.dumps(dict(status="compared", attempts=len(attempts), output=str(output))))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("prepare")
    command.add_argument("--output", type=Path, required=True)
    command = commands.add_parser("send")
    command.add_argument("--manifest", type=Path, required=True)
    command.add_argument("--case", required=True)
    command.add_argument("--mode", choices=["raw", "delegate"], required=True)
    command = commands.add_parser("compare")
    command.add_argument("--manifest", type=Path, required=True)
    command.add_argument("--events", type=Path, required=True)
    command.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "prepare":
        prepare(args.output)
    elif args.command == "send":
        send(args.manifest, args.case, args.mode)
    else:
        compare(args.manifest, args.events, args.output)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        raise SystemExit(f"FAIL URL transport probe: {error}")
