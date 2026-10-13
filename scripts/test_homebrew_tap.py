#!/usr/bin/env python3
"""Offline Homebrew evidence and transaction regressions; never install an app."""
import base64
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "scripts"))
spec = importlib.util.spec_from_file_location("homebrew_tap", ROOT / "scripts/homebrew_tap.py")
tap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tap)
EVIDENCE_ERROR = (tap.TapError, tap.publication.PublicationError)
VERSION, TAG, COMMIT = "9.10.0", "v9.10.0", "a" * 40
PUBLIC = "https://github.com/FileMintApp/FileMint"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def workflow_run(run_id, workflow, *, request=None, branch="main", commit=COMMIT):
    return {"id": run_id, "path": f".github/workflows/{workflow}", "head_sha": commit,
            "head_branch": branch, "event": "workflow_dispatch" if request else "push",
            "display_title": request or "Source CI", "status": "completed",
            "conclusion": "success", "run_attempt": 1}


class ReleaseFixture(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="filemint-homebrew-tests-")
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name).resolve()
        self.manifest_path = self.work / f"FileMint-{VERSION}.release.json"
        self.manifest = {"version": VERSION, "build": "99", "tag": TAG, "commit": COMMIT,
                         "dmgSHA256": digest(b"fixture DMG"), "zipSHA256": digest(b"fixture ZIP"),
                         "certificateSHA256": digest(b"fixture certificate"), "appcastSHA256": digest(b"fixture DMG feed"),
                         "zipAppcastSHA256": digest(b"fixture ZIP feed"),
                         "notarySubmissionID": "11111111-2222-4333-8444-555555555555"}
        certificate = self.work / "certificate.cer"
        certificate.write_bytes(b"fixture certificate")
        certificate_patch = patch.object(tap, "CERTIFICATE", certificate)
        certificate_patch.start()
        self.addCleanup(certificate_patch.stop)
        self.files = {f"FileMint-{VERSION}.dmg": b"fixture DMG",
                      f"FileMint-{VERSION}.zip": b"fixture ZIP",
                      f"FileMint-{VERSION}.appcast.xml": b"fixture DMG feed",
                      f"FileMint-{VERSION}.appcast-zip.xml": b"fixture ZIP feed"}
        for name, data in self.files.items():
            (self.work / name).write_bytes(data)
        for extension in ("dmg", "zip"):
            name = f"FileMint-{VERSION}.{extension}"
            (self.work / (name + ".sha256")).write_text(f"{digest(self.files[name])}  {name}\n")
        self.write_manifest()

    def write_manifest(self):
        self.manifest_path.write_text(json.dumps(self.manifest))


class ManifestAndCaskTests(ReleaseFixture):
    def test_ten_string_field_manifest_round_trip(self):
        self.assertEqual(tap.load_manifest(self.manifest_path), self.manifest)
        self.assertEqual(len(self.manifest), 10)

    def test_manifest_requires_exact_keys_and_string_types(self):
        original = copy.deepcopy(self.manifest)
        for field in original:
            for operation in ("missing", "number", "boolean", "null"):
                with self.subTest(field=field, operation=operation):
                    self.manifest = copy.deepcopy(original)
                    if operation == "missing":
                        del self.manifest[field]
                    else:
                        self.manifest[field] = {"number": 99, "boolean": True, "null": None}[operation]
                    self.write_manifest()
                    with self.assertRaises(EVIDENCE_ERROR):
                        tap.load_manifest(self.manifest_path)
        self.manifest = original | {"unrecognized": "field"}
        self.write_manifest()
        with self.assertRaises(EVIDENCE_ERROR):
            tap.load_manifest(self.manifest_path)

    def test_duplicate_json_keys_and_nonobject_manifests_fail(self):
        serialized = json.dumps(self.manifest)
        for text in (serialized[:-1] + ', "version": "9.10.0"}', "[]", "null", "{"):
            with self.subTest(text=text):
                self.manifest_path.write_text(text)
                with self.assertRaises(EVIDENCE_ERROR):
                    tap.load_manifest(self.manifest_path)

    def test_manifest_rejects_invalid_identity_and_path_or_ruby_injection(self):
        mutations = {"version": ["../9.10.0", '9.10.0";system("true")', "9.10.0\n", "9.10.0-beta"],
                     "tag": ["v9.10.1", "../v9.10.0"], "build": ["0", "-1", "99\n"],
                     "commit": ["a" * 39, "A" * 40],
                     "notarySubmissionID": ["", "not-a-uuid"]}
        for field in ("dmgSHA256", "zipSHA256", "certificateSHA256", "appcastSHA256", "zipAppcastSHA256"):
            mutations[field] = ["f" * 63, "G" * 64, "1" * 64 + "\n"]
        original = copy.deepcopy(self.manifest)
        for field, values in mutations.items():
            for value in values:
                with self.subTest(field=field, value=value):
                    self.manifest = original | {field: value}
                    self.write_manifest()
                    with self.assertRaises(EVIDENCE_ERROR):
                        tap.load_manifest(self.manifest_path)

    def test_cask_round_trip_preserves_release_and_platform_contract(self):
        cask = tap.render_cask(VERSION, self.manifest["dmgSHA256"])
        self.assertEqual(tap.parse_cask(cask), (VERSION, self.manifest["dmgSHA256"]))
        self.assertIn('cask "filemint"', cask)
        self.assertIn(f'version "{VERSION}"', cask)
        self.assertIn('arch: :arm64', cask)
        self.assertIn('macos:', cask)
        self.assertIn(':ventura', cask)
        self.assertIn('auto_updates true', cask)
        self.assertIn('app "FileMint.app"', cask)
        for forbidden in ("\n  zap ", "\n  uninstall ", "system_command", "\n  preflight", "\n  postflight", "quit:", "signal:"):
            self.assertNotIn(forbidden, cask)

    def test_cask_rejects_executable_ruby_and_unrecognized_layout(self):
        cask = tap.render_cask(VERSION, self.manifest["dmgSHA256"])
        mutations = [cask + '\nsystem("true")\n', cask.replace("\nend", '\n  zap trash: "~/Library"\nend'),
                     cask.replace('app "FileMint.app"', 'app "Other.app"'),
                     cask.replace('auto_updates true', 'auto_updates false'),
                     cask.replace('arch: :arm64', 'arch: :intel'),
                     cask.replace(':ventura', ':monterey'),
                     cask.replace(self.manifest["dmgSHA256"], ":no_check"),
                     cask.replace('version "9.10.0"', 'version "#{system(\'true\')}"')]
        for text in mutations:
            with self.subTest(cask=text):
                with self.assertRaises(EVIDENCE_ERROR):
                    tap.parse_cask(text)

    def test_versions_compare_numerically(self):
        self.assertGreater(tap.version_key("0.10.0"), tap.version_key("0.9.99"))
        self.assertGreater(tap.version_key("10.0.0"), tap.version_key("9.99.99"))
        self.assertEqual(tap.version_key("0.7.0"), (0, 7, 0))


