#!/usr/bin/env python3
"""Prepare a reviewed Cask or synchronize an existing tap from release evidence.

This tool never installs an application, creates a repository, dispatches Actions,
or downloads release archives. Only ``publish`` can update the existing tap.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import uuid
from urllib.parse import urlencode

sys.dont_write_bytecode = True
import release_publication as publication


ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "scripts/homebrew/filemint.rb.in"
SKELETON = ROOT / "scripts/homebrew/tap"
TAP_REPO = "FileMintApp/homebrew-tap"
TAP_URL = f"https://github.com/{TAP_REPO}.git"
CERTIFICATE = ROOT / "Config/Signing/DeveloperIDApplication-8S66M2ZLD5.cer"
MANIFEST_FIELDS = frozenset(("version", "build", "tag", "commit", "dmgSHA256",
                             "zipSHA256", "certificateSHA256", "appcastSHA256",
                             "zipAppcastSHA256", "notarySubmissionID"))
HASH_FIELDS = frozenset(("dmgSHA256", "zipSHA256", "certificateSHA256",
                        "appcastSHA256", "zipAppcastSHA256"))
# Homebrew 6's --online implies --download. These audits fetch/extract the DMG;
# local publication reuses verify_release_pair.sh for signatures, architecture
# and minimum OS instead. Local Homebrew 6.0.11 also requires a `verified` URL
# parameter that current Homebrew rejects; retain current public Cask syntax and
# skip only that obsolete local metadata rule. Actions retains the full audit.
LOCAL_AUDIT_EXCLUSIONS = ("download", "signing", "rosetta", "min_os",
                          "missing_verified", "unnecessary_verified")


class TapError(RuntimeError):
    pass


def run(args, *, cwd=ROOT, env=None):
    if len(args) > 1 and args[0] == "brew":
        step = "online metadata audit" if args[1] == "audit" else args[1]
        print(f"Homebrew validation: {step}", file=sys.stderr, flush=True)
    result = subprocess.run([str(arg) for arg in args], cwd=cwd, env=env,
                            text=True, capture_output=True, timeout=600)
    if result.returncode:
        raise TapError(f"{args[0]} failed: {result.stderr.strip()[:1000]}")
    return result.stdout.strip()


def regular_file(path):
    path = Path(path)
    if path.is_symlink() or not path.is_file():
        raise TapError(f"Expected a regular file: {path.name}")
    return path


def digest(path):
    result = hashlib.sha256()
    with regular_file(path).open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def unique_object(pairs):
    result = {}
    for name, value in pairs:
        if name in result:
            raise TapError(f"Duplicate JSON field: {name}")
        result[name] = value
    return result


def read_json(path):
    path = regular_file(path)
    if path.stat().st_size > 1024 * 1024:
        raise TapError("JSON evidence exceeds its size limit")
    try:
        return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_object)
    except (ValueError, UnicodeError) as error:
        raise TapError("Invalid JSON evidence") from error


def version_key(version):
    if not isinstance(version, str) or not re.fullmatch(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)", version):
        raise TapError("Invalid stable version")
    return tuple(int(part) for part in version.split("."))


def positive(value, label):
    if type(value) is not int or value <= 0:
        raise TapError(f"Invalid {label}")
    return value


def load_manifest(path):
    manifest = read_json(path)
    if (not isinstance(manifest, dict) or set(manifest) != MANIFEST_FIELDS
            or any(type(value) is not str for value in manifest.values())):
        raise TapError("Expected the ten-string-field DMG/ZIP release manifest")
    version_key(manifest["version"])
    if manifest["tag"] != f"v{manifest['version']}":
        raise TapError("Manifest version/tag mismatch")
    if (not re.fullmatch(r"[1-9][0-9]*", manifest["build"])
            or not re.fullmatch(r"[0-9a-f]{40}", manifest["commit"])):
        raise TapError("Invalid manifest build or commit")
    if any(not re.fullmatch(r"[0-9a-f]{64}", manifest[field]) for field in HASH_FIELDS):
        raise TapError("Invalid manifest SHA-256")
    if not re.fullmatch(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", manifest["notarySubmissionID"]):
        raise TapError("Invalid notarization submission ID")
    return manifest


def artifact_paths(manifest_path, manifest):
    directory, version = Path(manifest_path).parent, manifest["version"]
    return {
        f"FileMint-{version}.dmg": directory / f"FileMint-{version}.dmg",
        f"FileMint-{version}.dmg.sha256": directory / f"FileMint-{version}.dmg.sha256",
        f"FileMint-{version}.zip": directory / f"FileMint-{version}.zip",
        f"FileMint-{version}.zip.sha256": directory / f"FileMint-{version}.zip.sha256",
        "appcast.xml": directory / f"FileMint-{version}.appcast.xml",
        "appcast-zip.xml": directory / f"FileMint-{version}.appcast-zip.xml",
    }


def validate_local(manifest_path, manifest):
    paths = artifact_paths(manifest_path, manifest)
    version = manifest["version"]
    hashes = {f"FileMint-{version}.dmg": "dmgSHA256",
              f"FileMint-{version}.zip": "zipSHA256",
              "appcast.xml": "appcastSHA256", "appcast-zip.xml": "zipAppcastSHA256"}
    for name, path in paths.items():
        size = regular_file(path).stat().st_size
        limit = 65_536 if name.endswith(".xml") else (4096 if name.endswith(".sha256") else 1_073_741_824)
        if not 0 < size <= limit:
            raise TapError("Release artifact exceeds its size limit")
        if name in hashes and digest(path) != manifest[hashes[name]]:
            raise TapError(f"Local {name} does not match its manifest SHA-256")
    for extension, field in (("dmg", "dmgSHA256"), ("zip", "zipSHA256")):
        name = f"FileMint-{version}.{extension}"
        expected = f"{manifest[field]}  {name}\n".encode("ascii")
        if paths[f"{name}.sha256"].read_bytes() != expected:
            raise TapError(f"Invalid portable {extension.upper()} checksum")
    if digest(CERTIFICATE) != manifest["certificateSHA256"]:
        raise TapError("Release certificate does not match the manifest")
    local_commit = run(["git", "rev-parse", "--verify", f"refs/tags/{manifest['tag']}^{{commit}}"])
    if local_commit != manifest["commit"]:
        raise TapError("Local release tag does not match the manifest commit")
    environment = os.environ.copy()
    environment.pop("FILEMINT_ALLOW_PENDING_053", None)
    environment.update(APPLE_TEAM_ID="8S66M2ZLD5",
                       APPLE_CODESIGN_IDENTITY="Developer ID Application: Guangzhou Guangbei Vertex Technology co.,Ltd (8S66M2ZLD5)")
    run(["bash", str(ROOT / "scripts/verify_release_pair.sh"), paths[f"FileMint-{version}.dmg"],
         version, manifest["build"], paths["appcast.xml"], paths["appcast-zip.xml"]], env=environment)


class ReadOnlyGitHub(publication.GitHub):
    def api(self, endpoint, method="GET", body=None, missing_ok=False):
        if method != "GET" or body is not None:
            raise TapError("Homebrew evidence checks only permit GitHub GET requests")
        return super().api(endpoint, method=method, missing_ok=missing_ok)


class TapGitHub:
    def api(self, endpoint):
        path = f"repos/{TAP_REPO}" + (f"/{endpoint}" if endpoint else "")
        payload = run(["gh", "api", path, "--method", "GET", "-H", "Accept: application/vnd.github+json"])
        try:
            return json.loads(payload, object_pairs_hook=unique_object)
        except ValueError as error:
            raise TapError("Tap API returned invalid JSON") from error


def verified_run(gh, run_id, attempt, workflow, commit, branch, request=None):
    run_id, attempt = positive(run_id, "workflow run ID"), positive(attempt, "verified attempt")
    record = gh.api(f"actions/runs/{run_id}")
    if (not isinstance(record, dict) or record.get("id") != run_id
            or not publication.matching_run(record, workflow, commit, branch, request)
            or record.get("status") != "completed" or record.get("conclusion") != "success"
            or record.get("run_attempt") != attempt):
        raise TapError(f"Exact {workflow} run/attempt is not successfully verified")
    return {"id": run_id, "attempt": attempt}


def requested_run(gh, state, manifest, kind):
    record = state.get("requests", {}).get(kind)
    if not isinstance(record, dict):
        raise TapError(f"Missing {kind} verification request")
    request_id = record.get("request_id", "")
    if not isinstance(request_id, str) or not re.fullmatch(r"[0-9a-f]{32}", request_id):
        raise TapError(f"Invalid {kind} request identity")
    title = f"FileMint {kind} {request_id}"
    branch = "main" if kind == "deploy" else manifest["tag"]
    commit = record.get("commit", "")
    if (record.get("title") != title or record.get("ref") != branch
            or not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit)
            or (kind != "deploy" and commit != manifest["commit"])):
        raise TapError(f"Invalid {kind} workflow binding")
    return verified_run(gh, record.get("run_id"), record.get("verified_attempt"),
                        publication.WORKFLOWS[kind], commit, branch, title)


def validate_release(manifest_path, gh=None, require_complete=False):
    manifest_path = Path(manifest_path).absolute()
    manifest = load_manifest(manifest_path)
    validate_local(manifest_path, manifest)
    state = read_json(manifest_path.with_name(f"FileMint-{manifest['version']}.publication.json"))
    if (not isinstance(state, dict) or type(state.get("schemaVersion")) is not int
            or state.get("schemaVersion") != 1 or state.get("candidate") != manifest
            or state.get("phase") not in ("published", "complete")
            or not isinstance(state.get("requests"), dict)
            or type(state.get("website_required")) is not bool):
        raise TapError("Publication journal does not prove this published candidate")
    if require_complete and not (state["phase"] == "complete" or state.get("distribution_complete") is True):
        raise TapError("Finish application publication and applicable website deployment before tap synchronization")
    release_id = positive(state.get("release_id"), "release ID")
    assets = state.get("assets")
    if (not isinstance(assets, list) or any(not isinstance(item, dict) for item in assets)
            or any(set(item) != {"name", "id", "size"} or not isinstance(item["name"], str)
                   or type(item["id"]) is not int or item["id"] <= 0
                   or type(item["size"]) is not int or item["size"] <= 0 for item in assets)):
        raise TapError("Missing verified release assets")
    gh = gh or ReadOnlyGitHub()
    release = publication.check_public(gh, release_id, manifest["tag"], manifest["commit"], assets)
    # Bind API sizes and optional server digests to the already verified local bytes.
    # Remote artifact authenticity is established by the exact candidate run below.
    paths = artifact_paths(manifest_path, manifest)
    for asset in release["assets"]:
        path = paths[asset["name"]]
        if asset["size"] != path.stat().st_size:
            raise TapError("Published asset size differs from the local verified artifact")
        if asset.get("digest") is not None and asset["digest"] != f"sha256:{digest(path)}":
            raise TapError("Published asset digest differs from the local verified artifact")
    runs = {"ci": verified_run(gh, state.get("ci_run_id"), state.get("ci_verified_attempt"),
                               "ci.yml", manifest["commit"], "main"),
            "candidate": requested_run(gh, state, manifest, "candidate")}
    if require_complete and state["website_required"]:
        runs["site"] = requested_run(gh, state, manifest, "site")
        runs["deploy"] = requested_run(gh, state, manifest, "deploy")
    return {"schemaVersion": 1, "manifest": manifest, "release_id": release_id,
            "assets": assets, "runs": runs,
            "caskSHA256": hashlib.sha256(render_cask(manifest["version"], manifest["dmgSHA256"]).encode()).hexdigest()}


def render_cask(version, sha256):
    version_key(version)
    if not isinstance(sha256, str) or not re.fullmatch(r"[0-9a-f]{64}", sha256):
        raise TapError("Invalid Cask SHA-256")
    template = regular_file(TEMPLATE).read_text(encoding="utf-8")
    if template.count("@VERSION@") != 1 or template.count("@SHA256@") != 1:
        raise TapError("Cask template must contain exactly the version and SHA-256 placeholders")
    return template.replace("@VERSION@", version).replace("@SHA256@", sha256)


def parse_cask(text):
    if not isinstance(text, str) or len(text) > 65_536:
        raise TapError("Invalid Cask text")
    versions = re.findall(r'^  version "([0-9.]+)"$', text, re.MULTILINE)
    hashes = re.findall(r'^  sha256 "([0-9a-f]{64})"$', text, re.MULTILINE)
    if len(versions) != 1 or len(hashes) != 1 or render_cask(versions[0], hashes[0]) != text:
        raise TapError("Existing Cask differs from the reviewed declarative template")
    return versions[0], hashes[0]


def skeleton_files():
    if SKELETON.is_symlink() or not SKELETON.is_dir():
        raise TapError("Missing tap skeleton")
    result = {}
    for path in SKELETON.rglob("*"):
        if path.is_symlink():
            raise TapError("Tap skeleton must not contain symlinks")
        if path.is_file():
            name = path.relative_to(SKELETON).as_posix()
            if ".git" in path.relative_to(SKELETON).parts or name in ("Casks/filemint.rb", "receipt.json"):
                raise TapError("Unexpected tap skeleton entry")
            result[name] = path.read_bytes()
    if not result:
        raise TapError("Tap skeleton is empty")
    return result


def prepare(manifest_path, output_dir, gh=None):
    receipt = validate_release(manifest_path, gh=gh)
    manifest = receipt["manifest"]
    files = skeleton_files()
    files["Casks/filemint.rb"] = render_cask(manifest["version"], manifest["dmgSHA256"]).encode()
    files["receipt.json"] = (json.dumps(receipt, indent=2, sort_keys=True) + "\n").encode()
    output = Path(output_dir).absolute()
    if any(path.is_symlink() for path in (output, *output.parents)):
        raise TapError("Preparation output must not traverse a symlink")
    if output.exists():
        if not output.is_dir():
            raise TapError("Preparation output is not a directory")
        existing = {}
        for path in output.rglob("*"):
            if path.is_symlink() or (not path.is_dir() and not path.is_file()):
                raise TapError("Unexpected preparation output entry")
            if path.is_file():
                existing[path.relative_to(output).as_posix()] = path.read_bytes()
        if existing:
            if existing != files:
                raise TapError("Preparation output contains different files; use a new output directory")
            return receipt | {"status": "prepared"}
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".filemint-tap-", dir=output.parent) as temporary:
        staging = Path(temporary) / "tap"
        staging.mkdir()
        for name, contents in files.items():
            path = staging / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(contents)
        if output.exists():
            output.rmdir()  # Only an empty, explicitly selected output is replaceable.
        staging.rename(output)
    return receipt | {"status": "prepared"}


def validate_brew_metadata(payload, version, sha256, token):
    try:
        info = json.loads(payload)
    except ValueError as error:
        raise TapError("Homebrew returned invalid Cask metadata") from error
    casks = info.get("casks") if isinstance(info, dict) else None
    if not isinstance(casks, list) or len(casks) != 1 or not isinstance(casks[0], dict):
        raise TapError("Homebrew did not resolve exactly one local Cask")
    item = casks[0]
    dependencies = {"arch": [{"type": "arm", "bits": 64}], "macos": {">=": ["13"]}}
    artifacts = item.get("artifacts")
    if (item.get("token") != "filemint" or item.get("full_token") != f"{token}/filemint"
            or item.get("tap") != token or item.get("version") != version
            or item.get("sha256") != sha256 or item.get("auto_updates") is not True
            or item.get("url") != f"{publication.PUBLIC}/releases/download/v{version}/FileMint-{version}.dmg"
            or item.get("depends_on") != dependencies
            or not isinstance(artifacts, list) or len(artifacts) != 1
            or not isinstance(artifacts[0], dict) or artifacts[0].get("app") != ["FileMint.app"]
            or set(artifacts[0]) - {"app", "target"}):
        raise TapError("Homebrew metadata differs from the reviewed release/platform/app contract")


def validate_brew(checkout):
    cask = Path(checkout) / "Casks/filemint.rb"
    # Only canonical bytes reach Homebrew's Ruby evaluator. Validation registers
    # one uniquely named metadata-only tap, never an app or an existing user tap.
    contents = regular_file(cask).read_text(encoding="utf-8")
    version, sha256 = parse_cask(contents)
    environment = os.environ | {"HOMEBREW_DEVELOPER": "1",
                                "HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ANALYTICS": "1"}
    # Do not unset explicit HOMEBREW_FORBID_* policy. Developer mode is local to
    # these commands; audit/livecheck use a named tap because Homebrew 6 rejects paths.
    token = f"filemint-validation/check-{uuid.uuid4().hex}"
    if token in run(["brew", "tap"], cwd=checkout, env=environment).splitlines():
        raise TapError("The unique validation tap already exists; retain it and retry")
    with tempfile.TemporaryDirectory(prefix="filemint-cask-validation-") as temporary:
        snapshot = Path(temporary) / "tap"
        (snapshot / "Casks").mkdir(parents=True)
        snapshot_cask = snapshot / "Casks/filemint.rb"
        snapshot_cask.write_text(contents, encoding="utf-8")
        git_environment = environment | {
            "GIT_AUTHOR_NAME": "FileMint Cask Validation", "GIT_COMMITTER_NAME": "FileMint Cask Validation",
            "GIT_AUTHOR_EMAIL": "validation@filemint.invalid", "GIT_COMMITTER_EMAIL": "validation@filemint.invalid",
        }
        for args in (["init", "--quiet", "--initial-branch=main"], ["add", "--", "Casks/filemint.rb"],
                     ["commit", "--quiet", "-m", "Validate reviewed FileMint Cask"]):
            run(["git", "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgsign=false", *args],
                cwd=snapshot, env=git_environment)
        registered = False
        try:
            run(["brew", "tap", "--custom-remote", token, str(snapshot)], cwd=snapshot, env=environment)
            registered = True
            named_cask = f"{token}/filemint"
            # Run serially: Homebrew commands may update their shared Ruby tooling.
            run(["brew", "style", str(snapshot_cask)], cwd=snapshot, env=environment)
            run(["brew", "readall", "--os=all", "--arch=all", token], cwd=snapshot, env=environment)
            payload = run(["brew", "info", "--json=v2", "--cask", named_cask], cwd=snapshot, env=environment)
            validate_brew_metadata(payload, version, sha256, token)
            run(["brew", "audit", "--cask", "--online", "--strict",
                 f"--except={','.join(LOCAL_AUDIT_EXCLUSIONS)}", named_cask], cwd=snapshot, env=environment)
            run(["brew", "livecheck", "--cask", named_cask], cwd=snapshot, env=environment)
        finally:
            try:
                # A failed registration can still leave a partially created tap.
                # The preflight and random token establish ownership of this name.
                if registered or token in run(["brew", "tap"], cwd=snapshot, env=environment).splitlines():
                    run(["brew", "untap", token], cwd=snapshot, env=environment)
                    if token in run(["brew", "tap"], cwd=snapshot, env=environment).splitlines():
                        raise TapError("Homebrew still lists the temporary validation tap")
            except (TapError, OSError, subprocess.TimeoutExpired) as error:
                raise TapError(f"Temporary Homebrew tap cleanup failed: {token}; remove only this tap before retrying ({error})") from error


def git(checkout, *args):
    return run(["git", "-c", "core.hooksPath=/dev/null", *args], cwd=checkout)


def check_layout(checkout):
    allowed = set(skeleton_files()) | {"Casks/filemint.rb"}
    entries = git(checkout, "ls-files", "--stage", "-z").split("\0")
    observed = set()
    for entry in entries:
        if not entry:
            continue
        metadata, separator, name = entry.partition("\t")
        if not separator or not re.fullmatch(r"100644 [0-9a-f]{40} 0", metadata) or name not in allowed:
            raise TapError("Tap contains an unexpected file, executable, symlink or submodule")
        regular_file(Path(checkout) / name)
        observed.add(name)
    if observed != allowed or git(checkout, "status", "--porcelain", "--untracked-files=all"):
        raise TapError("Tap layout is incomplete or the temporary checkout is not clean")
    return regular_file(Path(checkout) / "Casks/filemint.rb").read_text(encoding="utf-8")


def tap_head(api):
    record = api.api("git/ref/heads/main")
    obj = record.get("object", {}) if isinstance(record, dict) else {}
    if obj.get("type") != "commit" or not re.fullmatch(r"[0-9a-f]{40}", str(obj.get("sha", ""))):
        raise TapError("Tap main does not resolve to a commit")
    return obj["sha"]


def readback(api, commit, expected):
    if tap_head(api) != commit:
        raise TapError("Tap main changed concurrently or push readback is unresolved; retry without force pushing")
    record = api.api(f"contents/Casks/filemint.rb?ref={commit}")
    if (not isinstance(record, dict) or record.get("type") != "file"
            or record.get("encoding") != "base64" or record.get("path") != "Casks/filemint.rb"):
        raise TapError("Cannot verify the published Cask")
    try:
        contents = base64.b64decode("".join(record.get("content", "").split()), validate=True)
    except (ValueError, TypeError) as error:
        raise TapError("Invalid Cask readback encoding") from error
    if contents != expected.encode():
        raise TapError("Published Cask bytes differ; retain the tap and investigate")


def verify_tap_ci(api, commit, *, clock=time.monotonic, sleep=time.sleep):
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise TapError("Invalid tap CI commit")
    timeout, interval = publication.actions_wait_settings()
    deadline, run_id, previous = clock() + timeout, None, None
    while True:
        if tap_head(api) != commit:
            raise TapError("Tap main changed during CI verification; retry without force pushing")
        if run_id is None:
            query = urlencode({"event": "push", "branch": "main", "head_sha": commit, "per_page": 100})
            runs = api.api(f"actions/workflows/validate.yml/runs?{query}")["workflow_runs"]
            matches = [run for run in runs if publication.matching_run(run, "validate.yml", commit, "main")]
            run = max(matches, key=lambda item: positive(item.get("id"), "tap CI run ID")) if matches else None
            if run is not None:
                run_id = positive(run.get("id"), "tap CI run ID")
        else:
            run = api.api(f"actions/runs/{run_id}")
        if run is not None:
            if (run.get("id") != run_id
                    or not publication.matching_run(run, "validate.yml", commit, "main")):
                raise TapError("Saved tap CI run no longer matches the synchronized commit")
            status = (run_id, run.get("status"), run.get("conclusion"), run.get("run_attempt"))
            if status != previous:
                print(f"Homebrew CI: run {run_id}, {status[1]}, {status[2] or 'pending'}", file=sys.stderr, flush=True)
                previous = status
            if run.get("status") == "completed":
                if run.get("conclusion") != "success":
                    raise TapError(f"Homebrew CI did not succeed ({run.get('conclusion')}); "
                                   f"rerun run {run_id} in GitHub, then retry the same manifest")
                verified = verified_run(api, run_id, run.get("run_attempt"), "validate.yml", commit, "main")
                if tap_head(api) != commit:
                    raise TapError("Tap main changed after CI verification; retain it and retry")
                return verified
        remaining = deadline - clock()
        if remaining <= 0:
            raise TapError(f"Timed out waiting for Homebrew CI for {commit}; retry the same manifest")
        sleep(min(interval, remaining))


def verified_sync_receipt(api, receipt, commit, expected, status):
    readback(api, commit, expected)
    tap_ci = verify_tap_ci(api, commit)
    readback(api, commit, expected)
    return receipt | {"status": status, "tap_commit": commit, "tap_ci": tap_ci}


def publish(manifest_path, gh=None):
    receipt = validate_release(manifest_path, gh=gh, require_complete=True)
    manifest = receipt["manifest"]
    expected = render_cask(manifest["version"], manifest["dmgSHA256"])
    api = TapGitHub()
    repository = api.api("")
    if (not isinstance(repository, dict) or repository.get("full_name") != TAP_REPO
            or repository.get("default_branch") != "main" or repository.get("private") is not False
            or repository.get("archived") is not False or repository.get("disabled") is not False):
        raise TapError("The existing public FileMint tap on main is required; this tool never creates it")
    original = tap_head(api)
    with tempfile.TemporaryDirectory(prefix="filemint-homebrew-") as temporary:
        checkout = Path(temporary) / "tap"
        git(ROOT, "-c", "credential.helper=", "-c", "credential.helper=!gh auth git-credential",
            "clone", "--branch", "main", "--single-branch", "--no-tags", TAP_URL, str(checkout))
        if git(checkout, "remote", "get-url", "origin") != TAP_URL or git(checkout, "rev-parse", "HEAD") != original:
            raise TapError("Tap source changed during clone")
        existing = check_layout(checkout)
        version, sha256 = parse_cask(existing)
        if version_key(version) > version_key(manifest["version"]):
            raise TapError("Refusing to downgrade the tap")
        if version == manifest["version"] and sha256 != manifest["dmgSHA256"]:
            raise TapError("Refusing a same-version Cask byte/hash change")
        cask = checkout / "Casks/filemint.rb"
        cask.write_text(expected, encoding="utf-8")
        validate_brew(checkout)
        refreshed = validate_release(manifest_path, gh=gh, require_complete=True)
        if refreshed != receipt:
            raise TapError("Release evidence changed while validating the Cask")
        if tap_head(api) != original or cask.read_text(encoding="utf-8") != expected:
            raise TapError("Tap or prepared Cask changed during validation")
        if existing == expected:
            return verified_sync_receipt(api, receipt, original, expected, "unchanged")
        git(checkout, "add", "--", "Casks/filemint.rb")
        if git(checkout, "diff", "--cached", "--name-only") != "Casks/filemint.rb":
            raise TapError("Unexpected staged tap changes")
        git(checkout, "commit", "-m", f"chore: update filemint to {manifest['version']}")
        commit = git(checkout, "rev-parse", "HEAD")
        try:
            git(checkout, "-c", "credential.helper=", "-c", "credential.helper=!gh auth git-credential",
                "push", "origin", "HEAD:refs/heads/main")
        except (TapError, OSError, subprocess.TimeoutExpired):
            # A connection can fail after the remote accepted the commit. Reconcile
            # using GET before calling it a failure or attempting another write.
            try:
                readback(api, commit, expected)
            except (TapError, OSError, subprocess.TimeoutExpired) as read_error:
                raise TapError("Tap push outcome is unresolved or rejected; retain the remote and retry the same manifest without force pushing") from read_error
        return verified_sync_receipt(api, receipt, commit, expected, "published")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest="mode", required=True)
    preparation = modes.add_parser("prepare", help="validate a public release and write a local reviewable tap")
    preparation.add_argument("--manifest", required=True, type=Path)
    preparation.add_argument("--output-dir", required=True, type=Path)
    synchronization = modes.add_parser("publish", help="synchronize an existing tap after application and website publication")
    synchronization.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = (prepare(args.manifest, args.output_dir) if args.mode == "prepare" else publish(args.manifest))
    except (TapError, publication.PublicationError, OSError, subprocess.TimeoutExpired,
            KeyError, TypeError, ValueError) as error:
        print(f"Homebrew {args.mode} failed: {error}", file=sys.stderr)
        if args.mode == "publish":
            print("Published app releases and their assets are unchanged; retry publish with the same manifest.", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
