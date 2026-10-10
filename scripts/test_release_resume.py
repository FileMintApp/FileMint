#!/usr/bin/env python3
"""Check release source binding with a disposable Git repo and offline adapters."""
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class ReleaseSourceResumeTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name).resolve()
        self.repo = self.work / "repo"
        self.scripts = self.repo / "scripts"
        self.scripts.mkdir(parents=True)
        self.log = self.work / "calls.log"
        self.log.write_text("")
        for name in ("release_local.sh", "release_metadata.py"):
            shutil.copyfile(ROOT / "scripts" / name, self.scripts / name)
        (self.repo / "project.yml").write_text("settings:\n  base:\n    MARKETING_VERSION: 0.6.5\n    CURRENT_PROJECT_VERSION: 24\n")
        (self.repo / "docs").mkdir()
        (self.repo / "docs/RELEASE_NOTES.md").write_text("# FileMint 0.6.5\n\nFixture release.\n")
        (self.repo / ".gitignore").write_text("build/\nConfig/Signing/\n")
        certificate = self.repo / "Config/Signing/DeveloperIDApplication-8S66M2ZLD5.cer"
        certificate.parent.mkdir(parents=True)
        certificate.write_bytes(b"synthetic certificate")
        for name, body in {
            "notarize_dmg.sh": 'echo notarize >> "$FILEMINT_RELEASE_TEST_LOG"\n',
            "verify_release_artifact.sh": 'echo artifact >> "$FILEMINT_RELEASE_TEST_LOG"\n',
            "verify_release_pair.sh": 'echo pair >> "$FILEMINT_RELEASE_TEST_LOG"\n',
            "package_release_zip.sh": '''echo zip >> "$FILEMINT_RELEASE_TEST_LOG"
printf 'ZIP from the same DMG' > "${1%.dmg}.zip"
(cd "$(dirname "$1")" && shasum -a 256 "$(basename "${1%.dmg}.zip")") > "${1%.dmg}.zip.sha256"
''',
            "sparkle_tools.sh": 'echo sparkle >> "$FILEMINT_RELEASE_TEST_LOG"\n',
            "package_release.sh": '''echo package >> "$FILEMINT_RELEASE_TEST_LOG"
printf 'built from %s\\n' "$(git rev-parse HEAD)" > "$FILEMINT_OUTPUT_DIR/FileMint-0.6.5.dmg"
printf '{"id":"12345678-1234-1234-1234-123456789abc"}' > "$FILEMINT_OUTPUT_DIR/FileMint-0.6.5.dmg.notary.json"
exit 1
''',
        }.items():
            (self.scripts / name).write_text("#!/bin/bash\nset -euo pipefail\n" + body)
        (self.scripts / "update_appcast.py").write_text(
            'import pathlib,sys\npathlib.Path(sys.argv[5]).write_text("synthetic appcast")\n')
        stubs = self.work / "bin"
        stubs.mkdir()
        for name, body in {
            "gh": '''echo github >> "$FILEMINT_RELEASE_TEST_LOG"
if [[ "$1 $2" == "release view" ]]; then echo v0.6.4; exit 0; fi
if [[ "$1 $2" != "release download" ]]; then exit 99; fi
while [[ "$1" != "--dir" ]]; do shift; done
cat > "$2/appcast.xml" <<'XML'
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item><sparkle:shortVersionString>0.6.4</sparkle:shortVersionString><sparkle:version>23</sparkle:version></item></channel></rss>
XML
''',
            "openssl": 'echo certificate >> "$FILEMINT_RELEASE_TEST_LOG"\n',
            "xcrun": 'echo apple >> "$FILEMINT_RELEASE_TEST_LOG"\n',
            "make": 'echo verify >> "$FILEMINT_RELEASE_TEST_LOG"\n',
        }.items():
            path = stubs / name
            path.write_text("#!/bin/bash\nset -euo pipefail\n" + body)
            path.chmod(0o755)
        self.env = {
            "PATH": f"{stubs}:{os.environ['PATH']}",
            "APPLE_NOTARY_KEYCHAIN_PROFILE": "synthetic-fixture",
            "FILEMINT_RELEASE_TEST_LOG": str(self.log),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
        }
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "release-test@example.invalid")
        self.git("config", "core.hooksPath", os.devnull)
        self.git("add", ".")
        self.git("commit", "-qm", "fixture source A")
        self.git("tag", "v0.6.5")
        self.commit = self.git("rev-parse", "HEAD").strip()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.repo, env=self.env,
                              capture_output=True, text=True, check=True, timeout=30).stdout

    def run_script(self, stage=None):
        environment = self.env.copy()
        if stage is not None:
            environment["FILEMINT_RESUME_STAGE"] = str(stage)
        return subprocess.run(["bash", str(self.scripts / "release_local.sh")], cwd=self.repo,
                              env=environment, capture_output=True, text=True, timeout=30)

    def interrupted_build(self):
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("retained staging files", result.stderr)
        stages = list((self.repo / "build/local-release-work.noindex").iterdir())
        self.assertEqual(len(stages), 1)
        stage = stages[0]
        self.assertEqual(json.loads((stage / "source.json").read_text()), {
            "version": "0.6.5", "build": "24", "tag": "v0.6.5", "commit": self.commit,
        })
        return stage

    def test_same_source_resumes_exact_retained_bytes_without_rebuilding(self):
        stage = self.interrupted_build()
        original = (stage / "FileMint-0.6.5.dmg").read_bytes()
        self.log.write_text("")
        result = self.run_script(stage)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.repo / "build/FileMint-0.6.5.dmg").read_bytes(), original)
        manifest = json.loads((self.repo / "build/FileMint-0.6.5.release.json").read_text())
        self.assertEqual(manifest["commit"], self.commit)
        self.assertEqual(len(manifest["zipSHA256"]), 64)
        self.assertEqual(len(manifest["zipAppcastSHA256"]), 64)
        self.assertTrue((self.repo / "build/FileMint-0.6.5.zip.sha256").exists())
        self.assertTrue((self.repo / "build/FileMint-0.6.5.appcast-zip.xml").exists())
        self.assertIn("zip", self.log.read_text().splitlines())
        self.assertIn("pair", self.log.read_text().splitlines())
        self.assertNotIn("package", self.log.read_text().splitlines())
        self.assertNotIn("verify", self.log.read_text().splitlines())
        self.assertFalse(stage.exists())

    def test_other_commit_with_same_version_and_retargeted_tag_is_rejected(self):
        stage = self.interrupted_build()
        original = (stage / "FileMint-0.6.5.dmg").read_bytes()
        (self.repo / "changed-source.txt").write_text("source B, same version/build")
        self.git("add", "changed-source.txt")
        self.git("commit", "-qm", "fixture source B")
        self.git("tag", "-f", "v0.6.5")
        self.log.write_text("")
        result = self.run_script(stage)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Retained release source", result.stderr)
        self.assertEqual(self.log.read_text(), "")
        self.assertEqual((stage / "FileMint-0.6.5.dmg").read_bytes(), original)
        self.assertEqual(json.loads((stage / "source.json").read_text())["commit"], self.commit)
        self.assertFalse((self.repo / "build/FileMint-0.6.5.release.json").exists())

    def test_missing_malformed_or_mismatched_record_is_preserved_and_rejected(self):
        stage = self.interrupted_build()
        record = stage / "source.json"
        valid = json.loads(record.read_text())
        invalid = [None, "{broken", "null"] + [json.dumps(valid | {key: "different"})
                                               for key in ("version", "build", "tag", "commit")]
        for value in invalid:
            with self.subTest(value=value):
                if value is None:
                    record.unlink()
                else:
                    record.write_text(value)
                self.log.write_text("")
                result = self.run_script(stage)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Retained release source", result.stderr)
                self.assertEqual(self.log.read_text(), "")
                self.assertTrue((stage / "FileMint-0.6.5.dmg").exists())
                if value is None:
                    self.assertFalse(record.exists())
                else:
                    self.assertEqual(record.read_text(), value)


if __name__ == "__main__":
    unittest.main()
