#!/usr/bin/env python3
"""Stage, verify and promote one release; only Actions runners download assets."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlencode
import uuid

ROOT = Path(__file__).resolve().parent.parent
REPO = "FileMintApp/FileMint"
API = f"repos/{REPO}"
PUBLIC = f"https://github.com/{REPO}"
SITE_INPUTS = ("README.md", "README.en.md", "website", "package.json", "pnpm-lock.yaml",
               ".github/workflows/build-pages.yml", ".github/workflows/deploy-pages.yml")
WORKFLOWS = {"candidate": "release.yml", "site": "build-pages.yml", "deploy": "deploy-pages.yml"}


class PublicationError(RuntimeError):
    pass


class APIError(PublicationError):
    def __init__(self, message, status=None):
        super().__init__(message)
        self.status = status


def command(args, **kwargs):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True, timeout=120, **kwargs)
    if result.returncode:
        raise PublicationError(f"{args[0]} failed: {result.stderr.strip()[:1000]}")
    return result.stdout.strip()


class GitHub:
    def api(self, endpoint, method="GET", body=None, missing_ok=False):
        args = ["gh", "api", f"{API}/{endpoint}", "--method", method, "--include",
                "-H", "Accept: application/vnd.github+json"]
        if body is not None:
            args += ["--input", "-"]
        result = subprocess.run(args, cwd=ROOT, input=json.dumps(body) if body is not None else None,
                                text=True, capture_output=True, timeout=120)
        header, separator, payload = result.stdout.partition("\n\n")
        match = re.match(r"HTTP/\S+\s+(\d+)", header)
        status = int(match[1]) if match else None
        if missing_ok and status == 404:
            return None
        if result.returncode or status is None or not 200 <= status < 300:
            raise APIError(f"GitHub {method} {endpoint} failed (HTTP {status or 'unknown'})", status)
        if not separator or not payload.strip():
            return None
        try:
            return json.loads(payload)
        except ValueError as error:
            raise APIError("GitHub returned invalid JSON", status) from error

    def create(self, tag, version, assets, notes):
        command(["gh", "release", "create", tag, *map(str, assets), "--repo", REPO,
                 "--draft", "--verify-tag", "--title", f"FileMint {version}", "--notes-file", str(notes)])

    def upload(self, tag, assets):
        command(["gh", "release", "upload", tag, *map(str, assets), "--repo", REPO])


def validate_identity(tag, commit, build=None):
    if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", tag) or not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise PublicationError("Invalid release tag or commit")
    if build is not None and not re.fullmatch(r"[1-9][0-9]*", str(build)):
        raise PublicationError("Invalid release build")


def positive_id(value):
    if not re.fullmatch(r"[1-9][0-9]*", str(value)):
        raise PublicationError("Invalid GitHub resource ID")
    return int(value)


def find_release(gh, tag):
    # The tag endpoint is documented for published releases. Drafts require the
    # authenticated release listing; a 404 must not be mistaken for no draft.
    published = gh.api(f"releases/tags/{tag}", missing_ok=True)
    if published is not None:
        return published
    for page in range(1, 101):
        releases = gh.api(f"releases?per_page=100&page={page}")
        matches = [release for release in releases if release.get("tag_name") == tag]
        if len(matches) > 1:
            raise PublicationError("Ambiguous Release tag")
        if matches:
            return matches[0]
        if len(releases) < 100:
            return None
    raise PublicationError("Release listing exceeded the discovery limit")


def asset_snapshot(release, tag, complete=True):
    if release.get("tag_name") != tag or release.get("prerelease") is not False:
        raise PublicationError("Release tag or prerelease state does not match")
    version = tag[1:]
    expected = {f"FileMint-{version}.dmg", f"FileMint-{version}.dmg.sha256", "appcast.xml"}
    assets = release.get("assets", [])
    names = [asset.get("name") for asset in assets]
    if len(names) != len(set(names)) or not set(names) <= expected or (complete and set(names) != expected):
        raise PublicationError("Release must contain exactly the DMG, checksum and appcast.xml")
    snapshot = []
    for asset in assets:
        if asset.get("state") != "uploaded" or type(asset.get("size")) is not int or asset["size"] <= 0:
            raise PublicationError("Release asset upload is incomplete")
        snapshot.append({"name": asset["name"], "id": positive_id(asset["id"]), "size": asset["size"]})
    return sorted(snapshot, key=lambda asset: asset["name"])


def resolve_tag(gh, tag):
    obj = gh.api(f"git/ref/tags/{tag}")["object"]
    for _ in range(5):
        if obj.get("type") == "commit":
            return obj["sha"]
        if obj.get("type") != "tag" or not re.fullmatch(r"[0-9a-f]{40}", obj.get("sha", "")):
            break
        obj = gh.api(f"git/tags/{obj['sha']}")["object"]
    raise PublicationError("Cannot resolve the release tag to a commit")


def check_release(gh, release_id, tag, commit, snapshot, draft):
    release = gh.api(f"releases/{positive_id(release_id)}")
    if (release.get("id") != release_id or release.get("draft") is not draft
            or asset_snapshot(release, tag) != snapshot):
        raise PublicationError("Release state or candidate asset IDs changed; retain it and investigate")
    if resolve_tag(gh, tag) != commit:
        raise PublicationError("Remote tag no longer points at the verified source")
    return release


def check_public(gh, release_id, tag, commit, snapshot):
    release = check_release(gh, release_id, tag, commit, snapshot, False)
    if release.get("html_url") != f"{PUBLIC}/releases/tag/{tag}":
        raise PublicationError("Unexpected public release page URL")
    for asset in release["assets"]:
        if asset.get("browser_download_url") != f"{PUBLIC}/releases/download/{tag}/{asset['name']}":
            raise PublicationError("Public update asset URL is not the immutable tag URL")
    latest = gh.api("releases/latest")
    if (latest.get("id") != release_id or latest.get("draft") is not False or latest.get("prerelease") is not False
            or latest.get("html_url") != f"{PUBLIC}/releases/tag/{tag}"):
        raise PublicationError("Latest does not expose this stable release; online-update discovery is unconfirmed")
    if asset_snapshot(latest, tag) != snapshot:
        raise PublicationError("Latest release assets differ from the verified candidate")
    if any(asset.get("browser_download_url") != f"{PUBLIC}/releases/download/{tag}/{asset['name']}"
           for asset in latest["assets"]):
        raise PublicationError("Latest update download URLs are invalid")
    return release


def matching_run(run, workflow, commit, branch, request=None):
    if (run.get("head_sha") != commit or run.get("head_branch") != branch or
            run.get("path", "").split("@")[0] != f".github/workflows/{workflow}"):
        return False
    if request is None:
        return run.get("event") == "push"
    return run.get("event") == "workflow_dispatch" and run.get("display_title") == request


def site_artifact(gh, run_id):
    data = gh.api(f"actions/runs/{positive_id(run_id)}/artifacts?per_page=100")
    candidates = [item for item in data["artifacts"]
                  if item.get("name") == "github-pages" and item.get("expired") is False]
    if len(candidates) != 1:
        raise PublicationError("The verified website artifact is missing or expired")
    return {"id": positive_id(candidates[0]["id"]), "name": "github-pages"}


class Publication:
    def __init__(self, manifest_path, gh=None, clock=time.monotonic, sleep=time.sleep):
        self.manifest_path = Path(manifest_path)
        self.manifest = json.loads(self.manifest_path.read_text())
        self.version = self.manifest["version"]
        self.tag, self.commit, self.build = self.manifest["tag"], self.manifest["commit"], self.manifest["build"]
        validate_identity(self.tag, self.commit, self.build)
        if self.tag != f"v{self.version}":
            raise PublicationError("Manifest version/tag mismatch")
        self.path = self.manifest_path.with_name(f"FileMint-{self.version}.publication.json")
        self.gh, self.clock, self.sleep = gh or GitHub(), clock, sleep
        self.public = False
        self.unknown = False
        self.observed = False
        self.timeout = int(os.environ.get("FILEMINT_ACTIONS_TIMEOUT_SECONDS", "2700"))
        self.interval = int(os.environ.get("FILEMINT_ACTIONS_POLL_SECONDS", "15"))
        if not 1 <= self.timeout <= 86400 or not 1 <= self.interval <= 300:
            raise PublicationError("Invalid Actions wait duration")
        if self.path.is_symlink():
            raise PublicationError("Publication journal must not be a symlink")
        self.state = json.loads(self.path.read_text()) if self.path.exists() else {
            "schemaVersion": 1, "candidate": self.manifest, "phase": "preparing", "requests": {}}
        if self.state.get("schemaVersion") != 1 or self.state.get("candidate") != self.manifest:
            raise PublicationError("Publication journal does not match this local candidate")
        self.unknown = self.state.get("phase") == "publishing"
        self.public = self.state.get("phase") in ("published", "complete")

    def save(self):
        with tempfile.NamedTemporaryFile(mode="w", dir=self.path.parent, prefix=".publication-", delete=False) as out:
            temporary = Path(out.name)
            json.dump(self.state, out, indent=2)
            out.write("\n")
            out.flush()
            os.fsync(out.fileno())
        os.replace(temporary, self.path)

    def inputs(self):
        return {"release_id": str(self.state["release_id"]), "tag": self.tag,
                "commit": self.commit, "build": str(self.build),
                "assets": json.dumps(self.state["assets"], separators=(",", ":"))}

    def wait(self, lookup, label, timeout=None):
        deadline = self.clock() + (self.timeout if timeout is None else timeout)
        previous = None
        while True:
            run = lookup()
            if run:
                status = (run["id"], run.get("status"), run.get("conclusion"))
                if status != previous:
                    print(f"{label}: run {status[0]}, {status[1]}, {status[2] or 'pending'}", flush=True)
                    previous = status
                if run.get("status") == "completed":
                    if run.get("conclusion") != "success":
                        raise PublicationError(f"{label} did not succeed ({run.get('conclusion')}); rerun run {run['id']} in GitHub, then resume")
                    return run
            remaining = deadline - self.clock()
            if remaining <= 0:
                raise PublicationError(f"Timed out waiting for {label}; saved run identity is retained")
            self.sleep(min(self.interval, remaining))

    def source_ci(self):
        def lookup():
            run_id = self.state.get("ci_run_id")
            if run_id:
                run = self.gh.api(f"actions/runs/{positive_id(run_id)}")
                if not matching_run(run, "ci.yml", self.commit, "main"):
                    raise PublicationError("Saved source CI run does not match this commit")
                return run
            query = urlencode({"event": "push", "branch": "main", "head_sha": self.commit, "per_page": 100})
            runs = self.gh.api(f"actions/workflows/ci.yml/runs?{query}")["workflow_runs"]
            matches = [run for run in runs if matching_run(run, "ci.yml", self.commit, "main")]
            if matches:
                run = max(matches, key=lambda run: run["id"])
                self.state["ci_run_id"] = positive_id(run["id"])
                self.save()
                return run
            return None
        run = self.wait(lookup, "Source CI")
        self.state["ci_verified_attempt"] = run.get("run_attempt", 1)
        self.save()
        return run

    def dispatch(self, kind, inputs):
        workflow = WORKFLOWS[kind]
        record = self.state["requests"].get(kind)
        if record is None:
            ref = "main" if kind == "deploy" else self.tag
            workflow_commit = (self.gh.api("git/ref/heads/main")["object"]["sha"]
                               if kind == "deploy" else self.commit)
            request_id = uuid.uuid4().hex
            record = {"request_id": request_id, "ref": ref, "commit": workflow_commit,
                      "title": f"FileMint {kind} {request_id}", "run_id": None}
            self.state["requests"][kind] = record
            self.save()  # An uncertain dispatch resumes discovery of this request, not a new one.
            try:
                self.gh.api(f"actions/workflows/{workflow}/dispatches", "POST",
                            {"ref": ref, "inputs": inputs | {"request_id": request_id}})
            except APIError as error:
                if error.status and 400 <= error.status < 500:
                    del self.state["requests"][kind]  # A rejected request did not create a run.
                    self.save()
                raise

        def lookup():
            if record["run_id"]:
                run = self.gh.api(f"actions/runs/{positive_id(record['run_id'])}")
                if not matching_run(run, workflow, record["commit"], record["ref"], record["title"]):
                    raise PublicationError(f"Saved {kind} run identity changed")
                return run
            query = urlencode({"event": "workflow_dispatch", "head_sha": record["commit"], "per_page": 100})
            runs = self.gh.api(f"actions/workflows/{workflow}/runs?{query}")["workflow_runs"]
            matches = [run for run in runs if matching_run(run, workflow, record["commit"], record["ref"], record["title"])]
            if len(matches) > 1:
                raise PublicationError(f"Ambiguous duplicate {kind} workflow requests")
            if matches:
                record["run_id"] = positive_id(matches[0]["id"])
                self.save()
                return matches[0]
            return None
        run = self.wait(lookup, kind)
        record["verified_attempt"] = run.get("run_attempt", 1)
        self.save()
        return run

    def website_required(self, previous):
        if previous is None:
            return True
        tag = previous["tag_name"]
        validate_identity(tag, self.commit)
        try:
            command(["git", "rev-parse", "--verify", f"refs/tags/{tag}^{{commit}}"])
        except PublicationError:
            command(["git", "fetch", "--no-tags", "origin", f"refs/tags/{tag}:refs/tags/{tag}"])
        return bool(command(["git", "diff", "--name-only", f"refs/tags/{tag}", self.commit, "--", *SITE_INPUTS]))

    def run(self):
        was_complete = self.state.get("phase") == "complete"
        release = (self.gh.api(f"releases/{positive_id(self.state['release_id'])}", missing_ok=True)
                   if self.state.get("release_id") else find_release(self.gh, self.tag))
        self.observed = True
        self.public = bool(release and release.get("draft") is False)
        self.unknown = False
        if self.public and self.state.get("phase") not in ("publishing", "published", "complete"):
            raise PublicationError("Release is already public without this journal's verified promotion; do not replace it")
        if release and release.get("draft") is True and not self.state.get("creation_started"):
            raise PublicationError("Existing draft is not owned by this publication journal")
        if "website_required" not in self.state:
            previous = self.gh.api("releases/latest", missing_ok=True)
            self.state["base_tag"] = previous["tag_name"] if previous else None
            self.state["website_required"] = self.website_required(previous)
            self.save()
        if not self.public:
            if resolve_tag_local := command(["git", "rev-parse", f"refs/tags/{self.tag}"]):
                remote_ref = command(["git", "ls-remote", "--tags", "origin", f"refs/tags/{self.tag}"])
                if remote_ref and remote_ref.split()[0] != resolve_tag_local:
                    raise PublicationError("Remote release tag differs from the local tag")
                command(["git", "push", "origin", "main"])
                if not remote_ref:
                    command(["git", "push", "origin", f"refs/tags/{self.tag}"])
            with tempfile.TemporaryDirectory(prefix="filemint-release-upload-") as temporary:
                upload = Path(temporary)
                feed = upload / "appcast.xml"
                feed.write_bytes(self.manifest_path.with_name(f"FileMint-{self.version}.appcast.xml").read_bytes())
                notes = upload / "release-notes.md"
                notes.write_text(command(["python3", "scripts/release_metadata.py", "notes", "--version", self.version]) + "\n")
                paths = [self.manifest_path.with_name(f"FileMint-{self.version}.dmg"),
                         self.manifest_path.with_name(f"FileMint-{self.version}.dmg.sha256"), feed]
                if release is None:
                    if self.state.get("release_id"):
                        raise PublicationError("Previously staged Release disappeared; do not recreate it")
                    self.state["creation_started"] = True
                    self.save()
                    try:
                        self.gh.create(self.tag, self.version, paths, notes)
                    except PublicationError:
                        # The CLI may have uploaded only some assets before losing the connection.
                        release = find_release(self.gh, self.tag)
                        if release is None:
                            raise
                    release = find_release(self.gh, self.tag)
                    if release is None:
                        raise PublicationError("Draft creation could not be confirmed; resume the saved journal")
                elif not self.state.get("creation_started"):
                    raise PublicationError("Existing draft is not owned by this publication journal")
                if release.get("draft") is not True:
                    self.public = True
                    raise PublicationError("Release became public before candidate verification")
                release_id = positive_id(release["id"])
                if self.state.get("release_id", release_id) != release_id:
                    raise PublicationError("Release ID changed")
                self.state["release_id"] = release_id
                present = asset_snapshot(release, self.tag, complete=False)
                if "assets" not in self.state:
                    missing = [path for path in paths if path.name not in {asset["name"] for asset in present}]
                    if missing:
                        self.gh.upload(self.tag, missing)
                    release = self.gh.api(f"releases/{release_id}")
                    self.state["assets"] = asset_snapshot(release, self.tag)
                    self.state["phase"] = "draft"
                    self.save()

            check_release(self.gh, self.state["release_id"], self.tag, self.commit, self.state["assets"], True)
            print(f"Draft uploaded; this version is not available for online updates: {self.tag}", flush=True)
            self.source_ci()
            self.dispatch("candidate", self.inputs())
            if self.state["website_required"]:
                run = self.dispatch("site", {"tag": self.tag, "commit": self.commit})
                self.state["site_artifact"] = site_artifact(self.gh, run["id"])
                self.save()
            # A cancelled/restarted run must not be masked by an earlier observation.
            self.source_ci()
            self.dispatch("candidate", self.inputs())
            if self.state["website_required"]:
                run = self.dispatch("site", {"tag": self.tag, "commit": self.commit})
                if site_artifact(self.gh, run["id"]) != self.state["site_artifact"]:
                    raise PublicationError("Website build artifact changed before publication")
            check_release(self.gh, self.state["release_id"], self.tag, self.commit, self.state["assets"], True)
            self.state["phase"] = "publishing"
            self.save()
            self.unknown = True
            try:
                self.gh.api(f"releases/{self.state['release_id']}", "PATCH",
                            {"draft": False, "prerelease": False, "make_latest": "true"})
            except (PublicationError, subprocess.TimeoutExpired):
                release = self.gh.api(f"releases/{self.state['release_id']}")
                self.public = release.get("draft") is False
                self.unknown = False
                if not self.public:
                    self.state["phase"] = "draft"
                    self.save()
                    raise PublicationError("Publication request did not make the draft public; resume to retry")
            else:
                release = self.gh.api(f"releases/{self.state['release_id']}")
                self.public = release.get("draft") is False
                self.unknown = False
            if not self.public:
                raise PublicationError("GitHub did not confirm public Release status")

        self.state["phase"] = "published"
        self.save()
        check_public(self.gh, self.state["release_id"], self.tag, self.commit, self.state["assets"])
        print(f"Published and confirmed Latest online-update availability: {self.tag}", flush=True)
        if was_complete:
            self.state["phase"] = "complete"
            self.save()
            print(f"Release workflow already complete: {self.tag}", flush=True)
            return
        if self.state["website_required"]:
            site = self.state["requests"]["site"]
            self.dispatch("site", {"tag": self.tag, "commit": self.commit})
            artifact = site_artifact(self.gh, site["run_id"])
            if artifact != self.state["site_artifact"]:
                # A successful rerun of the same source build may replace an expired artifact.
                previous = self.state["requests"].get("deploy")
                if previous:
                    if not previous["run_id"] or self.gh.api(f"actions/runs/{positive_id(previous['run_id'])}")["status"] != "completed":
                        raise PublicationError("Previous website deployment is unresolved; finish it before changing artifacts")
                    self.state.setdefault("past_deployments", []).append(previous)
                    del self.state["requests"]["deploy"]
                self.state["site_artifact"] = artifact
                self.save()
            inputs = self.inputs() | {"build_run_id": str(site["run_id"]),
                                     "build_request_id": site["request_id"],
                                     "artifact_id": str(self.state["site_artifact"]["id"])}
            self.dispatch("deploy", inputs)
        else:
            print("Website inputs unchanged; deployment is not applicable.", flush=True)
        self.state["phase"] = "complete"
        self.save()
        print(f"Release workflow complete: {self.tag}", flush=True)


def workflow_inputs():
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise PublicationError("Remote asset downloads are restricted to GitHub Actions runners")
    inputs = json.loads(os.environ["FILEMINT_PUBLICATION_INPUTS"])
    validate_identity(inputs["tag"], inputs["commit"], inputs.get("build"))
    if command(["git", "rev-parse", "HEAD"]) != inputs["commit"]:
        raise PublicationError("Workflow checkout differs from the requested release commit")
    return inputs


def verify_candidate():
    inputs = workflow_inputs()
    gh = GitHub()
    snapshot = json.loads(inputs["assets"])
    tag, commit = inputs["tag"], inputs["commit"]
    release_id = positive_id(inputs["release_id"])
    release = check_release(gh, release_id, tag, commit, snapshot, True)
    command(["python3", "scripts/release_metadata.py", "check", "--version", tag[1:], "--build", inputs["build"]])
    with tempfile.TemporaryDirectory(prefix="filemint-candidate-") as temporary:
        work = Path(temporary)
        for asset in release["assets"]:
            with (work / asset["name"]).open("wb") as output:
                subprocess.run(["gh", "api", f"{API}/releases/assets/{positive_id(asset['id'])}",
                                "-H", "Accept: application/octet-stream"], stdout=output, check=True, timeout=600)
            if (work / asset["name"]).stat().st_size != asset["size"]:
                raise PublicationError("Downloaded asset size differs from update discovery metadata")
        subprocess.run(["bash", "scripts/verify_release_artifact.sh", str(work / f"FileMint-{tag[1:]}.dmg"),
                        tag[1:], inputs["build"], str(work / "appcast.xml")], cwd=ROOT, check=True)
    check_release(gh, release_id, tag, commit, snapshot, True)
    print("Draft candidate passed checksum, signing, notarization and Sparkle installation checks.")


def prepare_site_deployment():
    inputs = workflow_inputs()
    gh = GitHub()
    snapshot = json.loads(inputs["assets"])
    check_public(gh, positive_id(inputs["release_id"]), inputs["tag"], inputs["commit"], snapshot)
    run_id = positive_id(inputs["build_run_id"])
    run = gh.api(f"actions/runs/{run_id}")
    if (not matching_run(run, WORKFLOWS["site"], inputs["commit"], inputs["tag"], f"FileMint site {inputs['build_request_id']}")
            or run.get("status") != "completed" or run.get("conclusion") != "success"):
        raise PublicationError("Website build is not the verified release build")
    if site_artifact(gh, run_id)["id"] != positive_id(inputs["artifact_id"]):
        raise PublicationError("Website artifact identity changed")
    directory = Path(os.environ["RUNNER_TEMP"]) / f"filemint-pages-{uuid.uuid4().hex}"
    directory.mkdir()
    command(["gh", "run", "download", str(run_id), "--repo", REPO, "--name", "github-pages", "--dir", str(directory)])
    archive = directory / "artifact.tar"
    if list(directory.iterdir()) != [archive] or archive.is_symlink() or not archive.is_file() or archive.stat().st_size <= 0:
        raise PublicationError("Unexpected website artifact archive")
    with open(os.environ["GITHUB_OUTPUT"], "a") as out:
        out.write(f"archive={archive}\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("local", "candidate", "deploy"))
    parser.add_argument("manifest", nargs="?", type=Path)
    args = parser.parse_args()
    publication = None
    try:
        if args.mode == "candidate":
            verify_candidate()
        elif args.mode == "deploy":
            prepare_site_deployment()
        else:
            if args.manifest is None:
                parser.error("local mode requires the verified source manifest")
            lock_path = args.manifest.with_suffix(".publication.lock")
            with lock_path.open("a") as lock:
                try:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError as error:
                    raise PublicationError("Another publication process owns this candidate") from error
                publication = Publication(args.manifest)
                publication.run()
    except (PublicationError, OSError, ValueError, KeyError, subprocess.SubprocessError, KeyboardInterrupt) as error:
        if publication and publication.unknown:
            status = "Publication status is unknown; query GitHub and resume the saved journal before retrying"
        elif publication and publication.public:
            status = "Release is already published; online-update confirmation or website follow-up failed; keep its assets intact"
        elif publication and publication.observed:
            status = "Pre-publication work stopped; retain the candidate and draft"
        else:
            status = "Publication stopped before remote status could be confirmed"
        print(f"{status}: {error}", file=sys.stderr)
        return 130 if isinstance(error, KeyboardInterrupt) else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
