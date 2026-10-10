#!/usr/bin/env python3
import base64
import tempfile
import unittest
from unittest.mock import patch
import subprocess
import sys
sys.dont_write_bytecode = True
from pathlib import Path
import update_appcast as appcast


class AppcastTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.archive = Path(self.directory.name) / "FileMint-0.6.0.dmg"
        self.archive.write_bytes(b"test archive")
        self.feed = Path(self.directory.name) / "appcast.xml"
        self.signature = base64.b64encode(bytes(64)).decode()

    def write(self, mutate=lambda root: None):
        tree = appcast.make_feed(self.archive, "0.6.0", "13", self.signature)
        mutate(tree.getroot())
        tree.write(self.feed, encoding="utf-8", xml_declaration=True)

    def test_round_trip_and_tampered_archive_size(self):
        self.write()
        self.assertEqual(appcast.validate_feed(self.feed, self.archive, "0.6.0", "13"), self.signature)
        self.assertEqual(appcast.ET.parse(self.feed).findtext("./channel/item/" + appcast.tag("minimumSystemVersion")), appcast.minimum_system_version())
        self.assertEqual(appcast.ET.parse(self.feed).findtext("./channel/item/" + appcast.tag("hardwareRequirements")), "arm64")
        self.archive.write_bytes(b"changed archive")
        with self.assertRaises(ValueError):
            appcast.validate_feed(self.feed, self.archive, "0.6.0", "13")

    def test_zip_has_its_own_feed_and_cannot_replace_the_legacy_dmg_enclosure(self):
        self.write()
        legacy = self.feed.read_bytes()
        archive = Path(self.directory.name) / "FileMint-0.6.0.zip"
        archive.write_bytes(b"ZIP payload")
        feed = Path(self.directory.name) / "appcast-zip.xml"
        appcast.make_feed(archive, "0.6.0", "13", self.signature).write(feed)
        self.assertEqual(appcast.validate_feed(feed, archive, "0.6.0", "13"), self.signature)
        for wrong_feed, wrong_archive in ((feed, self.archive), (self.feed, archive)):
            with self.assertRaisesRegex(ValueError, "does not match"):
                appcast.validate_feed(wrong_feed, wrong_archive, "0.6.0", "13")
        self.assertEqual(self.feed.read_bytes(), legacy)
        item = appcast.ET.parse(feed).find("./channel/item")
        self.assertEqual(item.find(appcast.tag("version")).text, "13")
        self.assertEqual(item.find("enclosure").get("url"), f"{appcast.RELEASES}/download/v0.6.0/{archive.name}")

    def test_zip_signature_verification_uses_the_configured_key_and_final_archive(self):
        self.archive = Path(self.directory.name) / "FileMint-0.6.0.zip"
        self.archive.write_bytes(b"final ZIP")
        self.feed = Path(self.directory.name) / "appcast-zip.xml"
        self.write()
        args = ["update_appcast.py", "verify", str(self.archive), "0.6.0", "13", str(self.feed)]
        with patch.object(sys, "argv", args), patch.object(appcast.subprocess, "check_output") as private_key, \
                patch.object(appcast.subprocess, "run") as verify:
            appcast.main()
            private_key.assert_not_called()
            self.assertEqual(verify.call_args.args[0][2:], [str(self.archive), appcast.public_key(), self.signature])
            self.assertTrue(verify.call_args.kwargs["check"])

    def test_resumed_generation_reuses_only_verified_feed_without_private_key(self):
        self.write()
        original = self.feed.read_bytes()
        args = ["update_appcast.py", "generate", str(self.archive), "0.6.0", "13", str(self.feed)]
        with patch.object(sys, "argv", args), patch.object(appcast.subprocess, "check_output") as private_key, \
                patch.object(appcast.subprocess, "run") as verify:
            appcast.main()
            private_key.assert_not_called()
            verify.assert_called_once()
            self.assertTrue(verify.call_args.kwargs["check"])
            self.assertIn("verify_update_signature.swift", verify.call_args.args[0][1])
        self.assertEqual(self.feed.read_bytes(), original)
        # A signature failure cannot silently regenerate/replace the old feed.
        with patch.object(sys, "argv", args), patch.object(appcast.subprocess, "check_output") as private_key, \
                patch.object(appcast.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "swift")):
            with self.assertRaises(subprocess.CalledProcessError):
                appcast.main()
            private_key.assert_not_called()
        self.assertEqual(self.feed.read_bytes(), original)

    def test_project_deployment_targets_must_match(self):
        project = Path(self.directory.name) / "project.yml"
        project.write_text('    macOS: "13.0"\n    MACOSX_DEPLOYMENT_TARGET: 13.0\n')
        self.assertEqual(appcast.minimum_system_version(project), "13.0")
        project.write_text('    macOS: "13.0"\n    MACOSX_DEPLOYMENT_TARGET: 14.0\n')
        with self.assertRaises(ValueError):
            appcast.minimum_system_version(project)

    def test_rejects_changed_release_and_extra_payloads(self):
        mutations = [
            lambda root: root.find("./channel/item/enclosure").set("url", "https://example.com/update.dmg"),
            lambda root: root.find("./channel/item/enclosure").set(appcast.tag("installationType"), "package"),
            lambda root: root.find("./channel/item").append(appcast.ET.Element(appcast.tag("deltas"))),
            lambda root: root.find("./channel").append(appcast.ET.Element("item")),
            lambda root: root.find("./channel/item/" + appcast.tag("version")).__setattr__("text", "14"),
            lambda root: root.find("./channel/item/" + appcast.tag("shortVersionString")).__setattr__("text", "0.7.0"),
            lambda root: root.find("./channel/item/" + appcast.tag("minimumSystemVersion")).__setattr__("text", "0.0"),
            lambda root: root.find("./channel/item/" + appcast.tag("hardwareRequirements")).__setattr__("text", "x86_64"),
        ]
        for mutate in mutations:
            self.write(mutate)
            with self.assertRaises(ValueError):
                appcast.validate_feed(self.feed, self.archive, "0.6.0", "13")

    def test_rejects_invalid_versions_signatures_and_entities(self):
        for version in ["0.6.0-beta.1", "v0.6.0", "00.6.0", "0.6"]:
            with self.assertRaises(ValueError):
                appcast.make_feed(self.archive, version, "13", self.signature)
        with self.assertRaises(ValueError):
            appcast.make_feed(self.archive, "0.6.0", "13", base64.b64encode(bytes(32)).decode())
        self.feed.write_text('<!DOCTYPE rss [<!ENTITY e "payload">]><rss/>')
        with self.assertRaises(ValueError):
            appcast.validate_feed(self.feed, self.archive, "0.6.0", "13")


if __name__ == "__main__":
    unittest.main()
