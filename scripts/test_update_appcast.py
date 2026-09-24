#!/usr/bin/env python3
import base64
import tempfile
import unittest
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
