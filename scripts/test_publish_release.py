#!/usr/bin/env python3
"""Offline publication transaction, worker and local-guard regressions."""
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("publication", ROOT / "scripts/release_publication.py")
publication = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publication)
VERSION, TAG, COMMIT = "9.9.9", "v9.9.9", "a" * 40
NAMES = [f"FileMint-{VERSION}.dmg", f"FileMint-{VERSION}.dmg.sha256", "appcast.xml"]


def release(draft=True):
    return {"id": 7, "tag_name": TAG, "draft": draft, "prerelease": False,
            "html_url": f"{publication.PUBLIC}/releases/tag/{TAG}",
            "assets": [{"id": 100 + index, "name": name, "size": 20, "state": "uploaded",
                        "browser_download_url": f"{publication.PUBLIC}/releases/download/{TAG}/{name}"}
                       for index, name in enumerate(NAMES)]}


def workflow_run(run_id, workflow, request=None, branch="main", commit=COMMIT):
    return {"id": run_id, "path": f".github/workflows/{workflow}", "head_sha": commit,
            "head_branch": branch, "event": "workflow_dispatch" if request else "push",
            "display_title": request or "Source CI", "status": "completed", "conclusion": "success"}


class FakeGitHub:
    def __init__(self):
        self.release = None
        self.previous = {"id": 6, "tag_name": "v9.9.8", "draft": False, "prerelease": False}
        self.runs = {1: workflow_run(1, "ci.yml")}
        self.events = []
        self.conclusions = {}
        self.pending = set()
        self.omit = set()
        self.hook = None
        self.promotion_error = None
        self.read_error_after_promotion = False
        self.expired = False
        self.artifact_id = 501
        self.asset_changed = False
        self.tag_commit = COMMIT
        self.api_failure = None
        self.uploaded = {}

    def create(self, tag, version, assets, notes):
        self.events.append(("create", tag))
        assert tag == TAG and version == VERSION
        assert [path.name for path in assets] == NAMES
        assert "Fixture release" in notes.read_text()
        self.uploaded = {path.name: path.read_bytes() for path in assets}
        self.release = release()

    def upload(self, tag, assets):
        self.events.append(("upload", [path.name for path in assets]))
        missing = {asset["name"]: asset for asset in release()["assets"]}
        self.release["assets"] += [missing[path.name] for path in assets]

    def api(self, endpoint, method="GET", body=None, missing_ok=False):
        self.events.append((method, endpoint, copy.deepcopy(body)))
        if self.hook:
            self.hook(endpoint, method, body)
        if self.api_failure and self.api_failure in endpoint:
            raise publication.APIError("Fixture API error", 503)
        path = urlsplit(endpoint).path
        if self.read_error_after_promotion and self.release and not self.release["draft"] and path.startswith("releases/"):
            raise publication.APIError("Unknown public status", 503)
        if path == "releases":
            return copy.deepcopy([self.release] if self.release else [self.previous])
        if path == f"releases/tags/{TAG}" and (not self.release or self.release["draft"]):
            if missing_ok:
                return None
            raise publication.APIError("Published release not found", 404)
        if path == f"releases/tags/{TAG}" or path == "releases/7":
            if method == "PATCH":
                assert body == {"draft": False, "prerelease": False, "make_latest": "true"}
                if self.promotion_error != "before":
                    self.release["draft"] = False
                if self.promotion_error:
                    raise publication.APIError("Uncertain promotion response", 502)
            if self.release is None and not missing_ok:
                raise publication.APIError("Not found", 404)
            return copy.deepcopy(self.release)
        if path == "releases/latest":
            return copy.deepcopy(self.release if self.release and not self.release["draft"] else self.previous)
        if path == f"git/ref/tags/{TAG}":
            return {"object": {"type": "commit", "sha": self.tag_commit}}
        if path == "git/ref/heads/main":
            return {"object": {"type": "commit", "sha": COMMIT}}
        if path.startswith("actions/workflows/"):
            workflow = path.split("/")[2]
            if path.endswith("/dispatches"):
                kind = next(kind for kind, name in publication.WORKFLOWS.items() if name == workflow)
                inputs = body["inputs"]
                assert body["ref"] == ("main" if kind == "deploy" else TAG)
                if kind in ("candidate", "deploy"):
                    assert json.loads(inputs["assets"]) == publication.asset_snapshot(self.release, TAG)
                    assert inputs["release_id"] == "7" and inputs["build"] == "99"
                if kind == "deploy":
                    assert self.release["draft"] is False
                    assert inputs["artifact_id"] == str(self.artifact_id)
                    assert self.runs[int(inputs["build_run_id"])]["conclusion"] == "success"
                if kind not in self.omit:
                    run_id = len(self.runs) + 10
                    run = workflow_run(run_id, workflow, f"FileMint {kind} {inputs['request_id']}", body["ref"])
                    run["conclusion"] = self.conclusions.get(kind, "success")
                    if kind in self.pending:
                        run.update(status="in_progress", conclusion=None)
                    self.runs[run_id] = run
                return None
            return {"workflow_runs": copy.deepcopy([run for run in self.runs.values()
                                                      if run["path"].endswith("/" + workflow)])}
        if path.startswith("actions/runs/"):
            run_id = int(path.split("/")[2])
            if path.endswith("/artifacts"):
                return {"artifacts": [{"id": self.artifact_id, "name": "github-pages", "expired": self.expired}]}
            return copy.deepcopy(self.runs[run_id])
        raise AssertionError((endpoint, method, body))


class PublicationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="filemint-publication-")
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)
        self.manifest = self.work / f"FileMint-{VERSION}.release.json"
        self.candidate = {"version": VERSION, "tag": TAG, "commit": COMMIT, "build": "99",
                          "dmgSHA256": "1" * 64, "appcastSHA256": "2" * 64}
        self.manifest.write_text(json.dumps(self.candidate))
        (self.work / f"FileMint-{VERSION}.dmg").write_bytes(b"verified local candidate")
        (self.work / f"FileMint-{VERSION}.dmg.sha256").write_text("local portable checksum")
        self.feed = self.work / f"FileMint-{VERSION}.appcast.xml"
        self.feed.write_text(f'<enclosure url="{publication.PUBLIC}/releases/download/{TAG}/{NAMES[0]}" edSignature="final-signature"/>')
        self.gh = FakeGitHub()
        self.time = 0
        self.sleep_callback = None
        self.website_changed = True
        self.commands = []
        self.addCleanup(patch.stopall)
        patch.object(publication, "command", side_effect=self.command).start()
        patch.dict(os.environ, {"FILEMINT_ACTIONS_TIMEOUT_SECONDS": "3", "FILEMINT_ACTIONS_POLL_SECONDS": "1"}).start()

    def command(self, args, **kwargs):
        self.commands.append(args)
        if args[:2] == ["git", "diff"]:
            return "website/index.md" if self.website_changed else ""
        if args[:2] == ["git", "ls-remote"]:
            return ""
        if args[0] == "git":
            return COMMIT
        if args[:2] == ["python3", "scripts/release_metadata.py"]:
            return "# FileMint 9.9.9\nFixture release"
        raise AssertionError(args)

    def sleep(self, duration):
        self.time += duration
        if self.sleep_callback:
            self.sleep_callback()

    def instance(self):
        return publication.Publication(self.manifest, self.gh, lambda: self.time, self.sleep)

    def run_publication(self):
        runner = self.instance()
        with contextlib.redirect_stdout(io.StringIO()) as out:
            runner.run()
        return runner, out.getvalue()

    def stages(self):
        result = []
        for event in self.gh.events:
            if event[0] == "create":
                result.append("draft")
            elif event[0] == "POST" and event[1].endswith("/dispatches"):
                result.append(event[1].split("/")[2])
            elif event[0] == "PATCH":
                result.append("publish")
        return result

    def test_draft_checks_publish_and_deploy_order_preserves_sparkle_feed(self):
        original = self.feed.read_bytes()
        runner, output = self.run_publication()
        self.assertEqual(self.stages(), ["draft", "release.yml", "build-pages.yml", "publish", "deploy-pages.yml"])
        self.assertEqual(runner.state["phase"], "complete")
        self.assertEqual(self.gh.uploaded["appcast.xml"], original)
        self.assertEqual(self.feed.read_bytes(), original)
        self.assertLess(output.index("not available for online updates"), output.index("Published and confirmed"))
        self.assertTrue(all(args[:3] != ["gh", "release", "download"] for args in self.commands))

    def test_prepublication_failed_cancelled_and_skipped_checks_keep_draft(self):
        for kind, conclusion in (("candidate", "failure"), ("candidate", "cancelled"),
                                 ("site", "timed_out"), ("site", "skipped")):
            with self.subTest(kind=kind, conclusion=conclusion):
                self.gh = FakeGitHub()
                self.gh.conclusions[kind] = conclusion
                self.manifest.with_name(f"FileMint-{VERSION}.publication.json").unlink(missing_ok=True)
                with self.assertRaisesRegex(publication.PublicationError, "did not succeed"):
                    self.run_publication()
                self.assertTrue(self.gh.release["draft"])
                self.assertNotIn("publish", self.stages())
                self.assertNotIn("deploy-pages.yml", self.stages())

    def test_source_ci_failure_blocks_candidate_dispatch_and_publication(self):
        self.gh.runs[1]["conclusion"] = "failure"
        with self.assertRaisesRegex(publication.PublicationError, "Source CI did not succeed"):
            self.run_publication()
        self.assertEqual(self.stages(), ["draft"])

    def test_each_pending_prepublication_job_blocks_publication(self):
        for kind in ("candidate", "site"):
            with self.subTest(kind=kind):
                self.gh = FakeGitHub()
                self.gh.pending.add(kind)
                self.manifest.with_name(f"FileMint-{VERSION}.publication.json").unlink(missing_ok=True)
                def complete():
                    self.assertTrue(self.gh.release["draft"])
                    self.assertNotIn("publish", self.stages())
                    for run in self.gh.runs.values():
                        run.update(status="completed", conclusion="success")
                self.sleep_callback = complete
                self.run_publication()
                self.assertIn("publish", self.stages())

    def test_missing_current_request_cannot_reuse_old_green_candidate(self):
        self.gh.omit.add("candidate")
        self.gh.runs[2] = workflow_run(2, "release.yml", "FileMint candidate old", TAG)
        with self.assertRaisesRegex(publication.PublicationError, "Timed out"):
            self.run_publication()
        self.assertTrue(self.gh.release["draft"])

    def test_missing_source_ci_does_not_use_other_branch_or_commit(self):
        self.gh.runs = {1: workflow_run(1, "ci.yml", branch="other"),
                        2: workflow_run(2, "ci.yml", commit="b" * 40)}
        with self.assertRaisesRegex(publication.PublicationError, "Timed out waiting for Source CI"):
            self.run_publication()
        self.assertNotIn("publish", self.stages())

    def test_unchanged_site_is_explicitly_not_applicable(self):
        self.website_changed = False
        runner, output = self.run_publication()
        self.assertEqual(self.stages(), ["draft", "release.yml", "publish"])
        self.assertFalse(runner.state["website_required"])
        self.assertIn("not applicable", output)

    def test_expired_website_artifact_blocks_publication(self):
        self.gh.expired = True
        with self.assertRaisesRegex(publication.PublicationError, "missing or expired"):
            self.run_publication()
        self.assertTrue(self.gh.release["draft"])

    def test_asset_replacement_during_ci_blocks_promotion(self):
        def change(endpoint, method, body):
            if endpoint.startswith("actions/workflows/build-pages.yml/runs"):
                self.gh.release["assets"][0]["id"] = 999
        self.gh.hook = change
        with self.assertRaisesRegex(publication.PublicationError, "asset IDs changed"):
            self.run_publication()
        self.assertNotIn("publish", self.stages())

    def test_tag_movement_blocks_publication(self):
        self.gh.tag_commit = "b" * 40
        with self.assertRaisesRegex(publication.PublicationError, "tag no longer"):
            self.run_publication()
        self.assertTrue(self.gh.release["draft"])

    def test_uncertain_promotion_response_is_reconciled_without_second_upload(self):
        self.gh.promotion_error = "after"
        runner, _ = self.run_publication()
        self.assertEqual(runner.state["phase"], "complete")
        self.assertEqual(self.stages().count("publish"), 1)
        self.assertEqual(self.stages().count("draft"), 1)

    def test_failed_promotion_stays_draft_and_resume_reuses_verified_runs(self):
        self.gh.promotion_error = "before"
        with self.assertRaisesRegex(publication.PublicationError, "did not make the draft public"):
            self.run_publication()
        self.assertTrue(self.gh.release["draft"])
        self.gh.promotion_error = None
        self.run_publication()
        self.assertEqual(self.stages().count("release.yml"), 1)
        self.assertEqual(self.stages().count("build-pages.yml"), 1)

    def test_unknown_publication_keeps_publishing_journal_and_recovers(self):
        self.gh.promotion_error = "after"
        self.gh.read_error_after_promotion = True
        runner = self.instance()
        with self.assertRaises(publication.APIError), contextlib.redirect_stdout(io.StringIO()):
            runner.run()
        self.assertTrue(runner.unknown)
        self.assertEqual(runner.state["phase"], "publishing")
        self.assertTrue(self.instance().unknown)
        self.gh.read_error_after_promotion = False
        self.run_publication()
        self.assertEqual(self.stages().count("publish"), 1)
        self.assertEqual(self.stages().count("release.yml"), 1)

    def test_site_failure_is_post_publication_and_resume_only_observes_site_rerun(self):
        self.gh.conclusions["deploy"] = "failure"
        runner = self.instance()
        with self.assertRaisesRegex(publication.PublicationError, "deploy did not succeed"), contextlib.redirect_stdout(io.StringIO()):
            runner.run()
        self.assertTrue(runner.public)
        self.assertFalse(self.gh.release["draft"])
        self.assertEqual(runner.state["phase"], "published")
        before = self.stages()
        self.gh.runs[runner.state["requests"]["deploy"]["run_id"]]["conclusion"] = "success"
        resumed, _ = self.run_publication()
        self.assertEqual(resumed.state["phase"], "complete")
        self.assertEqual(self.stages(), before)

    def test_fresh_verified_site_artifact_retries_deployment_without_republishing_app(self):
        self.gh.conclusions["deploy"] = "failure"
        with self.assertRaises(publication.PublicationError):
            self.run_publication()
        self.gh.artifact_id = 502
        self.gh.conclusions["deploy"] = "success"
        runner, _ = self.run_publication()
        self.assertEqual(runner.state["site_artifact"]["id"], 502)
        self.assertEqual(len(runner.state["past_deployments"]), 1)
        self.assertEqual(self.stages().count("deploy-pages.yml"), 2)
        self.assertEqual(self.stages().count("publish"), 1)
        self.assertEqual(self.stages().count("draft"), 1)

    def test_existing_release_without_journal_is_never_adopted_or_replaced(self):
        for draft in (True, False):
            with self.subTest(draft=draft):
                self.gh.release = release(draft)
                self.commands.clear()
                with self.assertRaises(publication.PublicationError):
                    self.run_publication()
                self.assertFalse(self.commands)
                self.assertFalse(self.stages())

    def test_journal_for_another_candidate_is_rejected(self):
        runner = self.instance()
        runner.save()
        self.candidate["dmgSHA256"] = "3" * 64
        self.manifest.write_text(json.dumps(self.candidate))
        with self.assertRaisesRegex(publication.PublicationError, "does not match"):
            self.instance()

    def test_public_url_or_latest_mismatch_blocks_update_success_report(self):
        for failure in ("url", "latest"):
            with self.subTest(failure=failure):
                gh = FakeGitHub()
                gh.release = release(False)
                snapshot = publication.asset_snapshot(gh.release, TAG)
                if failure == "url":
                    gh.release["assets"][0]["browser_download_url"] = "https://example.invalid/draft.dmg"
                else:
                    original = gh.api
                    gh.api = lambda endpoint, *args, **kwargs: gh.previous if endpoint == "releases/latest" else original(endpoint, *args, **kwargs)
                with self.assertRaises(publication.PublicationError):
                    publication.check_public(gh, 7, TAG, COMMIT, snapshot)

    def test_api_failure_never_turns_into_a_missing_optional_job(self):
        self.gh.api_failure = "actions/workflows/build-pages.yml/runs"
        with self.assertRaises(publication.APIError):
            self.run_publication()
        self.assertTrue(self.gh.release["draft"])

    def test_draft_download_worker_keeps_full_sparkle_checks_and_expected_build(self):
        self.gh.release = release()
        inputs = {"release_id": "7", "tag": TAG, "commit": COMMIT, "build": "99",
                  "assets": json.dumps(publication.asset_snapshot(self.gh.release, TAG))}
        calls = []
        def run(args, **kwargs):
            calls.append(args)
            if args[0] == "gh":
                kwargs["stdout"].write(b"x" * 20)
            return subprocess.CompletedProcess(args, 0)
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "true", "FILEMINT_PUBLICATION_INPUTS": json.dumps(inputs)}), \
                patch.object(publication, "GitHub", return_value=self.gh), patch.object(publication.subprocess, "run", side_effect=run):
            publication.verify_candidate()
        checks = [args for args in calls if args[:2] == ["bash", "scripts/verify_release_artifact.sh"]]
        self.assertEqual(len(checks), 1)
        self.assertEqual(checks[0][3:5], [VERSION, "99"])
        self.assertTrue(checks[0][5].endswith("/appcast.xml"))
        self.assertEqual(len([args for args in calls if args[0] == "gh"]), 3)

    def test_candidate_worker_rejects_discovery_size_mismatch(self):
        self.gh.release = release()
        inputs = {"release_id": "7", "tag": TAG, "commit": COMMIT, "build": "99",
                  "assets": json.dumps(publication.asset_snapshot(self.gh.release, TAG))}
        def truncated(args, **kwargs):
            kwargs["stdout"].write(b"short")
            return subprocess.CompletedProcess(args, 0)
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "true", "FILEMINT_PUBLICATION_INPUTS": json.dumps(inputs)}), \
                patch.object(publication, "GitHub", return_value=self.gh), patch.object(publication.subprocess, "run", side_effect=truncated):
            with self.assertRaisesRegex(publication.PublicationError, "size differs"):
                publication.verify_candidate()

    def test_site_deployment_reuses_verified_archive_without_a_build(self):
        runner, _ = self.run_publication()
        site = runner.state["requests"]["site"]
        inputs = runner.inputs() | {"build_run_id": str(site["run_id"]), "build_request_id": site["request_id"], "artifact_id": "501"}
        output = self.work / "outputs"
        downloaded = []
        def fetch(args, **kwargs):
            if args[:3] == ["gh", "run", "download"]:
                downloaded.append(args)
                (Path(args[-1]) / "artifact.tar").write_bytes(b"the already verified website tar")
                return ""
            return self.command(args)
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "true", "FILEMINT_PUBLICATION_INPUTS": json.dumps(inputs),
                                     "RUNNER_TEMP": str(self.work), "GITHUB_OUTPUT": str(output)}), \
                patch.object(publication, "GitHub", return_value=self.gh), patch.object(publication, "command", side_effect=fetch):
            publication.prepare_site_deployment()
            archive = Path(output.read_text().strip().split("=", 1)[1])
            self.assertEqual(archive.read_bytes(), b"the already verified website tar")
            self.assertEqual(downloaded[0][3], str(site["run_id"]))
            inputs["artifact_id"] = "502"
            os.environ["FILEMINT_PUBLICATION_INPUTS"] = json.dumps(inputs)
            with self.assertRaisesRegex(publication.PublicationError, "artifact identity changed"):
                publication.prepare_site_deployment()
            self.assertEqual(len(downloaded), 1)

    def test_site_deployment_rejects_unpublished_release_before_downloading(self):
        self.gh.release = release()
        inputs = {"release_id": "7", "tag": TAG, "commit": COMMIT, "build": "99",
                  "assets": json.dumps(publication.asset_snapshot(self.gh.release, TAG)),
                  "build_run_id": "11", "build_request_id": "request", "artifact_id": "501"}
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "true", "FILEMINT_PUBLICATION_INPUTS": json.dumps(inputs)}), \
                patch.object(publication, "GitHub", return_value=self.gh):
            with self.assertRaisesRegex(publication.PublicationError, "Release state"):
                publication.prepare_site_deployment()
        self.assertTrue(all(args[0] != "gh" for args in self.commands))

    def test_candidate_worker_rejects_published_release_and_wrong_checkout(self):
        self.gh.release = release(False)
        inputs = {"release_id": "7", "tag": TAG, "commit": COMMIT, "build": "99",
                  "assets": json.dumps(publication.asset_snapshot(self.gh.release, TAG))}
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "true", "FILEMINT_PUBLICATION_INPUTS": json.dumps(inputs)}), \
                patch.object(publication, "GitHub", return_value=self.gh), patch.object(publication.subprocess, "run") as download:
            with self.assertRaises(publication.PublicationError):
                publication.verify_candidate()
            download.assert_not_called()
            inputs["commit"] = "b" * 40
            os.environ["FILEMINT_PUBLICATION_INPUTS"] = json.dumps(inputs)
            with self.assertRaisesRegex(publication.PublicationError, "checkout differs"):
                publication.verify_candidate()

    def test_workers_refuse_local_remote_downloads(self):
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}):
            with self.assertRaisesRegex(publication.PublicationError, "restricted to GitHub Actions"):
                publication.verify_candidate()


class LocalSourceGuardTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="filemint-publication-source-")
        self.addCleanup(temporary.cleanup)
        self.repo = Path(temporary.name)
        (self.repo / "scripts").mkdir()
        for name in ("publish_local.sh", "release_metadata.py"):
            shutil.copyfile(ROOT / "scripts" / name, self.repo / "scripts" / name)
        (self.repo / "scripts/update_appcast.py").write_text("import os, sys\nsys.exit(int(os.environ.get('FAIL_APPCAST', '0')))\n")
        (self.repo / "scripts/verify_release_artifact.sh").write_text('exit "${FAIL_ARTIFACT:-0}"\n')
        (self.repo / "scripts/release_publication.py").write_text("print('REMOTE_PUBLICATION_ENTERED')\n")
        (self.repo / "project.yml").write_text(f"settings:\n  base:\n    MARKETING_VERSION: {VERSION}\n    CURRENT_PROJECT_VERSION: 99\n")
        (self.repo / "docs").mkdir()
        (self.repo / "docs/RELEASE_NOTES.md").write_text(f"# FileMint {VERSION}\nFixture release\n")
        (self.repo / ".gitignore").write_text("build/\nConfig/Signing/\n")
        self.env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        for args in (("init", "-q", "-b", "main"), ("config", "user.name", "Fixture"),
                     ("config", "user.email", "fixture@example.invalid"), ("config", "core.hooksPath", os.devnull),
                     ("remote", "add", "origin", "https://github.com/FileMintApp/FileMint.git"),
                     ("add", "."), ("commit", "-qm", "fixture"), ("tag", TAG)):
            self.git(*args)
        self.commit = self.git("rev-parse", "HEAD").strip()
        (self.repo / "build").mkdir()
        self.dmg = self.repo / "build" / NAMES[0]
        self.dmg.write_bytes(b"locally verified candidate")
        Path(str(self.dmg) + ".sha256").write_text("portable checksum")
        feed = self.repo / "build" / f"FileMint-{VERSION}.appcast.xml"
        feed.write_text("verified signed feed")
        certificate = self.repo / "Config/Signing/DeveloperIDApplication-8S66M2ZLD5.cer"
        certificate.parent.mkdir(parents=True)
        certificate.write_bytes(b"synthetic certificate")
        self.manifest = self.repo / "build" / f"FileMint-{VERSION}.release.json"
        self.original = {"version": VERSION, "build": "99", "tag": TAG, "commit": self.commit,
                         "dmgSHA256": hashlib.sha256(self.dmg.read_bytes()).hexdigest(),
                         "appcastSHA256": hashlib.sha256(feed.read_bytes()).hexdigest(),
                         "certificateSHA256": hashlib.sha256(certificate.read_bytes()).hexdigest()}
        self.manifest.write_text(json.dumps(self.original))

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.repo, env=self.env, check=True,
                              text=True, capture_output=True, timeout=20).stdout

    def publish(self, **env):
        return subprocess.run(["bash", "scripts/publish_local.sh"], cwd=self.repo, env=self.env | env,
                              capture_output=True, text=True, timeout=20)

    def test_valid_candidate_enters_remote_transaction_after_local_checks(self):
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("REMOTE_PUBLICATION_ENTERED", result.stdout)

    def test_each_mismatched_manifest_field_blocks_remote_work(self):
        for field in self.original:
            with self.subTest(field=field):
                self.manifest.write_text(json.dumps(self.original | {field: "different"}))
                result = self.publish()
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("REMOTE_PUBLICATION_ENTERED", result.stdout)

    def test_appcast_and_sparkle_artifact_failures_block_remote_work(self):
        for failure in ("FAIL_APPCAST", "FAIL_ARTIFACT"):
            result = self.publish(**{failure: "1"})
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("REMOTE_PUBLICATION_ENTERED", result.stdout)

    def test_dirty_source_blocks_remote_work(self):
        (self.repo / "uncommitted.txt").write_text("pending")
        result = self.publish()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("REMOTE_PUBLICATION_ENTERED", result.stdout)


