#!/usr/bin/env python3
"""Build, sign and install FileMint Debug on the current development Mac."""
import argparse
import ctypes
from dataclasses import dataclass
import fcntl
import os
from pathlib import Path
import platform
import plistlib
import re
import subprocess
import sys
import tempfile
import time


ROOT = Path(__file__).resolve().parent.parent
APP = Path("/Applications/FileMint.app")
APP_ID = "io.github.daigua.filemint"
FINDER_ID = APP_ID + ".findersync"
FINDER = Path("Contents/PlugIns/FileMintFinderSync.appex")
LSREGISTER = ("/System/Library/Frameworks/CoreServices.framework/Frameworks/"
              "LaunchServices.framework/Support/lsregister")
DEVELOPER_ID_PREFIX = "Developer ID Application: "


class InstallError(RuntimeError):
    pass


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def output(*args):
    return run(*args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout


@dataclass(frozen=True)
class Signature:
    authority: str
    team: str
    requirement: str
    code_hash: str


def signatures(app):
    result = []
    for bundle, identifier in ((app, APP_ID), (app / FINDER, FINDER_ID)):
        metadata = output("/usr/bin/codesign", "--display", "--verbose=4", "-r-", bundle)
        values = [re.search(r"^" + prefix + r"(.+)$", metadata, re.MULTILINE) for prefix in
                  ("Identifier=", "Authority=", "TeamIdentifier=", "designated => ", "CDHash=")]
        if not all(values):
            raise InstallError(f"Missing Developer ID signing metadata for {bundle}")
        actual_id, authority, team, requirement, code_hash = (value[1] for value in values)
        if actual_id != identifier or not authority.startswith(DEVELOPER_ID_PREFIX):
            raise InstallError(f"Unexpected FileMint bundle identifier or signing identity in {bundle}")
        result.append(Signature(authority, team, requirement, code_hash))
    return tuple(result)


def signing_identity(previous):
    available = set(re.findall(r'"(Developer ID Application: [^"\n]+)"',
                               output("/usr/bin/security", "find-identity", "-v", "-p", "codesigning")))
    selected = os.environ.get("APPLE_CODESIGN_IDENTITY")
    if not selected and previous:
        selected = previous[0].authority
    if not selected and len(available) == 1:
        selected = next(iter(available))
    if selected not in available:
        raise InstallError("Select an available Developer ID Application identity with APPLE_CODESIGN_IDENTITY")
    return selected


def verify_copy(app, expected):
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", app)
    if signatures(app) != expected:
        raise InstallError(f"Signed code hashes or identity changed in {app}")


def bundle_key(path):
    if path.is_symlink() or (path.exists() and not path.is_dir()):
        raise InstallError(f"Expected an application directory at {path}")
    try:
        metadata = path.stat()
    except FileNotFoundError:
        return None
    return metadata.st_dev, metadata.st_ino


def move_bundle(source, destination, *, exchange):
    rename = ctypes.CDLL(None, use_errno=True).renamex_np
    rename.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
    rename.restype = ctypes.c_int
    rename_swap, rename_excl = 0x02, 0x04  # Darwin <stdio.h>
    if rename(os.fsencode(source), os.fsencode(destination), rename_swap if exchange else rename_excl):
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), str(destination))


def replace_bundle(staged, destination, previous_key, expected):
    if bundle_key(destination) != previous_key:
        raise InstallError("The installed bundle changed during preparation. Start a fresh install.")
    candidate_key = bundle_key(staged)
    try:
        move_bundle(staged, destination, exchange=previous_key is not None)
        verify_copy(destination, expected)
    except (Exception, KeyboardInterrupt):
        if bundle_key(destination) == candidate_key and bundle_key(staged) == previous_key:
            if previous_key is None:
                move_bundle(destination, staged, exchange=False)
            else:
                move_bundle(staged, destination, exchange=True)
                print("Restored the previous FileMint bundle.", flush=True)
        raise