class LocalArtifactTests(ReleaseFixture):
    def setUp(self):
        super().setUp()
        self.commands = []
        self.local_tag = COMMIT

    def command(self, args, **kwargs):
        self.commands.append((args, kwargs))
        if args[:2] == ["git", "rev-parse"]:
            return self.local_tag
        if any(str(arg).endswith("verify_release_pair.sh") for arg in args):
            return ""
        raise AssertionError(f"Unexpected local artifact command: {args}")

    def validate(self):
        with patch.object(tap, "run", side_effect=self.command):
            return tap.validate_local(self.manifest_path, self.manifest)

    def test_valid_files_invoke_existing_verifier_with_bound_version_build(self):
        self.validate()
        verifier = [(args, kwargs) for args, kwargs in self.commands
                    if any(str(arg).endswith("verify_release_pair.sh") for arg in args)]
        self.assertEqual(len(verifier), 1)
        args, kwargs = verifier[0]
        self.assertIn(str(self.work / f"FileMint-{VERSION}.dmg"), list(map(str, args)))
        self.assertIn(VERSION, args)
        self.assertIn("99", args)
        self.assertTrue(any(f"refs/tags/{TAG}" in str(arg)
                            for args, _ in self.commands for arg in args))

    def test_each_local_archive_and_feed_hash_is_verified_before_native_check(self):
        for filename in self.files:
            with self.subTest(filename=filename):
                path = self.work / filename
                before = path.read_bytes()
                path.write_bytes(before + b" changed")
                self.commands.clear()
                with self.assertRaises(EVIDENCE_ERROR):
                    self.validate()
                self.assertFalse(any(any(str(arg).endswith("verify_release_pair.sh") for arg in args)
                                     for args, _ in self.commands))
                path.write_bytes(before)

    def test_both_portable_checksums_bind_digest_and_exact_filename(self):
        for extension in ("dmg", "zip"):
            path = self.work / f"FileMint-{VERSION}.{extension}.sha256"
            before = path.read_text()
            for text in ("0" * 64 + before[64:], before.replace(f"FileMint-{VERSION}", "Other"),
                         before + before, "", before.replace("  ", " *../")):
                with self.subTest(extension=extension, text=text):
                    path.write_text(text)
                    with self.assertRaises(EVIDENCE_ERROR):
                        self.validate()
            path.write_text(before)

    def test_missing_and_symlinked_artifacts_fail(self):
        path = self.work / f"FileMint-{VERSION}.dmg"
        before = path.read_bytes()
        path.unlink()
        with self.assertRaises(EVIDENCE_ERROR):
            self.validate()
        other = self.work / "other.dmg"
        other.write_bytes(before)
        path.symlink_to(other)
        with self.assertRaises(EVIDENCE_ERROR):
            self.validate()

    def test_local_tag_is_required_even_when_remote_evidence_is_valid(self):
        self.local_tag = "b" * 40
        with self.assertRaises(EVIDENCE_ERROR):
            self.validate()

    def test_native_verification_failure_propagates(self):
        with patch.object(tap, "run", side_effect=tap.TapError("fixture verifier failure")):
            with self.assertRaises(EVIDENCE_ERROR):
                tap.validate_local(self.manifest_path, self.manifest)

    def test_certificate_hash_and_notarization_policy_cannot_be_bypassed(self):
        self.manifest["certificateSHA256"] = "0" * 64
        with self.assertRaises(EVIDENCE_ERROR):
            self.validate()
        self.manifest["certificateSHA256"] = digest(b"fixture certificate")
        with patch.dict(os.environ, {"FILEMINT_ALLOW_PENDING_053": "1", "APPLE_TEAM_ID": "wrong-team"}):
            self.validate()
        verifier = next(kwargs for args, kwargs in self.commands
                        if any(str(arg).endswith("verify_release_pair.sh") for arg in args))
        self.assertNotIn("FILEMINT_ALLOW_PENDING_053", verifier["env"])
        self.assertEqual(verifier["env"]["APPLE_TEAM_ID"], "8S66M2ZLD5")


