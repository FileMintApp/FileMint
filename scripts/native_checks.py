#!/usr/bin/env python3
"""Plan and run existing local native QA fixtures without touching production data."""
import argparse
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
import fcntl
from fnmatch import fnmatchcase
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import signal
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
import native_qa as qa

ROOT = Path(__file__).resolve().parent.parent


@dataclass(frozen=True)
class Suite:
    kind: str
    marker: str
    arguments: tuple = ()
    environment: tuple = ()


SUITES = {
    "batch-rename": Suite("batch-rename", "PASS batch rename sandbox:"),
    "template-workflow": Suite("template-workflow", "PASS template workflow:"),
    "creation-opening": Suite("template-workflow", "PASS creation opening:", environment=(("FILEMINT_TEMPLATE_QA_MODE", "opening"),)),
    "update-scheduling": Suite("template-workflow", "PASS pre-release fixes:", environment=(("FILEMINT_TEMPLATE_QA_MODE", "review-fixes"),)),
    "open-with": Suite("open-with", "PASS sandbox open-with:"),
    "file-tools-settings": Suite("file-tools-settings", "PASS native icon styles", ("--verify-icons",)),
    "file-info": Suite("file-info", "PASS file information:", environment=(("FILEMINT_FILE_INFO_EXPORT_ARTIFACTS", "1"),)),
    "resource-tools": Suite("resource-tools", "PASS original preserved; clipboard untouched; no owner preferences loaded;"),
    "design-ui": Suite("design-ui", "PASS automated design QA:", ("--verify-automation",)),
    "update-summary": Suite("design-ui", "PASS update summary QA:", ("--verify-updates",)),
    "favorite-model": Suite("", "PASS favorite model"),
}
ALL = tuple(SUITES)
BUILDERS = {kind: f"scripts/build_{kind.replace('-', '_')}_harness.sh"
            for kind in {suite.kind for suite in SUITES.values() if suite.kind}}
MANUAL = {
    "finder": "Installed Finder menu/callback delivery needs the affected Finder QA scenario.",
    "folder-grants": "External folder picker and saved access across process restarts need signed installed-app checks.",
    "move-sandbox": "The existing move fixture still requires explicit external-folder authorization.",
    "update-sandbox": "The legacy update fixture requires a real save panel; also run the applicable update-client checks.",
    "sparkle-installation": "Actual signed old/new replacement and relaunch require the isolated installer scenario.",
    "access-migration": "Access migration requires declared Full Disk Access and a separately enabled QA Finder extension.",
    "login-items": "System login-item registration needs its affected native system scenario.",
    "terminal-apps": "Real terminal tab/window/cwd delivery needs its selected application scenario.",
    "favorite-search": "Quick-search keyboard/selection behavior needs the affected native interaction check.",
}