def finder_registrations():
    listing = output("/usr/bin/pluginkit", "-m", "-A", "-D", "-v", "-i", FINDER_ID)
    entries = []
    for line in listing.splitlines():
        parts = line.split("\t")
        if len(parts) > 1 and parts[-1].startswith("/"):
            entries.append((Path(parts[-1]), parts[0].strip()[0]))
    return entries


def unregister_temporary(app, standalone_finder=None):
    paths = {app / FINDER, standalone_finder}
    for path, _ in finder_registrations():
        if path in paths:
            run("/usr/bin/pluginkit", "-r", path)
    if app.is_dir():
        try:
            output(LSREGISTER, "-u", app)
        except subprocess.CalledProcessError as error:
            if "-10814" not in error.stdout:  # No registration for this staged bundle.
                raise


def build_candidate(staged, record, identity):
    build_log = record / "xcodebuild.log"
    print(f"Building arm64 Debug. Build log at {build_log}", flush=True)
    with tempfile.TemporaryDirectory(prefix="build.", dir=record) as temporary:
        derived_data = Path(temporary)
        products = derived_data / "Build/Products/Debug"
        built = products / APP.name
        try:
            with build_log.open("w") as log:
                run("make", "project", stdout=log, stderr=subprocess.STDOUT)
                run("/usr/bin/xcodebuild", "-project", "FileMint.xcodeproj", "-scheme", "FileMint",
                    "-configuration", "Debug", "-destination", "platform=macOS,arch=arm64",
                    "-derivedDataPath", derived_data, "-clonedSourcePackagesDirPath", ROOT / "build/SourcePackages",
                    "ENABLE_DEBUG_DYLIB=NO", "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "build",
                    stdout=log, stderr=subprocess.STDOUT)
            run("bash", "scripts/sign_app.sh", built, env=dict(os.environ, APPLE_CODESIGN_IDENTITY=identity))
            run("/usr/bin/ditto", built, staged)
        finally:
            unregister_temporary(built, products / FINDER.name)

    run("bash", "scripts/verify_bundle.sh", staged)
    expected = signatures(staged)
    for bundle, signature in zip((staged, staged / FINDER), expected):
        run("bash", "scripts/verify_developer_id_signature.sh", bundle,
            env=dict(os.environ, APPLE_CODESIGN_IDENTITY=identity, APPLE_TEAM_ID=signature.team))
    return expected


def backup_previous(record, previous):
    archive = record / "previous-FileMint.app.zip"
    run("bash", "scripts/make_zip.sh", APP, env=dict(os.environ, ZIP_PATH=str(archive)))
    with tempfile.TemporaryDirectory(prefix="check-backup.", dir=record) as temporary:
        run("/usr/bin/ditto", "-x", "-k", archive, temporary)
        verify_copy(Path(temporary) / APP.name, previous)
    print(f"Verified previous app backup at {archive}", flush=True)


def process_ids(executable):
    pattern = rf"^{re.escape(str(executable))}([[:space:]]|$)"
    result = subprocess.run(["/usr/bin/pgrep", "-f", pattern], text=True, stdout=subprocess.PIPE)
    if result.returncode == 1:
        return set()
    result.check_returncode()
    return {int(pid) for pid in result.stdout.split()}


def wait_for(check, seconds):
    deadline = time.monotonic() + seconds
    while True:
        result = check()
        if result or time.monotonic() >= deadline:
            return result
        time.sleep(0.5)


def installed_finder_registration():
    entries = finder_registrations()
    return entries if len(entries) == 1 and entries[0][0] == APP / FINDER else []