class FakeGitHub:
    """Only known GET endpoints exist; an accidental dispatch fails the test."""
    def __init__(self, release, runs):
        self.release = release
        self.latest = copy.deepcopy(release)
        self.runs = runs
        self.tag_commit = COMMIT
        self.events = []

    def api(self, endpoint, method="GET", body=None, missing_ok=False):
        self.events.append((method, endpoint, body))
        if method != "GET" or body is not None:
            raise AssertionError(f"Unexpected GitHub mutation: {method} {endpoint}")
        path = urlsplit(endpoint).path
        if ((path.startswith("releases/") and path.rsplit("/", 1)[-1].isdigit())
                or path == f"releases/tags/{TAG}"):
            return copy.deepcopy(self.release)
        if path == "releases/latest":
            return copy.deepcopy(self.latest)
        if path == f"git/ref/tags/{TAG}":
            return {"object": {"type": "commit", "sha": self.tag_commit}}
        if path.startswith("actions/runs/"):
            return copy.deepcopy(self.runs[int(path.split("/")[2])])
        raise AssertionError(f"Unexpected API request: {endpoint}")


class EvidenceFixture(ReleaseFixture):
    def setUp(self):
        super().setUp()
        names = [f"FileMint-{VERSION}.dmg", f"FileMint-{VERSION}.dmg.sha256", "appcast.xml",
                 f"FileMint-{VERSION}.zip", f"FileMint-{VERSION}.zip.sha256", "appcast-zip.xml"]
        release = {"id": 7, "tag_name": TAG, "draft": False, "prerelease": False,
                   "html_url": f"{PUBLIC}/releases/tag/{TAG}",
                   "assets": [{"id": 100 + index, "name": name, "size": 20, "state": "uploaded",
                               "browser_download_url": f"{PUBLIC}/releases/download/{TAG}/{name}"}
                              for index, name in enumerate(names)]}
        for asset in release["assets"]:
            filename = (f"FileMint-{VERSION}.{asset['name']}" if asset["name"].startswith("appcast")
                        else asset["name"])
            asset["size"] = (self.work / filename).stat().st_size
        self.state = {"schemaVersion": 1, "candidate": copy.deepcopy(self.manifest), "phase": "complete",
                      "release_id": 7, "ci_run_id": 1, "ci_verified_attempt": 1, "website_required": False,
                      "assets": sorted([{"name": asset["name"], "id": asset["id"], "size": asset["size"]}
                                        for asset in release["assets"]], key=lambda value: value["name"]),
                      "requests": {"candidate": self.request("candidate", 2)}}
        runs = {1: workflow_run(1, "ci.yml"),
                2: workflow_run(2, "release.yml", branch=TAG,
                                request=self.state["requests"]["candidate"]["title"])}
        self.gh = FakeGitHub(release, runs)
        self.journal_path = self.manifest_path.with_name(f"FileMint-{VERSION}.publication.json")
        self.write_journal()

    @staticmethod
    def request(kind, run_id, *, branch=TAG, commit=COMMIT):
        request_id = str(run_id) * 32
        return {"request_id": request_id, "ref": branch, "commit": commit,
                "title": f"FileMint {kind} {request_id}", "run_id": run_id, "verified_attempt": 1}

    def write_journal(self):
        self.journal_path.write_text(json.dumps(self.state))

    def validate(self, **kwargs):
        with patch.object(tap, "validate_local"):
            return tap.validate_release(self.manifest_path, self.gh, **kwargs)