# Shared-file rules are conservative; --suite is the reviewed behavior-based override.
RULES = (
    (("scripts/native_checks.py", "scripts/test_native_checks.py", "scripts/native_qa.py", "scripts/test_native_qa.py",
      "scripts/native_qa_running.swift", "scripts/native_qa_preferences.swift", "scripts/image_compression_link.sh", "Makefile"), ALL, ()),
    (("scripts/batch_rename_smoke.swift", "scripts/build_batch_rename_harness.sh", "App/FileMint/BatchRename*.swift"), ("batch-rename",), ()),
    (("scripts/file_info_smoke.swift", "scripts/build_file_info_harness.sh", "App/FileMint/FileInfo*.swift"), ("file-info",), ("folder-grants",)),
    (("scripts/file_content_copy_checks.swift", "App/FileMint/FileContent*.swift"), ("file-info",), ("folder-grants",)),
    (("scripts/template_workflow_smoke.swift", "scripts/build_template_workflow_harness.sh"), ("template-workflow", "creation-opening", "update-scheduling"), ()),
    (("scripts/creation_opening_checks.swift", "scripts/run_creation_opening_checks.sh"), ("creation-opening",), ()),
    (("scripts/open_with_smoke.swift", "scripts/build_open_with_harness.sh", "App/FileMint/OpenWithApplicationAccess.swift"), ("open-with", "creation-opening"), ()),
    (("scripts/file_tools_settings_smoke.swift", "scripts/build_file_tools_settings_harness.sh"), ("file-tools-settings",), ()),
    (("scripts/resource_tools_smoke.swift", "scripts/build_resource_tools_harness.sh", "App/FileMint/ResourceTools*.swift"), ("resource-tools",), ()),
    (("scripts/design_ui_smoke.swift", "scripts/build_design_ui_harness.sh"), ("design-ui", "update-summary"), ()),
    (("App/FileMint/AboutPane.swift", "App/FileMint/UserGuideLink.swift"), ("update-summary",), ()),
    (("scripts/favorite_model_smoke.swift", "scripts/verify_favorite_model.sh", "App/FileMint/FavoriteLocationsModel.swift"), ("favorite-model", "design-ui"), ()),
    (("App/FileMint/PreferencesModel.swift",), ("template-workflow", "creation-opening", "update-scheduling", "design-ui"), ()),
    (("SharedUI/CustomFileSavePanelController.swift", "App/FileMint/PlainTextEditor.swift", "App/FileMint/CreationApplicationLabel.swift",
      "App/FileMint/PostCreationActionExecutor.swift", "App/FileMint/Template*.swift", "App/FileMint/TypesPane.swift"), ("template-workflow", "creation-opening", "design-ui"), ()),
    (("App/FileMint/UpdateModel.swift",), ("update-scheduling", "design-ui"), ()),
    (("App/FileMint/ContentView.swift", "App/FileMint/Settings*.swift", "App/FileMint/FoldersPane.swift", "App/FileMint/FavoriteLocationsView.swift"), ("design-ui",), ()),
    (("App/FileMint/FileToolsSettingsView.swift", "App/FileMint/OpenWithSettingsView.swift"), ("file-tools-settings", "design-ui"), ()),
    (("SharedUI/FileToolAppearance.swift", "App/FileMint/DesignSystem.swift", "App/FileMint/MenuIconControl.swift",
      "App/FileMint/SystemSymbolCatalog.swift", "Resources/Assets.xcassets/*", "Resources/SFSymbol*"), ("file-tools-settings", "template-workflow", "resource-tools", "design-ui"), ()),
    (("App/FileMint/FileOperationCoordinator.swift",), ("batch-rename", "open-with", "creation-opening", "file-info"), ()),
    (("App/FileMint/BatchRenameAccess.swift", "CorePackage/Sources/FileMintCore/BatchRenameAccessStore.swift"), ("batch-rename",), ("folder-grants",)),
    (("App/FileMint/OpenWithFolderAccess.swift", "CorePackage/Sources/FileMintCore/OpenWithFolderAccessStore.swift"), ("open-with",), ("folder-grants",)),
    (("SharedUI/FolderAccess.swift",), ("batch-rename", "open-with", "creation-opening"), ("folder-grants",)),
    (("App/FileMint/TerminalDirectoryLauncher.swift",), ("open-with",), ("terminal-apps",)),
    (("App/FileMint/FavoriteQuickPanelController.swift", "App/FileMint/FavoriteFeedbackController.swift"), ("design-ui", "favorite-model"), ("favorite-search",)),
    (("FinderSyncExtension/*",), ("file-tools-settings", "batch-rename", "open-with", "creation-opening", "file-info"), ("finder",)),
    (("App/FileMint/AppDelegate.swift", "App/FileMint/FileMintApp.swift", "App/FileMint/FinderHiddenItemsService.swift"), ("design-ui", "creation-opening", "update-scheduling"), ("finder",)),
    (("App/FileMint/LoginItemService.swift",), ("design-ui",), ("login-items",)),
    (("App/FileMint/UpdateClient.swift", "scripts/update_sandbox_smoke.swift", "scripts/build_update_sandbox_harness.sh"), (), ("update-sandbox",)),
    (("App/FileMint/SparkleInstaller.swift", "scripts/*sparkle*", "scripts/sign_update_fixture.swift"), (), ("sparkle-installation",)),
    (("scripts/move_sandbox_smoke.swift", "scripts/build_move_sandbox_harness.sh"), (), ("move-sandbox",)),
    (("scripts/*access_migration*", "scripts/sign_access_migration_fixture.swift"), (), ("access-migration",)),
    (("CorePackage/Sources/FileMintCore/FileOperation*.swift", "CorePackage/Sources/FileMintCore/QuickCreationTicket*.swift"), ("batch-rename", "open-with", "creation-opening", "file-info"), ()),
    # Build-only edits use the compilation/artifact row of HARNESS, not automatic GUI replay.
    (("project.yml", "CorePackage/Package.swift"), (), ()),
    (("CorePackage/Artifacts/*",), ("resource-tools",), ()),
    (("CorePackage/Sources/FileMintCore/Resources/*",), ("template-workflow", "creation-opening"), ()),
)


def git(*arguments):
    return subprocess.check_output(["git", *arguments], cwd=ROOT, stderr=subprocess.PIPE)