class GitHubTransportTests(unittest.TestCase):
    def test_real_upload_commands_create_only_a_draft_and_never_clobber_assets(self):
        with patch.object(publication, "command") as call:
            gh = publication.GitHub()
            gh.create(TAG, VERSION, [Path(name) for name in NAMES], Path("notes.md"))
            self.assertIn("--draft", call.call_args.args[0])
            self.assertNotIn("--latest", call.call_args.args[0])
            gh.upload(TAG, [Path(NAMES[0])])
            self.assertNotIn("--clobber", call.call_args.args[0])

    def test_not_found_is_distinct_from_authentication_or_transport_errors(self):
        for status in (404, 403, 500):
            result = subprocess.CompletedProcess([], 1, f'HTTP/2.0 {status} Error\nHeader: value\n\n{{"message":"error"}}', "error")
            with patch.object(publication.subprocess, "run", return_value=result):
                if status == 404:
                    self.assertIsNone(publication.GitHub().api("releases/tags/v9.9.9", missing_ok=True))
                else:
                    with self.assertRaises(publication.APIError):
                        publication.GitHub().api("releases/tags/v9.9.9", missing_ok=True)

    def test_dispatch_payload_uses_stdin_json_and_empty_success_is_supported(self):
        result = subprocess.CompletedProcess([], 0, "HTTP/2.0 204 No Content\nHeader: value\n\n", "")
        body = {"ref": TAG, "inputs": {"notes": "literal $(command)\nand newlines"}}
        with patch.object(publication.subprocess, "run", return_value=result) as run:
            self.assertIsNone(publication.GitHub().api("actions/workflows/release.yml/dispatches", "POST", body))
            self.assertEqual(json.loads(run.call_args.kwargs["input"]), body)


if __name__ == "__main__":
    unittest.main()