class ReleaseEvidenceTests(EvidenceFixture):
    def test_exact_public_release_and_workflow_attempts_produce_receipt(self):
        receipt = self.validate(require_complete=True)
        self.assertEqual(receipt["manifest"], self.manifest)
        self.assertEqual(receipt["release_id"], 7)
        self.assertEqual(receipt["assets"], self.state["assets"])
        self.assertEqual(receipt["runs"]["ci"], {"id": 1, "attempt": 1})
        self.assertEqual(receipt["runs"]["candidate"], {"id": 2, "attempt": 1})
        self.assertTrue(all(method == "GET" for method, _, _ in self.gh.events))

    def test_draft_prerelease_changed_ids_or_wrong_latest_are_rejected(self):
        original = copy.deepcopy(self.gh.release)
        mutations = [("draft", True), ("prerelease", True), ("id", 8), ("tag_name", "v9.9.9"),
                     ("html_url", "https://example.invalid/release")]
        for field, value in mutations:
            with self.subTest(field=field):
                self.gh.release = original | {field: value}
                with self.assertRaises(EVIDENCE_ERROR):
                    self.validate()
        self.gh.release = original
        for field, value in mutations:
            with self.subTest(latest_field=field):
                self.gh.latest = original | {field: value}
                with self.assertRaises(EVIDENCE_ERROR):
                    self.validate()

    def test_every_asset_identity_and_final_url_is_bound(self):
        for asset_index in range(6):
            for field, value in (("id", 999), ("size", 21), ("state", "new"),
                                 ("browser_download_url", "https://example.invalid/download")):
                for target in ("release", "latest"):
                    with self.subTest(asset=asset_index, field=field, target=target):
                        old = copy.deepcopy(getattr(self.gh, target))
                        getattr(self.gh, target)["assets"][asset_index][field] = value
                        with self.assertRaises(EVIDENCE_ERROR):
                            self.validate()
                        setattr(self.gh, target, old)

    def test_missing_duplicate_or_extra_release_assets_fail(self):
        original = copy.deepcopy(self.gh.release["assets"])
        for assets in (original[:-1], original + [original[0]], original + [original[0] | {"name": "extra.txt"}]):
            with self.subTest(assets=assets):
                self.gh.release["assets"] = assets
                with self.assertRaises(EVIDENCE_ERROR):
                    self.validate()

    def test_journal_asset_snapshot_is_strict_and_server_digest_binds_local_bytes(self):
        original = copy.deepcopy(self.state["assets"])
        for field, value in (("id", True), ("id", "100"), ("size", -1), ("size", True),
                             ("name", "unexpected.dmg"), ("extra", "ignored?")):
            with self.subTest(field=field, value=value):
                self.state["assets"] = copy.deepcopy(original)
                self.state["assets"][0][field] = value
                self.write_journal()
                with self.assertRaises(EVIDENCE_ERROR):
                    self.validate()
        self.state["assets"] = original
        self.write_journal()
        self.gh.release["assets"][0]["digest"] = "sha256:" + "0" * 64
        with self.assertRaises(EVIDENCE_ERROR):
            self.validate()

    def test_readonly_client_refuses_dispatch_and_patch_before_transport(self):
        with patch.object(tap.publication.GitHub, "api") as transport:
            for method, body in (("POST", None), ("PATCH", {}), ("GET", {"unexpected": True})):
                with self.subTest(method=method, body=body):
                    with self.assertRaises(EVIDENCE_ERROR):
                        tap.ReadOnlyGitHub().api("actions/workflows/release.yml/dispatches", method, body)
            transport.assert_not_called()

    def test_remote_tag_must_still_resolve_to_manifest_commit(self):
        self.gh.tag_commit = "b" * 40
        with self.assertRaises(EVIDENCE_ERROR):
            self.validate()

    def test_exact_successful_ci_and_candidate_runs_are_required(self):
        mutations = {"status": ["queued", "in_progress"],
                     "conclusion": ["failure", "cancelled", "skipped", "timed_out", None],
                     "head_sha": ["b" * 40], "head_branch": ["unrelated"],
                     "path": [".github/workflows/unrelated.yml"], "id": [999], "run_attempt": [2]}
        for run_id in (1, 2):
            original = copy.deepcopy(self.gh.runs[run_id])
            for field, values in mutations.items():
                for value in values:
                    with self.subTest(run=run_id, field=field, value=value):
                        self.gh.runs[run_id] = original | {field: value}
                        with self.assertRaises(EVIDENCE_ERROR):
                            self.validate()
            self.gh.runs[run_id] = original | {"event": "pull_request"}
            with self.assertRaises(EVIDENCE_ERROR):
                self.validate()
            self.gh.runs[run_id] = original
        self.gh.runs[2]["display_title"] = "FileMint candidate unrelated"
        with self.assertRaises(EVIDENCE_ERROR):
            self.validate()

    def test_missing_or_changed_journal_binding_is_not_historical_evidence(self):
        original = copy.deepcopy(self.state)
        mutations = [("ci_run_id", None), ("ci_verified_attempt", None), ("phase", "verifying"),
                     ("candidate", self.manifest | {"build": "98"}), ("release_id", 8)]
        for field, value in mutations:
            with self.subTest(field=field):
                self.state = original | {field: value}
                self.write_journal()
                with self.assertRaises(EVIDENCE_ERROR):
                    self.validate(require_complete=True)
        for field in ("request_id", "run_id", "verified_attempt", "ref", "commit", "title"):
            with self.subTest(candidate_field=field):
                self.state = copy.deepcopy(original)
                del self.state["requests"]["candidate"][field]
                self.write_journal()
                with self.assertRaises(EVIDENCE_ERROR):
                    self.validate()

    def test_required_site_and_deployment_must_finish_before_publish(self):
        self.state["website_required"] = True
        self.write_journal()
        with self.assertRaises(EVIDENCE_ERROR):
            self.validate(require_complete=True)
        for kind, run_id, workflow, branch in (("site", 3, "build-pages.yml", TAG),
                                               ("deploy", 4, "deploy-pages.yml", "main")):
            self.state["requests"][kind] = self.request(kind, run_id, branch=branch)
            self.gh.runs[run_id] = workflow_run(run_id, workflow, branch=branch,
                                               request=self.state["requests"][kind]["title"])
        self.write_journal()
        receipt = self.validate(require_complete=True)
        self.assertEqual(receipt["runs"]["deploy"], {"id": 4, "attempt": 1})
        for run_id in (3, 4):
            self.gh.runs[run_id]["conclusion"] = "failure"
            with self.assertRaises(EVIDENCE_ERROR):
                self.validate(require_complete=True)
            self.gh.runs[run_id]["conclusion"] = "success"

    def test_release_evidence_failure_never_opens_tap_for_mutation(self):
        self.gh.runs[2]["conclusion"] = "failure"
        with patch.object(tap, "validate_local"), patch.object(tap, "TapGitHub") as remote, patch.object(tap, "run") as run:
            with self.assertRaises(EVIDENCE_ERROR):
                tap.publish(self.manifest_path, self.gh)
            remote.assert_not_called()
            run.assert_not_called()


