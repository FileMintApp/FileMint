#!/usr/bin/env python3
"""Publish each signed native QA kind at a stable, isolated application path."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_IDENTITY = "Developer ID Application: Guangzhou Guangbei Vertex Technology co.,Ltd (8S66M2ZLD5)"
KINDS = {
    "template-workflow": ("TemplateWorkflowSmoke.app", "io.github.daigua.filemint.template-workflow-smoke", ("io.github.daigua.filemint.template-receiver",)),
    "open-with": ("OpenWithSmoke.app", "io.github.daigua.filemint.open-with-smoke", ("io.github.daigua.filemint.open-with-receiver",)),
    "file-tools-settings": ("FileMintToolsUIQA.app", "io.github.daigua.filemint.tools-ui-qa", ()),
    "move-sandbox": ("FileMintMoveSandboxSmoke.app", "io.github.daigua.filemint.move-smoke", ()),
    "update-sandbox": ("FileMintUpdateSandboxSmoke.app", "io.github.daigua.filemint.update-smoke", ()),
    "design-ui": ("FileMintDesignQA.app", "io.github.daigua.filemint.design-qa", ()),
    "resource-tools": ("FileMintResourceQA.app", "io.github.daigua.filemint.resource-qa", ()),
    "sparkle-installation": ("UpgradeQA.app", "io.github.daigua.filemint.upgrade-qa", ()),
    "access-migration": ("FileMintAccessQA.app", "io.github.daigua.filemint.access-qa", ("io.github.daigua.filemint.access-qa.finder",)),
}


class QAError(RuntimeError):
    pass


def command(args):
    result = subprocess.run(list(map(str, args)), text=True, capture_output=True, timeout=120)
    if result.returncode:
        raise QAError(f"{args[0]} failed: {result.stderr.strip()[:1000]}")
    return result.stdout + result.stderr


def signing_identity():
    identity = os.environ.get("FILEMINT_QA_CODESIGN_IDENTITY") or os.environ.get("APPLE_CODESIGN_IDENTITY") or DEFAULT_IDENTITY
    if not identity.startswith("Developer ID Application: "):
        raise QAError("Stable native QA requires the local Developer ID certificate; set FILEMINT_QA_CODESIGN_IDENTITY to select it")
    return identity


def app_path(kind):
    return ROOT / "build/native-qa.noindex" / kind / KINDS[kind][0]


def assert_stopped(kind):
    identifiers = (KINDS[kind][1], *KINDS[kind][2])
    active = json.loads(command(["xcrun", "swift", "-target", "arm64-apple-macos13.0",
                                 ROOT / "scripts/native_qa_running.swift", *identifiers]))
    if not isinstance(active, list) or active:
        raise QAError("Close this QA app and its receiver before rebuilding; running fixtures are never replaced")


def read_info(app):
    path = app / "Contents/Info.plist"
    if path.is_symlink():
        raise QAError("QA Info.plist must be a regular owned file")
    with path.open("rb") as source:
        return plistlib.load(source)


def sign_bundle(app, identity):
    # Preserve the previous sandbox entitlements and runtime flags. Re-sign all
    # nested executable code from the inside out, including native frameworks.
    targets = []
    magic = {b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe", b"\xfe\xed\xfa\xcf",
             b"\xfe\xed\xfa\xce", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"}
    for path in app.rglob("*"):
        if path.is_symlink():
            continue
        if path.is_dir() and path.suffix in (".app", ".appex", ".xpc", ".framework"):
            targets.append(path)
        elif path.is_file():
            with path.open("rb") as source:
                if source.read(4) in magic:
                    targets.append(path)
    for target in sorted(targets, key=lambda path: len(path.parts), reverse=True) + [app]:
        command(["codesign", "--force", "--timestamp=none", "--sign", identity,
                 "--preserve-metadata=entitlements,flags", target])


def verified_requirement(app, identity):
    command(["codesign", "--verify", "--strict", "--deep", app])
    metadata = command(["codesign", "-d", "--verbose=4", "-r-", app])
    requirement = next((line for line in metadata.splitlines() if line.startswith("designated => ")), "")
    identifier = read_info(app).get("CFBundleIdentifier")
    if f"Authority={identity}\n" not in metadata or f"Identifier={identifier}\n" not in metadata or not requirement:
        raise QAError("QA signing identity or designated requirement is missing/mismatched")
    return requirement


def write_json(path, value):
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, prefix=".qa-state-", delete=False) as output:
        temporary = Path(output.name)
        json.dump(value, output, indent=2)
        output.write("\n")
        output.flush()
        os.fsync(output.fileno())
    os.replace(temporary, path)


def publish(kind, source_app, run_root, already_signed=False):
    source_app, run_root = Path(source_app).absolute(), Path(run_root).absolute()
    base = ROOT / "build/native-qa.noindex"
    destination = app_path(kind)
    if source_app.is_symlink() or run_root.is_symlink():
        raise QAError("QA source app/run cannot be symlinks")
    try:
        run_root.resolve().relative_to((ROOT / "build").resolve())
        source_app.resolve().relative_to(run_root.resolve())
    except ValueError as error:
        raise QAError("Publish only a generated QA app inside its build run") from error
    if source_app.name != KINDS[kind][0] or source_app == destination or base in run_root.parents:
        raise QAError("Invalid QA staging application or run root")
    if not re.fullmatch(r"[A-Za-z0-9._-]{1,128}", run_root.name):
        raise QAError("Invalid fixture run ID")
    for directory in (ROOT / "build", base, destination.parent):
        if directory.is_symlink():
            raise QAError("Stable QA directories must not be symlinks")
        directory.mkdir(exist_ok=True)
    identity = signing_identity()
    pin_path = destination.parent / "identity.json"
    if pin_path.is_symlink() or destination.is_symlink():
        raise QAError("Stable QA app/identity record must not be symlinks")
    if already_signed and kind not in ("sparkle-installation", "access-migration"):
        raise QAError("Only pre-signed installer fixtures preserve their archive signing session")
    info = read_info(source_app)
    if info.get("CFBundleIdentifier") != KINDS[kind][1]:
        raise QAError("QA bundle identifier differs from its fixed kind")
    with (destination.parent / "publish.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise QAError("Another publisher owns this QA kind") from error
        assert_stopped(kind)
        with tempfile.TemporaryDirectory(prefix=".publish-", dir=destination.parent) as temporary:
            stage = Path(temporary)
            candidate = stage / destination.name
            command(["ditto", source_app, candidate])
            if already_signed:
                if info.get("FixtureRunID") != run_root.name:
                    raise QAError("Pre-signed installer host has a different fixture run ID")
            else:
                candidate_info = read_info(candidate)
                candidate_info["FixtureRunID"] = run_root.name
                (candidate / "Contents/Info.plist").write_bytes(plistlib.dumps(candidate_info))
                sign_bundle(candidate, identity)
            requirement = verified_requirement(candidate, identity)
            pin = dict(schemaVersion=1, workspace=str(ROOT), bundleID=KINDS[kind][1],
                       appPath=str(destination), signingIdentity=identity, designatedRequirement=requirement)
            if pin_path.exists():
                if json.loads(pin_path.read_text()) != pin:
                    raise QAError("Pinned QA identity changed; preserve the existing app and investigate")
            elif destination.exists():
                raise QAError("Existing QA app has no owned identity record; preserve it")
            if destination.exists():
                if read_info(destination).get("CFBundleIdentifier") != KINDS[kind][1] or verified_requirement(destination, identity) != requirement:
                    raise QAError("Existing QA application identity changed; preserve it")
            assert_stopped(kind)
            if not pin_path.exists():
                write_json(pin_path, pin)
            # Keep a backup outside the staging cleanup: even a failed rollback
            # must leave the last verified application recoverable.
            backup = destination.parent / f".previous-{uuid.uuid4().hex}.app"
            if destination.exists():
                os.replace(destination, backup)
            try:
                os.replace(candidate, destination)
            except OSError:
                if backup.exists():
                    try:
                        os.replace(backup, destination)
                    except OSError as error:
                        raise QAError(f"QA replacement failed; previous verified app retained at {backup}") from error
                raise
            if backup.exists():
                shutil.rmtree(backup)
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="mode", required=True)
    subparsers.add_parser("signing-identity")
    for mode in ("bundle-id", "path", "check-stopped"):
        subparsers.add_parser(mode).add_argument("kind", choices=KINDS)
    builder = subparsers.add_parser("publish")
    builder.add_argument("kind", choices=KINDS)
    builder.add_argument("source_app", type=Path)
    builder.add_argument("run_root", type=Path)
    builder.add_argument("--already-signed", action="store_true")
    args = parser.parse_args()
    if args.mode == "signing-identity":
        print(signing_identity())
    elif args.mode == "bundle-id":
        print(KINDS[args.kind][1])
    elif args.mode == "path":
        print(app_path(args.kind))
    elif args.mode == "check-stopped":
        assert_stopped(args.kind)
    else:
        print(publish(args.kind, args.source_app, args.run_root, args.already_signed))


if __name__ == "__main__":
    try:
        main()
    except (QAError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"Native QA setup failed: {error}", file=sys.stderr)
        sys.exit(2)
