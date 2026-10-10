#!/usr/bin/env python3
"""Check stable native QA identity/publication without certificates or UI access."""
import fcntl
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
import native_qa as qa
import access_migration_fixture as access_fixture


class NativeQATests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        (self.root / "build").mkdir()
        self.kind = "resource-tools"
        self.active = []
        self.fail_signing = False
        self.requirement = 'designated => identifier "fixture" and certificate leaf[subject.OU] = "QA-TEAM"'
        self.identity = qa.DEFAULT_IDENTITY
        self.calls = []
        self.addCleanup(patch.stopall)
        patch.object(qa, "ROOT", self.root).start()
        patch.object(qa, "command", side_effect=self.command).start()
        patch.dict(os.environ, {"FILEMINT_QA_CODESIGN_IDENTITY": qa.DEFAULT_IDENTITY}).start()

    def command(self, args):
        args = list(map(str, args))
        self.calls.append(args)
        if args[0] == "xcrun":
            return json.dumps(self.active)
        if args[0] == "ditto":
            shutil.copytree(args[1], args[2], symlinks=True)
        elif args[:2] == ["codesign", "--force"]:
            if self.fail_signing:
                raise qa.QAError("fixture signing failed")
        elif args[:2] == ["codesign", "-d"]:
            identifier = qa.read_info(Path(args[-1]))["CFBundleIdentifier"]
            return f"Authority={self.identity}\nIdentifier={identifier}\n{self.requirement}\n"
        else:
            self.assertEqual(args[:2], ["codesign", "--verify"])
        return ""

    def source(self, name="run.first", kind=None, payload=b"first", run_id=False):
        kind = kind or self.kind
        root = self.root / "build" / name
        app = root / qa.KINDS[kind][0]
        (app / "Contents/MacOS").mkdir(parents=True)
        info = dict(CFBundleIdentifier=qa.KINDS[kind][1], CFBundleExecutable="Fixture",
                    FixturePath=str(root / "fixtures"))
        if run_id:
            info["FixtureRunID"] = root.name
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
        (app / "Contents/MacOS/Fixture").write_bytes(b"\xcf\xfa\xed\xfe" + payload)
        return app, root

    def publish(self, name="run.first", payload=b"first"):
        source, root = self.source(name, payload=payload)
        return qa.publish(self.kind, source, root)

    def test_each_kind_has_a_distinct_stable_non_production_identity_and_path(self):
        self.assertEqual(len(qa.KINDS), 9)
        identifiers = [value[1] for value in qa.KINDS.values()]
        self.assertEqual(len(set(identifiers)), 9)
        self.assertNotIn("io.github.daigua.filemint", identifiers)
        self.assertEqual(qa.KINDS["design-ui"][1], "io.github.daigua.filemint.design-qa")
        self.assertEqual(qa.KINDS["sparkle-installation"][1], "io.github.daigua.filemint.upgrade-qa")
        for kind, (name, identifier, _) in qa.KINDS.items():
            self.assertEqual(qa.app_path(kind), self.root / "build/native-qa.noindex" / kind / name)
            self.assertFalse(identifier.endswith("run.first"))

    def test_two_builds_reuse_identity_path_and_requirement_but_isolate_run_data(self):
        destination = self.publish()
        pin = (destination.parent / "identity.json").read_bytes()
        first = qa.read_info(destination)
        second_destination = self.publish("run.second", b"second")
        self.assertEqual(destination, second_destination)
        self.assertEqual((destination.parent / "identity.json").read_bytes(), pin)
        second = qa.read_info(destination)
        self.assertEqual(first["CFBundleIdentifier"], second["CFBundleIdentifier"])
        self.assertNotEqual(first["FixtureRunID"], second["FixtureRunID"])
        self.assertNotEqual(first["FixturePath"], second["FixturePath"])
        self.assertNotIn("FixtureRunID", qa.read_info(self.root / "build/run.first/FileMintResourceQA.app"))
        self.assertFalse(list(destination.parent.glob(".previous-*.app")))

    def test_running_app_or_receiver_and_concurrent_publisher_preserve_the_current_app(self):
        destination = self.publish()
        original = (destination / "Contents/MacOS/Fixture").read_bytes()
        for active in ([qa.KINDS[self.kind][1]], ["receiver"]):
            self.active = active
            source, root = self.source("run.active" + str(len(self.calls)))
            with self.assertRaisesRegex(qa.QAError, "Close this QA"):
                qa.publish(self.kind, source, root)
            self.assertEqual((destination / "Contents/MacOS/Fixture").read_bytes(), original)
        self.active = []
        with (destination.parent / "publish.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with self.assertRaisesRegex(qa.QAError, "Another publisher"):
                self.publish("run.locked")
        self.assertEqual((destination / "Contents/MacOS/Fixture").read_bytes(), original)

    def test_signing_failure_and_changed_requirement_or_identity_preserve_the_good_app(self):
        destination = self.publish()
        original = (destination / "Contents/MacOS/Fixture").read_bytes()
        self.fail_signing = True
        with self.assertRaisesRegex(qa.QAError, "signing failed"):
            self.publish("run.failed")
        self.fail_signing = False
        self.requirement += " and changed"
        with self.assertRaisesRegex(qa.QAError, "Pinned QA identity changed"):
            self.publish("run.changed-requirement")
        self.identity = "Developer ID Application: Different Owner (OTHER)"
        with self.assertRaisesRegex(qa.QAError, "signing identity"):
            self.publish("run.changed-signer")
        self.assertEqual((destination / "Contents/MacOS/Fixture").read_bytes(), original)

    def test_rejected_bundle_identity_and_unowned_destination_are_not_overwritten(self):
        source, root = self.source()
        info = qa.read_info(source)
        info["CFBundleIdentifier"] = "io.github.daigua.filemint"
        (source / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
        with self.assertRaisesRegex(qa.QAError, "fixed kind"):
            qa.publish(self.kind, source, root)
        source, root = self.source("run.good")
        destination = qa.app_path(self.kind)
        destination.mkdir()
        (destination / "keep").write_text("unowned file")
        with self.assertRaisesRegex(qa.QAError, "no owned identity record"):
            qa.publish(self.kind, source, root)
        self.assertEqual((destination / "keep").read_text(), "unowned file")

    def test_symlink_source_and_stable_directory_cannot_redirect_publication(self):
        source, root = self.source()
        alias = root / "Alias.app"
        alias.symlink_to(source)
        with self.assertRaisesRegex(qa.QAError, "symlinks"):
            qa.publish(self.kind, alias, root)
        external = self.root / "external"
        external.mkdir()
        (self.root / "build/native-qa.noindex").symlink_to(external)
        with self.assertRaisesRegex(qa.QAError, "symlinks"):
            qa.publish(self.kind, source, root)
        self.assertEqual(list(external.iterdir()), [])

    def test_nested_code_is_signed_before_the_host_without_changing_entitlement_or_runtime_flags(self):
        source, root = self.source()
        nested = source / "Contents/Frameworks/Runtime.framework"
        (nested / "Versions/A").mkdir(parents=True)
        (nested / "Versions/A/Runtime").write_bytes(b"\xcf\xfa\xed\xfeframework")
        qa.publish(self.kind, source, root)
        signs = [args for args in self.calls if args[:2] == ["codesign", "--force"]]
        self.assertEqual(Path(signs[-1][-1]).name, source.name)
        self.assertTrue(all("--preserve-metadata=entitlements,flags" in args for args in signs))
        self.assertTrue(all("--options" not in args for args in signs))
        self.assertLess(next(i for i, args in enumerate(signs) if args[-1].endswith("/Runtime.framework/Versions/A/Runtime")),
                        next(i for i, args in enumerate(signs) if args[-1].endswith("/Runtime.framework")))

    def test_installer_host_keeps_presigned_bytes_and_run_identity(self):
        kind = "sparkle-installation"
        source, root = self.source(kind=kind, run_id=True)
        original = (source / "Contents/Info.plist").read_bytes()
        destination = qa.publish(kind, source, root, already_signed=True)
        self.assertEqual((destination / "Contents/Info.plist").read_bytes(), original)
        self.assertFalse(any(args[:2] == ["codesign", "--force"] for args in self.calls))
        source, root = self.source("run.missing", kind=kind)
        with self.assertRaisesRegex(qa.QAError, "different fixture run ID"):
            qa.publish(kind, source, root, already_signed=True)

    def test_access_migration_keeps_presigned_archive_session(self):
        kind = "access-migration"
        source, root = self.source(kind=kind, run_id=True)
        original = (source / "Contents/Info.plist").read_bytes()
        destination = qa.publish(kind, source, root, already_signed=True)
        self.assertEqual((destination / "Contents/Info.plist").read_bytes(), original)
        self.assertFalse(any(args[:2] == ["codesign", "--force"] for args in self.calls))

    def test_failed_swap_restores_the_previous_app_and_failed_rollback_retains_its_backup(self):
        destination = self.publish()
        original = (destination / "Contents/MacOS/Fixture").read_bytes()
        replace = os.replace
        fail_rollback = False
        def failure(source, target):
            source, target = Path(source), Path(target)
            if target == destination and (source.name == destination.name or (fail_rollback and source.name.startswith(".previous-"))):
                raise OSError("fixture rename failure")
            return replace(source, target)
        with patch.object(qa.os, "replace", side_effect=failure):
            with self.assertRaises(OSError):
                self.publish("run.rename")
            self.assertEqual((destination / "Contents/MacOS/Fixture").read_bytes(), original)
            fail_rollback = True
            with self.assertRaisesRegex(qa.QAError, "previous verified app retained"):
                self.publish("run.rollback")
        backups = list(destination.parent.glob(".previous-*.app"))
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / "Contents/MacOS/Fixture").read_bytes(), original)

    def test_adhoc_identity_is_rejected_instead_of_silently_losing_persistence(self):
        with patch.dict(os.environ, {"FILEMINT_QA_CODESIGN_IDENTITY": "-"}), self.assertRaises(qa.QAError):
            qa.signing_identity()

    def opening_runner(self):
        scripts = self.root / "scripts"
        scripts.mkdir()
        shutil.copyfile(qa.__file__, scripts / "native_qa.py")
        runner = scripts / "run_creation_opening_checks.sh"
        text = Path(__file__).with_name(runner.name).read_text()
        # Exercise the real shell entry point without changing LaunchServices.
        registrar = self.root / "fixture-lsregister"
        registration_path = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        self.assertEqual(text.count(registration_path), 1)
        runner.write_text(text.replace(registration_path, str(registrar)))
        registrar.write_text("""#!/usr/bin/env python3
import json, os, sys
with open(os.environ['FILEMINT_TEST_OPENING_LOG'], 'a') as output:
    output.write(json.dumps(['register', *sys.argv[1:]]) + '\\n')
""")
        registrar.chmod(0o755)
        log = self.root / "opening-events.jsonl"
        environment = dict(os.environ, FILEMINT_TEST_OPENING_LOG=str(log))
        return runner, log, environment

    def test_opening_runner_accepts_published_path_and_cleans_up_on_success_or_failure(self):
        source, run = self.source(kind="template-workflow")
        destination = qa.publish("template-workflow", source, run)
        host = destination / "Contents/MacOS/TemplateWorkflowSmoke"
        host.write_text("""#!/usr/bin/env python3
import json, os, sys
with open(os.environ['FILEMINT_TEST_OPENING_LOG'], 'a') as output:
    output.write(json.dumps(['launch', sys.argv[0], os.environ.get('FILEMINT_TEMPLATE_QA_MODE')]) + '\\n')
sys.exit(int(os.environ['FILEMINT_TEST_OPENING_EXIT']))
""")
        host.chmod(0o755)
        runner, log, environment = self.opening_runner()
        receiver = str(destination / "Contents/Resources/TemplateReceiver.app")
        for exit_code in (0, 9):
            with self.subTest(exit_code=exit_code):
                log.write_text("")
                result = subprocess.run(["bash", str(runner), str(destination)], text=True,
                                        capture_output=True, timeout=10,
                                        env=dict(environment, FILEMINT_TEST_OPENING_EXIT=str(exit_code)))
                self.assertEqual(result.returncode, exit_code, result.stderr)
                self.assertEqual([json.loads(line) for line in log.read_text().splitlines()], [
                    ["register", "-f", receiver], ["launch", str(host), "opening"],
                    ["register", "-u", receiver],
                ])

    def test_opening_runner_rejects_staging_and_other_apps_before_registration(self):
        source, _ = self.source(kind="template-workflow")
        runner, log, environment = self.opening_runner()
        for app in (source, qa.app_path("design-ui"), self.root / "build/DerivedData/FileMint.app"):
            with self.subTest(app=app):
                result = subprocess.run(["bash", str(runner), str(app)], text=True,
                                        capture_output=True, timeout=10, env=environment)
                self.assertEqual(result.returncode, 64, result.stderr)
                self.assertIn("Expected the stable template workflow QA bundle", result.stderr)
                self.assertFalse(log.exists(), "Rejected app reached registration or launch")