class PrepareTests(EvidenceFixture):
    def test_prepare_writes_canonical_cask_and_evidence_without_dispatch_or_push(self):
        destination = self.work / "prepared"
        with patch.object(tap, "validate_local"), patch.object(tap, "run") as run:
            receipt = tap.prepare(self.manifest_path, destination, self.gh)
        self.assertEqual(receipt["status"], "prepared")
        casks = list(destination.rglob("filemint.rb"))
        self.assertEqual(len(casks), 1)
        self.assertEqual(casks[0].read_text(), tap.render_cask(VERSION, self.manifest["dmgSHA256"]))
        self.assertEqual(receipt["caskSHA256"], digest(casks[0].read_bytes()))
        persisted = [json.loads(path.read_text()) for path in destination.rglob("*.json")]
        self.assertTrue(any(item.get("manifest") == self.manifest for item in persisted))
        for call in run.call_args_list:
            args = call.args[0]
            self.assertNotIn("push", args)
            self.assertFalse(args[:2] == ["gh", "workflow"])
        self.assertTrue(all(method == "GET" for method, _, _ in self.gh.events))

    def test_invalid_release_never_creates_preparation_output(self):
        destination = self.work / "prepared"
        self.gh.release["draft"] = True
        with patch.object(tap, "validate_local"):
            with self.assertRaises(EVIDENCE_ERROR):
                tap.prepare(self.manifest_path, destination, self.gh)
        self.assertFalse(destination.exists())

    def test_preparation_retry_is_identical_and_preserves_conflicting_output(self):
        destination = self.work / "prepared"
        with patch.object(tap, "validate_local"):
            first = tap.prepare(self.manifest_path, destination, self.gh)
            self.assertEqual(tap.prepare(self.manifest_path, destination, self.gh), first)
            marker = destination / "review-notes.txt"
            marker.write_text("Keep reviewer notes\n")
            with self.assertRaises(EVIDENCE_ERROR):
                tap.prepare(self.manifest_path, destination, self.gh)
        self.assertEqual(marker.read_text(), "Keep reviewer notes\n")

    def test_preparation_refuses_symlink_output_without_touching_target(self):
        destination = self.work / "prepared"
        real = self.work / "unrelated"
        real.mkdir()
        destination.symlink_to(real, target_is_directory=True)
        with patch.object(tap, "validate_local"):
            with self.assertRaises(EVIDENCE_ERROR):
                tap.prepare(self.manifest_path, destination, self.gh)
        self.assertEqual(list(real.iterdir()), [])