def launch_installed(previous_finder_pids, previous_election):
    run(LSREGISTER, "-f", APP)
    registration = wait_for(installed_finder_registration, 10)
    if not registration:
        registered = ", ".join(str(path) for path, _ in finder_registrations()) or "none"
        raise InstallError(f"Expected one Finder extension at the installed path. Registrations: {registered}")
    extension_path, election = registration[0]
    print(f"Finder extension registered at {extension_path}", flush=True)

    run("/usr/bin/open", "-a", APP)
    if not wait_for(lambda: process_ids(APP / "Contents/MacOS/FileMint"), 15):
        raise InstallError(f"Launch did not produce a running FileMint at {APP}")
    print(f"Running FileMint at {APP}", flush=True)
    if previous_election in ("+", "-") and previous_election != election:
        print("Finder extension election changed. Check the system's Finder Extensions setting.", file=sys.stderr)
    if election == "+":
        pids = wait_for(lambda: process_ids(extension_path / "Contents/MacOS/FileMintFinderSync")
                        - previous_finder_pids, 10)
        print("Finder extension process reloaded." if pids else
              "Finder extension is enabled. Reload of its process is still unverified.", flush=True)


def install(record):
    previous_key = bundle_key(APP)
    previous = None
    if previous_key is not None:
        run("/usr/bin/codesign", "--verify", "--deep", "--strict", APP)
        previous = signatures(APP)
    identity = signing_identity(previous)
    previous_election = dict(finder_registrations()).get(APP / FINDER)
    finder_executable = APP / FINDER / "Contents/MacOS/FileMintFinderSync"

    with tempfile.TemporaryDirectory(prefix=".filemint-debug.", dir=APP.parent) as temporary:
        staged = Path(temporary) / APP.name
        try:
            expected = build_candidate(staged, record, identity)
            if previous:
                if any(old.requirement != new.requirement for old, new in zip(previous, expected)):
                    raise InstallError("The Debug app or Finder extension signing requirement changed")
                backup_previous(record, previous)
            with (staged / "Contents/Info.plist").open("rb") as source:
                info = plistlib.load(source)
            with (staged / FINDER / "Contents/Info.plist").open("rb") as source:
                finder_info = plistlib.load(source)
            if finder_info["CFBundleVersion"] != info["CFBundleVersion"]:
                raise InstallError("Debug app and Finder extension build numbers differ")

            print("Requesting normal FileMint quit before bundle replacement.", flush=True)
            run("/usr/bin/xcrun", "swift", "scripts/quit_for_debug_install.swift", APP_ID, APP)
            if process_ids(APP / "Contents/MacOS/FileMint"):
                raise InstallError("FileMint is still running. Finish its work and quit before retrying.")
            previous_finder_pids = process_ids(finder_executable)
            if previous:
                verify_copy(APP, previous)
            replace_bundle(staged, APP, previous_key, expected)
            print(f"Installed FileMint {info['CFBundleShortVersionString']} ({info['CFBundleVersion']}) Debug at {APP}",
                  flush=True)
        finally:
            unregister_temporary(staged)
    launch_installed(previous_finder_pids, previous_election)


def main():
    argparse.ArgumentParser(description=__doc__).parse_args()
    try:
        if platform.system() != "Darwin" or platform.machine() != "arm64":
            raise InstallError("Debug installation requires an arm64 Mac")
        if os.getuid() == 0 or not os.access(APP.parent, os.W_OK):
            raise InstallError("Run as the signed-in Mac user with write access to /Applications")
        run("/bin/launchctl", "print", f"gui/{os.getuid()}", stdout=subprocess.DEVNULL)
        os.chdir(ROOT)
        os.environ.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
        base = ROOT / "build/local-debug-install.noindex"
        base.mkdir(parents=True, exist_ok=True)
        with (base / "install.lock").open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as error:
                raise InstallError("Another Debug installation is in progress") from error
            record = Path(tempfile.mkdtemp(prefix="run.", dir=base))
            install(record)
    except (InstallError, OSError, subprocess.CalledProcessError) as error:
        if isinstance(error, subprocess.CalledProcessError) and error.stdout:
            print(error.stdout.strip(), file=sys.stderr)
        print(f"Debug installation stopped. {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