class AccessMigrationTests(unittest.TestCase):
    def test_only_candidate_host_loses_sandbox_and_finder_keeps_no_network(self):
        old = access_fixture.entitlements(True)
        new = access_fixture.entitlements(False)
        finder = access_fixture.entitlements(True, extension=True)
        self.assertTrue(old["com.apple.security.app-sandbox"])
        self.assertEqual(new, {})
        self.assertTrue(finder["com.apple.security.app-sandbox"])
        self.assertNotIn("com.apple.security.network.client", finder)
        self.assertEqual(old["com.apple.security.temporary-exception.mach-lookup.global-name"],
                         [access_fixture.IDENTIFIER + "-spks", access_fixture.IDENTIFIER + "-spki"])
        for entitlements in (old, finder):
            self.assertEqual(entitlements["com.apple.security.temporary-exception.files.home-relative-path.read-write"],
                             ["/Library/Application Support/FileMintAccessQA/"])

    def test_fixture_cannot_sign_production_or_another_qa_run(self):
        valid = qa.ROOT / "build/access-migration-harness.noindex/run.fixture"
        self.assertEqual(access_fixture.validate_root(valid), valid)
        for path in (qa.ROOT, qa.ROOT / "build/DerivedData", qa.ROOT / "build/other/run.fixture",
                     qa.ROOT / "build/access-migration-harness.noindex/production"):
            with self.subTest(path=path), self.assertRaises(ValueError):
                access_fixture.validate_root(path)


if __name__ == "__main__":
    unittest.main()