class BrewContractTests(ReleaseFixture):
    def setUp(self):
        super().setUp()
        self.checkout = self.work / "tap"
        cask = self.checkout / "Casks/filemint.rb"
        cask.parent.mkdir(parents=True)
        cask.write_text(tap.render_cask(VERSION, self.manifest["dmgSHA256"]))
        self.info = {"casks": [{"token": "filemint", "version": VERSION,
                                "sha256": self.manifest["dmgSHA256"], "auto_updates": True,
                                "url": f"{PUBLIC}/releases/download/{TAG}/FileMint-{VERSION}.dmg",
                                "depends_on": {"arch": [{"type": "arm", "bits": 64}],
                                               "macos": {">=": ["13"]}},
                                "artifacts": [{"app": ["FileMint.app"]}]}]}
        self.commands = []
        self.registered = {"fixture/existing"}
        self.validation_tap = None
        self.fail_on = None
        self.partial_tap_failure = False
        self.untap_failure = False

    def command(self, args, **kwargs):
        args = list(map(str, args))
        self.commands.append((args, kwargs))
        if args[0] == "git":
            self.assertNotIn("push", args)
            environment = dict(kwargs.get("env") or os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1",
                               GIT_TERMINAL_PROMPT="0")
            result = subprocess.run(args, cwd=kwargs["cwd"], env=environment,
                                    capture_output=True, text=True)
            if result.returncode:
                raise tap.TapError(result.stderr)
            return result.stdout.strip()
        if args == ["brew", "tap"]:
            return "\n".join(sorted(self.registered))
        if args[:3] == ["brew", "tap", "--custom-remote"]:
            self.validation_tap = args[3]
            self.assertNotIn(self.validation_tap, self.registered)
            self.assertRegex(self.validation_tap, r"^filemint-validation/check-[0-9a-f]{32}$")
            snapshot = Path(args[4])
            self.assertEqual((snapshot / "Casks/filemint.rb").read_text(),
                             tap.render_cask(VERSION, self.manifest["dmgSHA256"]))
            self.registered.add(self.validation_tap)
            if self.partial_tap_failure:
                raise tap.TapError("Fixture tap registered but response lost")
            return ""
        if args[:2] == ["brew", "untap"]:
            self.assertEqual(args[2], self.validation_tap)
            if self.untap_failure:
                raise tap.TapError("Fixture cleanup failed")
            self.registered.remove(args[2])
            return ""
        if args[:2] == ["brew", self.fail_on]:
            raise tap.TapError(f"Fixture {self.fail_on} failed")
        if args[:2] == ["brew", "info"]:
            self.assertEqual(args[-1], f"{self.validation_tap}/filemint")
            info = copy.deepcopy(self.info)
            for item in info.get("casks", []):
                item.setdefault("tap", self.validation_tap)
                item.setdefault("full_token", f"{self.validation_tap}/filemint")
            return json.dumps(info)
        if args[:2] in (["brew", "style"], ["brew", "readall"], ["brew", "audit"], ["brew", "livecheck"]):
            return ""
        raise AssertionError(f"Unexpected Homebrew operation: {args}")

    def validate(self):
        with patch.object(tap, "run", side_effect=self.command):
            tap.validate_brew(self.checkout)

    def test_brew_checks_metadata_using_local_cask_and_preserves_user_policy(self):
        with patch.dict(os.environ, {"HOMEBREW_FORBID_CASKS": "1", "HOMEBREW_NO_INSTALL_FROM_API": ""}):
            self.validate()
        brew_commands = [(args, kwargs) for args, kwargs in self.commands if args[0] == "brew"]
        stages = [args[1] for args, _ in brew_commands if args[1] not in ("tap", "untap")]
        self.assertEqual(stages, ["style", "readall", "info", "audit", "livecheck"])
        self.assertEqual(self.registered, {"fixture/existing"})
        for args, kwargs in brew_commands:
            for key in ("HOMEBREW_NO_AUTO_UPDATE", "HOMEBREW_NO_ANALYTICS", "HOMEBREW_DEVELOPER",
                        "HOMEBREW_FORBID_CASKS"):
                self.assertEqual(kwargs["env"][key], "1")
            self.assertEqual(kwargs["env"]["HOMEBREW_NO_INSTALL_FROM_API"], "")
        self.assertFalse(any(args[1] in ("install", "upgrade", "uninstall", "reinstall")
                             for args, _ in brew_commands))
        readall = next(args for args, _ in brew_commands if args[1] == "readall")
        self.assertIn("--os=all", readall)
        self.assertIn("--arch=all", readall)
        audit = next(args for args, _ in brew_commands if args[1] == "audit")
        self.assertIn("--online", audit)
        self.assertIn("--strict", audit)
        # Local artifact verification already checked these. Homebrew's online
        # audit must not silently download public release archives on the owner Mac.
        self.assertEqual([arg for arg in audit if arg.startswith("--except=")],
                         ["--except=download,signing,rosetta,min_os,missing_verified,unnecessary_verified"])

    def test_unexpected_resolved_metadata_stops_before_online_audit(self):
        original = copy.deepcopy(self.info["casks"][0])
        mutations = {"token": "other", "version": "9.9.9", "sha256": "0" * 64,
                     "auto_updates": False, "url": "https://example.invalid/app.dmg",
                     "tap": "unexpected/remote", "full_token": "unexpected/remote/filemint",
                     "depends_on": {"arch": [{"type": "intel", "bits": 64}]},
                     "artifacts": [{"app": ["Other.app"]}]}
        for field, value in mutations.items():
            with self.subTest(field=field):
                self.info["casks"] = [original | {field: value}]
                self.commands.clear()
                with self.assertRaises(EVIDENCE_ERROR):
                    self.validate()
                self.assertFalse(any(args[:2] == ["brew", "audit"] for args, _ in self.commands))
                self.assertEqual(self.registered, {"fixture/existing"})

    def test_style_failure_and_unknown_ruby_never_reach_next_tool(self):
        self.fail_on = "style"
        with self.assertRaises(EVIDENCE_ERROR):
            self.validate()
        self.assertFalse(any(args[:2] == ["brew", "info"] for args, _ in self.commands))
        self.assertEqual(self.registered, {"fixture/existing"})
        cask = self.checkout / "Casks/filemint.rb"
        cask.write_text(cask.read_text() + 'system("true")\n')
        with patch.object(tap, "run") as run:
            with self.assertRaises(EVIDENCE_ERROR):
                tap.validate_brew(self.checkout)
            run.assert_not_called()

    def test_failed_audit_cleans_only_the_temporary_metadata_tap(self):
        self.fail_on = "audit"
        with self.assertRaises(EVIDENCE_ERROR):
            self.validate()
        self.assertEqual(self.registered, {"fixture/existing"})
        self.assertFalse(any(args[:2] == ["brew", "livecheck"] for args, _ in self.commands))
        self.assertEqual([args for args, _ in self.commands if args[:2] == ["brew", "untap"]],
                         [["brew", "untap", self.validation_tap]])

    def test_partial_tap_registration_is_reconciled_and_cleaned(self):
        self.partial_tap_failure = True
        with self.assertRaises(EVIDENCE_ERROR):
            self.validate()
        self.assertEqual(self.registered, {"fixture/existing"})
        self.assertFalse(any(args[:2] == ["brew", "audit"] for args, _ in self.commands))

    def test_cleanup_failure_is_reported_as_failure_with_recovery_identity(self):
        self.untap_failure = True
        with self.assertRaises(EVIDENCE_ERROR) as raised:
            self.validate()
        self.assertIn(self.validation_tap, str(raised.exception))
        self.assertEqual(self.registered, {"fixture/existing", self.validation_tap})