def changed_paths(base=None):
    revision = git("rev-parse", "--verify", "--end-of-options", f"{base or 'HEAD'}^{{commit}}").decode().strip()
    paths = git("diff", "--name-only", "--no-renames", "-z", revision, "--").split(b"\0")
    paths += git("ls-files", "--others", "--exclude-standard", "-z").split(b"\0")
    return sorted({os.fsdecode(path) for path in paths if path})


def source_state():
    untracked = {}
    for raw in git("ls-files", "--others", "--exclude-standard", "-z").split(b"\0"):
        if not raw:
            continue
        path = ROOT / os.fsdecode(raw)
        digest = hashlib.sha256()
        if path.is_symlink():
            digest.update(os.fsencode(os.readlink(path)))
        else:
            with path.open("rb") as source:
                for block in iter(lambda: source.read(1024 * 1024), b""):
                    digest.update(block)
        untracked[os.fsdecode(raw)] = digest.hexdigest()
    return dict(commit=git("rev-parse", "HEAD").decode().strip(),
                workingDiffSHA256=hashlib.sha256(git("diff", "--binary", "HEAD", "--")).hexdigest(),
                untrackedSHA256=untracked)


def plan_checks(paths, explicit=(), all_suites=False):
    if any(name not in SUITES for name in explicit):
        raise ValueError("Unknown automatic suite; interactive fixtures remain separate")
    normalized = []
    for path in paths:
        parsed = PurePosixPath(path)
        if not path or parsed.is_absolute() or ".." in parsed.parts:
            raise ValueError("Changed paths must be relative repository paths")
        normalized.append(str(parsed))
    selected, manual, unknown, reasons = set(), set(), [], {}
    if explicit or all_suites:
        selected.update(ALL if all_suites else explicit)
        reasons = {name: ["explicit reviewed scope"] for name in selected}
    else:
        for path in normalized:
            if path.endswith((".md", ".mdx")) or path.startswith(("docs/", "specs/", "website/")):
                continue
            matches = [rule for rule in RULES if any(fnmatchcase(path, pattern) for pattern in rule[0])]
            for _, suites, boundaries in matches:
                selected.update(suites)
                manual.update(boundaries)
                for name in suites:
                    reasons.setdefault(name, []).append(path)
            if not matches and path.startswith(("App/", "SharedUI/", "FinderSyncExtension/", "Config/")):
                unknown.append(path)
    return dict(schemaVersion=1, selection="explicit" if explicit or all_suites else "changed-paths",
                paths=sorted(set(normalized)), suites=[name for name in ALL if name in selected],
                reasons={name: sorted(set(reasons[name])) for name in ALL if name in selected},
                manualChecks=[dict(id=name, reason=MANUAL[name]) for name in MANUAL if name in manual],
                requiresReview=sorted(set(unknown)))


def child_environment(suite=None):
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith("FILEMINT_") or key == "FILEMINT_QA_CODESIGN_IDENTITY"}
    environment.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    if suite:
        environment.update(suite.environment)
    return environment


