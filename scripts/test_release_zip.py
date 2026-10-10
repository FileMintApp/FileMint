#!/usr/bin/env python3
"""Exercise ZIP packaging, safe extraction and both release paths offline."""
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import warnings
import zipfile

sys.dont_write_bytecode = True
import verify_release_zip as validator

ROOT = Path(__file__).resolve().parent.parent


class ZipLayoutTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)
        self.archive = self.work / "FileMint-0.6.0.zip"

    def write(self, entries=()):
        with zipfile.ZipFile(self.archive, "w") as archive, warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            archive.writestr("FileMint.app/Contents/Info.plist", "fixture")
            archive.writestr("FileMint.app/Contents/MacOS/FileMint", "executable")
            for name, data, symlink in entries:
                info = zipfile.ZipInfo(name)
                info.external_attr = ((stat.S_IFLNK | 0o755) if symlink else (stat.S_IFREG | 0o644)) << 16
                archive.writestr(info, data)

    def test_framework_links_and_ditto_resource_metadata_are_accepted(self):
        self.write([
            ("FileMint.app/Contents/Frameworks/Sparkle.framework/Versions/Current", "B", True),
            ("FileMint.app/Contents/Frameworks/Sparkle.framework/Sparkle", "Versions/Current/Sparkle", True),
            ("FileMint.app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle", "binary", False),
            ("__MACOSX/._FileMint.app", "resource metadata", False),
            ("__MACOSX/FileMint.app/Contents/._Info.plist", "resource metadata", False),
        ])
        validator.validate_archive(self.archive)

    def test_escaping_paths_links_and_non_app_payloads_are_rejected(self):
        for entry in [
            ("../outside", "file", False), ("/tmp/outside", "file", False),
            ("FileMint.app/../outside", "file", False), ("FileMint.app\\outside", "file", False),
            ("Applications", "/Applications", True), ("Other.app/Contents/Info.plist", "file", False),
            ("FileMint.app/link", "/tmp", True), ("FileMint.app/link", "../../outside", True),
            ("__MACOSX/FileMint.app/link", "/tmp", True),
        ]:
            with self.subTest(entry=entry):
                self.write([entry])
                with self.assertRaises(ValueError):
                    validator.validate_archive(self.archive)

    def test_payload_below_a_symlink_duplicates_and_expansion_limit_are_rejected(self):
        self.write([("FileMint.app/link", "Contents", True), ("FileMint.app/link/injected", "file", False)])
        with self.assertRaisesRegex(ValueError, "traverses"):
            validator.validate_archive(self.archive)
        self.write([("FileMint.app/Contents/Info.plist", "duplicate", False)])
        with self.assertRaisesRegex(ValueError, "duplicate"):
            validator.validate_archive(self.archive)
        self.write()
        with patch.object(validator, "MAXIMUM_SIZE", 1), self.assertRaisesRegex(ValueError, "expanded size"):
            validator.validate_archive(self.archive)

    def test_ditto_round_trip_preserves_framework_links_and_executable_permissions(self):
        app = self.work / "FileMint.app"
        executable = app / "Contents/MacOS/FileMint"
        executable.parent.mkdir(parents=True)
        executable.write_text("fixture executable")
        executable.chmod(0o755)
        (app / "Contents/Info.plist").write_text("fixture info")
        framework = app / "Contents/Frameworks/Sparkle.framework"
        (framework / "Versions/B").mkdir(parents=True)
        (framework / "Versions/B/Sparkle").write_text("framework fixture")
        (framework / "Versions/Current").symlink_to("B")
        (framework / "Sparkle").symlink_to("Versions/Current/Sparkle")
        env = os.environ | {"ZIP_PATH": str(self.archive)}
        subprocess.run(["bash", str(ROOT / "scripts/make_zip.sh"), str(app)], env=env, check=True, capture_output=True)
        extracted = self.work / "extract"
        subprocess.run(["ditto", "-x", "-k", str(self.archive), str(extracted)], check=True)
        result = extracted / "FileMint.app/Contents"
        self.assertEqual(os.readlink(result / "Frameworks/Sparkle.framework/Versions/Current"), "B")
        self.assertEqual(os.readlink(result / "Frameworks/Sparkle.framework/Sparkle"), "Versions/Current/Sparkle")
        self.assertEqual((result / "MacOS/FileMint").stat().st_mode & 0o777, 0o755)


class PackagingResumeTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)
        self.scripts = self.work / "scripts"
        self.scripts.mkdir()
        for name in ("package_release_zip.sh", "make_zip.sh", "verify_release_zip.py", "verify_release_pair.sh"):
            shutil.copyfile(ROOT / "scripts" / name, self.scripts / name)
        (self.scripts / "verify_bundle.sh").write_text('echo bundle >> "$FILEMINT_ZIP_TEST_LOG"\n')
        self.log = self.work / "calls.log"
        self.dmg = self.work / "FileMint-0.6.0.dmg"
        self.dmg.write_bytes(b"signed and accepted DMG fixture")
        self.zip = self.dmg.with_suffix(".zip")
        bin_path = self.work / "bin"
        bin_path.mkdir()
        for name, body in {
            "hdiutil": '''echo "hdiutil $1" >> "$FILEMINT_ZIP_TEST_LOG"
if [[ "$1" == attach ]]; then
  while [[ "$1" != -mountpoint ]]; do shift; done
  app="$2/FileMint.app"
  mkdir -p "$app/Contents/MacOS"
  printf 'executable fixture' > "$app/Contents/MacOS/FileMint"
  chmod 755 "$app/Contents/MacOS/FileMint"
  printf 'info fixture' > "$app/Contents/Info.plist"
fi
''',
            "xcrun": '''echo "$1 $2 $(basename "$3")" >> "$FILEMINT_ZIP_TEST_LOG"
if [[ "$1 $2" == "stapler staple" ]]; then
  if [[ "${FAIL_STAPLE:-0}" == 1 ]]; then exit 1; fi
  printf 'stapled ticket fixture' > "$3/Contents/FixtureTicket"
fi
''',
        }.items():
            path = bin_path / name
            path.write_text("#!/bin/bash\nset -euo pipefail\n" + body)
            path.chmod(0o755)
        self.env = os.environ | {"PATH": f"{bin_path}:{os.environ['PATH']}", "NOTARIZE": "1",
                                 "FILEMINT_ZIP_TEST_LOG": str(self.log)}

    def package(self, **extra):
        return subprocess.run(["bash", str(self.scripts / "package_release_zip.sh"), str(self.dmg)],
                              env=self.env | extra, text=True, capture_output=True, timeout=30)

    def test_same_dmg_app_is_stapled_before_zip_and_resume_preserves_exact_bytes(self):
        result = self.package()
        self.assertEqual(result.returncode, 0, result.stderr)
        with zipfile.ZipFile(self.zip) as archive:
            self.assertEqual(archive.read("FileMint.app/Contents/FixtureTicket"), b"stapled ticket fixture")
        self.assertIn("stapler staple FileMint.app", self.log.read_text())
        self.assertNotIn("notarytool", self.log.read_text())
        original, calls = self.zip.read_bytes(), self.log.read_text()
        # Recover an interruption between the immutable ZIP and checksum write.
        Path(str(self.zip) + ".sha256").unlink()
        result = self.package()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.zip.read_bytes(), original)
        self.assertEqual(self.log.read_text(), calls)
        self.assertTrue(Path(str(self.zip) + ".sha256").exists())
        self.assertFalse(list(self.work.glob("*.stage.*")))

    def test_changed_zip_or_source_dmg_cannot_be_reused_or_replaced(self):
        self.assertEqual(self.package().returncode, 0)
        original = self.zip.read_bytes()
        self.zip.write_bytes(original + b"tampered")
        self.assertNotEqual(self.package().returncode, 0)
        self.assertEqual(self.zip.read_bytes(), original + b"tampered")
        self.zip.write_bytes(original)
        self.dmg.write_bytes(b"different source DMG")
        self.assertNotEqual(self.package().returncode, 0)
        self.assertEqual(self.zip.read_bytes(), original)

    def test_failed_stapling_publishes_no_zip_and_retry_needs_no_resubmission(self):
        self.assertNotEqual(self.package(FAIL_STAPLE="1").returncode, 0)
        self.assertFalse(self.zip.exists())
        self.assertFalse(list(self.work.glob("*.stage.*")))
        result = self.package()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("notarytool", self.log.read_text())

    def pair(self, **extra):
        (self.scripts / "verify_release_artifact.sh").write_text('''set -euo pipefail
echo "$(basename "$1") $2 $3 $(basename "$4")" >> "$FILEMINT_ZIP_TEST_LOG"
if [[ "$1" == *.zip && "${FAIL_ZIP_CHECK:-0}" == 1 ]]; then exit 1; fi
if [[ "$1" == *.zip && "${DIFFERENT_PAYLOAD:-0}" == 1 ]]; then
  printf 'different-code-hash\\n' > "$5"
else
  printf 'same-code-hash\\n' > "$5"
fi
''')
        return subprocess.run(["bash", str(self.scripts / "verify_release_pair.sh"), str(self.dmg), "0.6.0", "13"],
                              env=self.env | extra, text=True, capture_output=True, timeout=30)

    def test_pair_checks_both_immutable_feeds_and_same_signed_payload(self):
        result = self.pair()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("FileMint-0.6.0.dmg 0.6.0 13 appcast.xml", self.log.read_text())
        self.assertIn("FileMint-0.6.0.zip 0.6.0 13 appcast-zip.xml", self.log.read_text())
        self.assertNotEqual(self.pair(FAIL_ZIP_CHECK="1").returncode, 0)
        result = self.pair(DIFFERENT_PAYLOAD="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("different signed applications", result.stderr)


if __name__ == "__main__":
    unittest.main()