class GitTransportTests(EvidenceFixture):
    """Exercise real commits, fast-forward rules and uncertain local transport."""
    def setUp(self):
        super().setUp()
        self.seed = self.work / "seed"
        self.seed.mkdir()
        self.remote = self.work / "tap.git"
        self.git_env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1",
                            GIT_TERMINAL_PROMPT="0", GIT_AUTHOR_NAME="Fixture",
                            GIT_AUTHOR_EMAIL="fixture@example.invalid", GIT_COMMITTER_NAME="Fixture",
                            GIT_COMMITTER_EMAIL="fixture@example.invalid")
        self.git("init", "--quiet", "--initial-branch=main", cwd=self.seed)
        self.git("init", "--quiet", "--bare", "--initial-branch=main", str(self.remote))
        self.git("remote", "add", "origin", str(self.remote), cwd=self.seed)
        self.seed_commit({"README.md": "Fixture tap\n", "README.en.md": "Fixture tap English\n",
                          ".github/workflows/validate.yml": "name: Fixture\n",
                          "Casks/filemint.rb": tap.render_cask("9.9.99", "c" * 64)})
        self.base = self.remote_head()
        self.commands = []
        self.push_mode = None
        self.api_wrong_content = False
        self.api_calls = []
        self.evidence = self.validate(require_complete=True)

    def git(self, *args, cwd=None):
        result = subprocess.run(["git", "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgsign=false", *args],
                                cwd=cwd or self.work, env=self.git_env, text=True, capture_output=True)
        if result.returncode:
            raise tap.TapError(result.stderr.strip())
        return result.stdout.strip()

    def seed_commit(self, changes):
        for filename, text in changes.items():
            path = self.seed / filename
            if text is None:
                path.unlink(missing_ok=True)
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text)
        self.git("add", "--all", cwd=self.seed)
        self.git("commit", "--quiet", "-m", "Fixture tap change", cwd=self.seed)
        self.git("push", "--quiet", "origin", "HEAD:refs/heads/main", cwd=self.seed)

    def remote_head(self):
        return self.git("--git-dir", str(self.remote), "rev-parse", "refs/heads/main")

    def remote_cask(self):
        return self.git("--git-dir", str(self.remote), "show", "refs/heads/main:Casks/filemint.rb") + "\n"

    def api(self, endpoint):
        self.api_calls.append(endpoint)
        path = urlsplit(endpoint).path
        if path in ("", "/", "repos/FileMintApp/homebrew-tap"):
            return {"full_name": "FileMintApp/homebrew-tap", "default_branch": "main",
                    "archived": False, "disabled": False, "private": False,
                    "clone_url": "https://github.com/FileMintApp/homebrew-tap.git"}
        if path in ("git/ref/heads/main", "git/refs/heads/main"):
            return {"object": {"type": "commit", "sha": self.remote_head()}}
        if path == "contents/Casks/filemint.rb":
            content = ("invalid readback\n" if self.api_wrong_content else self.remote_cask()).encode()
            return {"type": "file", "encoding": "base64", "content": base64.b64encode(content).decode(),
                    "path": "Casks/filemint.rb", "name": "filemint.rb", "size": len(content),
                    "sha": self.git("--git-dir", str(self.remote), "rev-parse", "refs/heads/main:Casks/filemint.rb")}
        raise AssertionError(f"Unexpected tap API request: {endpoint}")

    def command(self, args, *, cwd=ROOT, env=None):
        args = list(map(str, args))
        self.commands.append(args)
        if args[0] != "git":
            raise AssertionError(f"Unexpected command (no brew/gh/install/network allowed): {args}")
        if "clone" in args:
            fixture_args = [str(self.remote) if value == "https://github.com/FileMintApp/homebrew-tap.git" else value
                            for value in args[1:]]
            result = self.git(*fixture_args, cwd=cwd)
            self.git("remote", "set-url", "origin", "https://github.com/FileMintApp/homebrew-tap.git",
                     cwd=Path(args[-1]))
            return result
        if "push" in args:
            if self.push_mode == "concurrent":
                self.push_mode = None
                self.seed_commit({"README.md": "Concurrent maintainer change\n"})
            elif self.push_mode == "before":
                raise tap.TapError("Fixture transport failed before push")
        # Redirect only transport operations. The stored origin remains canonical.
        transport = any(value in args for value in ("push", "fetch", "ls-remote"))
        actual = args[1:]
        if transport:
            actual = ["-c", f"url.{self.remote}.insteadOf=https://github.com/FileMintApp/homebrew-tap.git", *actual]
        result = self.git(*actual, cwd=cwd)
        if "push" in args and self.push_mode == "after":
            self.push_mode = None
            raise tap.TapError("Fixture response lost after successful push")
        return result

    def publish(self, evidence=None):
        with patch.object(tap, "validate_release", side_effect=evidence or (lambda *a, **kw: copy.deepcopy(self.evidence))), \
                patch.object(tap, "TapGitHub", return_value=self), \
                patch.object(tap, "run", side_effect=self.command), \
                patch.object(tap, "validate_brew") as brew:
            result = tap.publish(self.manifest_path, self.gh)
        return result, brew

    def test_normal_fast_forward_only_changes_cask_and_verified_retry_is_noop(self):
        receipt, brew = self.publish()
        self.assertEqual(receipt["status"], "published")
        self.assertEqual(receipt["tap_commit"], self.remote_head())
        self.assertEqual(self.remote_cask(), tap.render_cask(VERSION, self.manifest["dmgSHA256"]))
        changed = self.git("--git-dir", str(self.remote), "diff", "--name-only", self.base, self.remote_head())
        self.assertEqual(changed, "Casks/filemint.rb")
        self.assertEqual(self.git("--git-dir", str(self.remote), "rev-parse", "refs/heads/main^"), self.base)
        brew.assert_called_once()
        self.assertTrue(any("contents/Casks/filemint.rb" in endpoint for endpoint in self.api_calls))
        self.commands.clear()
        head = self.remote_head()
        retry, _ = self.publish()
        self.assertEqual(retry["status"], "unchanged")
        self.assertEqual(self.remote_head(), head)
        self.assertFalse(any("push" in args for args in self.commands))

    def test_same_version_hash_change_and_downgrade_preserve_remote(self):
        for version in (VERSION, "10.0.0"):
            with self.subTest(version=version):
                self.seed_commit({"Casks/filemint.rb": tap.render_cask(version, "c" * 64)})
                head = self.remote_head()
                with self.assertRaises(EVIDENCE_ERROR):
                    self.publish()
                self.assertEqual(self.remote_head(), head)

    def test_unrecognized_remote_ruby_and_layout_are_not_rewritten(self):
        self.seed_commit({"Casks/filemint.rb": self.remote_cask() + 'system("true")\n'})
        head = self.remote_head()
        with self.assertRaises(EVIDENCE_ERROR):
            self.publish()
        self.assertEqual(self.remote_head(), head)
        self.seed_commit({"Casks/filemint.rb": tap.render_cask("9.9.99", "c" * 64),
                          "cmd/brew-surprise.rb": "raise 'must not execute'\n"})
        head = self.remote_head()
        with self.assertRaises(EVIDENCE_ERROR):
            self.publish()
        self.assertEqual(self.remote_head(), head)

    def test_missing_tap_never_creates_a_repository_or_starts_git_write(self):
        with patch.object(self, "api", side_effect=tap.TapError("Fixture tap does not exist")):
            with self.assertRaises(EVIDENCE_ERROR):
                self.publish()
        self.assertEqual(self.remote_head(), self.base)
        self.assertEqual(self.commands, [])

    def test_brew_validation_failure_preserves_existing_tap(self):
        with patch.object(tap, "validate_release", return_value=self.evidence), \
                patch.object(tap, "TapGitHub", return_value=self), \
                patch.object(tap, "run", side_effect=self.command), \
                patch.object(tap, "validate_brew", side_effect=tap.TapError("Fixture audit failed")):
            with self.assertRaises(EVIDENCE_ERROR):
                tap.publish(self.manifest_path, self.gh)
        self.assertEqual(self.remote_head(), self.base)
        self.assertFalse(any("push" in args for args in self.commands))

    def test_release_revalidation_failure_stops_before_push(self):
        calls = 0

        def evidence(*args, **kwargs):
            nonlocal calls
            calls += 1
            if calls > 1:
                raise tap.TapError("Latest changed during preparation")
            return copy.deepcopy(self.evidence)

        with self.assertRaises(EVIDENCE_ERROR):
            self.publish(evidence=evidence)
        self.assertGreaterEqual(calls, 2)
        self.assertEqual(self.remote_head(), self.base)
        self.assertFalse(any("push" in args for args in self.commands))

    def test_concurrent_remote_change_is_not_force_pushed_or_retried_over(self):
        self.push_mode = "concurrent"
        with self.assertRaises(EVIDENCE_ERROR):
            self.publish()
        self.assertEqual(self.remote_cask(), tap.render_cask("9.9.99", "c" * 64))
        readme = self.git("--git-dir", str(self.remote), "show", "refs/heads/main:README.md")
        self.assertEqual(readme, "Concurrent maintainer change")
        self.assertFalse(any("--force" in arg for args in self.commands for arg in args))

    def test_lost_push_response_reconciles_from_actual_remote_and_readback(self):
        self.push_mode = "after"
        receipt, _ = self.publish()
        self.assertEqual(receipt["status"], "published")
        self.assertEqual(receipt["tap_commit"], self.remote_head())
        retry, _ = self.publish()
        self.assertEqual(retry["status"], "unchanged")

    def test_failed_push_can_retry_without_touching_release_or_artifacts(self):
        original = {path.name: path.read_bytes() for path in self.work.iterdir() if path.is_file()}
        self.push_mode = "before"
        with self.assertRaises(EVIDENCE_ERROR):
            self.publish()
        self.assertEqual(self.remote_head(), self.base)
        self.push_mode = None
        receipt, _ = self.publish()
        self.assertEqual(receipt["status"], "published")
        for filename, content in original.items():
            self.assertEqual((self.work / filename).read_bytes(), content)
        self.assertTrue(all(method == "GET" for method, _, _ in self.gh.events))

    def test_bad_remote_readback_does_not_claim_success_or_undo_public_push(self):
        self.api_wrong_content = True
        with self.assertRaises(EVIDENCE_ERROR):
            self.publish()
        self.assertNotEqual(self.remote_head(), self.base)
        self.assertEqual(self.remote_cask(), tap.render_cask(VERSION, self.manifest["dmgSHA256"]))


if __name__ == "__main__":
    unittest.main()