def execute(arguments, log, timeout, markers=(), environment=None):
    """Only terminate the new subprocess group owned by this call, never other apps."""
    started = time.monotonic()
    timed_out = False
    interrupted = False
    with Path(log).open("wb") as output:
        process = subprocess.Popen(list(map(str, arguments)), cwd=ROOT, env=environment,
                                   stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
        except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
            timed_out = isinstance(error, subprocess.TimeoutExpired)
            interrupted = not timed_out
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                code = process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                return dict(status="blocked", reason="Owned subprocess did not stop after timeout; close it normally",
                            pid=process.pid, timedOut=True, log=str(log), seconds=time.monotonic() - started)
    with Path(log).open("rb") as source:
        source.seek(max(0, Path(log).stat().st_size - 4 * 1024 * 1024))
        lines = source.read().decode("utf-8", errors="replace").splitlines()
    missing = [marker for marker in markers if not any(line.startswith(marker) for line in lines)]
    failed = timed_out or interrupted or code != 0 or bool(missing) or any(line.startswith("FAIL ") for line in lines)
    return dict(status="failed" if failed else "passed", exitCode=code, timedOut=timed_out,
                interrupted=interrupted, missingMarkers=missing, log=str(log), seconds=round(time.monotonic() - started, 3))


@contextmanager
def lock_file(path):
    if path.is_symlink():
        raise qa.QAError("Native-check lock must not be a symlink")
    with path.open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise qa.QAError("Another native QA invocation owns this lock") from error
        yield


def verify_fixture(kind, previous_run=None):
    app = qa.app_path(kind)
    if any(path.is_symlink() for path in (ROOT / "build", ROOT / "build/native-qa.noindex", app.parent, app)):
        raise qa.QAError("Stable fixture directories must not be symlinks")
    info = qa.read_info(app)
    run_id = info.get("FixtureRunID")
    if (info.get("CFBundleIdentifier") != qa.KINDS[kind][1] or not isinstance(run_id, str)
            or not re.fullmatch(r"[A-Za-z0-9._-]{1,128}", run_id) or run_id in (".", "..")):
        raise qa.QAError("Missing published fixture identity")
    if run_id == previous_run:
        raise qa.QAError("Builder reused a stale fixture run")
    identity = qa.signing_identity()
    requirement = qa.verified_requirement(app, identity)
    pin_path = app.parent / "identity.json"
    if pin_path.is_symlink():
        raise qa.QAError("Fixture identity record must not be a symlink")
    pin = json.loads(pin_path.read_text())
    if (pin.get("workspace") != str(ROOT) or pin.get("appPath") != str(app)
            or pin.get("bundleID") != info["CFBundleIdentifier"] or pin.get("signingIdentity") != identity
            or pin.get("designatedRequirement") != requirement):
        raise qa.QAError("Published fixture differs from its pinned identity")
    name = info.get("CFBundleExecutable")
    if not isinstance(name, str) or PurePosixPath(name).name != name or name in ("", ".", ".."):
        raise qa.QAError("Invalid fixture executable name")
    executable = app / "Contents/MacOS" / name
    if (executable.is_symlink() or not executable.resolve().is_relative_to(app.resolve())
            or not executable.is_file() or not os.access(executable, os.X_OK)):
        raise qa.QAError("Missing owned fixture executable")
    return dict(app=str(app), bundleID=info["CFBundleIdentifier"], runID=run_id,
                designatedRequirement=requirement, executable=str(executable))


def preflight(names):
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise qa.QAError("Native checks need an arm64 macOS host")
    environment = child_environment()
    # Identity/process helpers inherit this same command-scoped Xcode.
    os.environ.setdefault("DEVELOPER_DIR", environment["DEVELOPER_DIR"])
    subprocess.run(["xcrun", "--find", "swiftc"], check=True, capture_output=True, env=environment, timeout=15)
    kinds = {SUITES[name].kind for name in names if SUITES[name].kind}
    if kinds:
        subprocess.run(["launchctl", "print", f"gui/{os.getuid()}"], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        identities = subprocess.check_output(["security", "find-identity", "-v", "-p", "codesigning"], text=True, timeout=15)
        if qa.signing_identity() not in identities:
            raise qa.QAError("Selected local Developer ID signing identity is unavailable")
        for kind in sorted(kinds):
            qa.assert_stopped(kind)
    return {"xcode": subprocess.check_output(["xcodebuild", "-version"], text=True, stderr=subprocess.STDOUT, env=environment, timeout=15).strip(),
            "swift": subprocess.check_output(["swift", "--version"], text=True, stderr=subprocess.STDOUT, env=environment, timeout=15).strip()}


def run_plan(plan, timeout=180, build_timeout=600):
    base = ROOT / "build/native-checks.noindex"
    for directory in (ROOT / "build", base):
        if directory.is_symlink():
            raise qa.QAError("Native-check report directories must not be symlinks")
        directory.mkdir(exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="run.", dir=base))
    report = dict(plan=plan, source=source_state(), startedAt=datetime.now(timezone.utc).isoformat(),
                  environment=dict(system=platform.system(), architecture=platform.machine(), macOS=platform.mac_ver()[0]),
                  status="running", checks=[], builds=[], report=str(output / "report.json"))

    def save():
        qa.write_json(output / "report.json", report)

    def finish():
        observed = {check["suite"] for check in report["checks"]}
        for name in plan["suites"]:
            if name not in observed:
                report["checks"].append(dict(suite=name, status="not-run", reason=report.get("error", "Prerequisite did not complete")))
        statuses = [value["status"] for value in report["checks"] + report["builds"]]
        if "failed" in statuses:
            report["status"] = "failed"
        elif report.get("error") or "blocked" in statuses or "not-run" in statuses or plan["manualChecks"] or plan["requiresReview"]:
            report["status"] = "blocked"
        else:
            report["status"] = "passed" if plan["suites"] else "not-applicable"
        report["finishedAt"] = datetime.now(timezone.utc).isoformat()
        save()
        return report

    save()
    try:
        with lock_file(base / "runner.lock"):
            if not plan["suites"]:
                return finish()
            report["environment"].update(preflight(plan["suites"]) or {})
            environment = child_environment()
            if any(SUITES[name].kind in ("template-workflow", "design-ui") for name in plan["suites"]):
                # Resolve the existing pinned framework without creating or registering
                # a second production App/Finder extension bundle on the developer's Mac.
                prerequisites = [
                    ("project", ["make", "project"]),
                    ("packages", ["xcodebuild", "-resolvePackageDependencies", "-project", "FileMint.xcodeproj",
                                  "-scheme", "FileMint", "-clonedSourcePackagesDirPath", str(ROOT / "build/SourcePackages"),
                                  "-derivedDataPath", str(output / "ResolvedData")]),
                ]
                for label, command in prerequisites:
                    result = execute(command, output / f"prepare-{label}.log", build_timeout, environment=environment)
                    report["builds"].append(dict(kind=label, **result))
                    save()
                    if result["status"] != "passed":
                        return finish()
            built = {}
            for name in plan["suites"]:
                suite = SUITES[name]
                if source_state() != report["source"]:
                    raise qa.QAError("Working source changed during native QA; rerun the affected checks")
                if suite.kind and suite.kind not in built:
                    app = qa.app_path(suite.kind)
                    previous = qa.read_info(app).get("FixtureRunID") if app.exists() else None
                    result = execute(["bash", BUILDERS[suite.kind]], output / f"build-{suite.kind}.log", build_timeout, environment=environment)
                    report["builds"].append(dict(kind=suite.kind, **result))
                    save()
                    if result["status"] != "passed":
                        for affected in plan["suites"]:
                            if SUITES[affected].kind == suite.kind:
                                report["checks"].append(dict(suite=affected, status="blocked", reason="Fresh fixture build failed"))
                        built[suite.kind] = None
                        if result["status"] == "blocked" or result.get("interrupted"):
                            return finish()
                        continue
                    built[suite.kind] = verify_fixture(suite.kind, previous)
                if suite.kind and built[suite.kind] is None:
                    continue
                if not suite.kind:
                    result = execute(["bash", "scripts/verify_favorite_model.sh"], output / f"{name}.log", build_timeout,
                                     (suite.marker,), environment)
                    report["checks"].append(dict(suite=name, **result))
                else:
                    fixture = built[suite.kind]
                    with lock_file(qa.app_path(suite.kind).parent / "publish.lock"):
                        qa.assert_stopped(suite.kind)
                        if verify_fixture(suite.kind)["runID"] != fixture["runID"]:
                            raise qa.QAError("Fixture was replaced after its build")
                        command = [fixture["executable"], *suite.arguments]
                        if name == "creation-opening":
                            command = ["bash", "scripts/run_creation_opening_checks.sh", fixture["app"]]
                        result = execute(command, output / f"{name}.log", timeout, (suite.marker,), child_environment(suite))
                        report["checks"].append(dict(suite=name, fixture=fixture, **result))
                print(f"{result['status'].upper()} native {name}", flush=True)
                save()
                if result["status"] == "blocked" or result.get("interrupted"):
                    return finish()
            if source_state() != report["source"]:
                raise qa.QAError("Working source changed during native QA; results belong to the earlier source")
    except (qa.QAError, OSError, ValueError, subprocess.SubprocessError) as error:
        report["error"] = str(error)
    return finish()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("plan", "run"))
    parser.add_argument("--base", default=os.environ.get("NATIVE_QA_BASE") or None)
    parser.add_argument("--path", action="append")
    parser.add_argument("--suite", action="append", choices=SUITES,
                        default=[name for name in os.environ.get("NATIVE_QA_SUITES", "").split(",") if name])
    parser.add_argument("--all", action="store_true", help="Explicitly run all automatic suites")
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--build-timeout", type=float, default=600)
    arguments = parser.parse_args(argv)
    if arguments.timeout <= 0 or arguments.build_timeout <= 0:
        parser.error("Timeouts must be positive")
    try:
        paths = arguments.path if arguments.path is not None else changed_paths(arguments.base)
        plan = plan_checks(paths, arguments.suite, arguments.all)
        if arguments.mode == "plan":
            print(json.dumps(plan, ensure_ascii=False, indent=2))
            return 0
        report = run_plan(plan, arguments.timeout, arguments.build_timeout)
        print(f"Native QA {report['status']}: {report['report']}")
        if report.get("error"):
            print(report["error"], file=sys.stderr)
        return {"passed": 0, "not-applicable": 0, "failed": 1, "blocked": 2}[report["status"]]
    except (qa.QAError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Native QA setup blocked: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
