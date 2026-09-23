#!/usr/bin/env python3
import tempfile
import unittest
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from release_metadata import check_successor, project_release, release_notes


class ReleaseMetadataTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "input"

    def test_project_version_is_unambiguous(self):
        self.path.write_text("settings:\n  base:\n    MARKETING_VERSION: 0.6.0\n    CURRENT_PROJECT_VERSION: 18\n")
        self.assertEqual(project_release(self.path), ("0.6.0", "18"))
        self.path.write_text(self.path.read_text() + "    MARKETING_VERSION: 0.6.1\n")
        with self.assertRaises(ValueError):
            project_release(self.path)

    def test_notes_only_include_current_release(self):
        self.path.write_text("# FileMint 0.6.0\n\nCurrent changes.\n\n# FileMint 0.5.9\n\nOld changes.\n")
        self.assertEqual(release_notes(self.path, "0.6.0"), "# FileMint 0.6.0\n\nCurrent changes.\n")
        with self.assertRaises(ValueError):
            release_notes(self.path, "0.6.1")

    def test_empty_notes_fail(self):
        self.path.write_text("# FileMint 0.6.0\n\n# FileMint 0.5.9\n\nOld changes.\n")
        with self.assertRaises(ValueError):
            release_notes(self.path, "0.6.0")

    def test_successor_requires_higher_version_and_build(self):
        self.path.write_text('<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item><sparkle:shortVersionString>0.5.9</sparkle:shortVersionString><sparkle:version>17</sparkle:version></item></channel></rss>')
        check_successor("0.5.10", "18", "0.5.9", self.path)
        for version, build in (("0.5.9", "18"), ("0.5.10", "17"), ("0.5.8", "19")):
            with self.assertRaises(ValueError):
                check_successor(version, build, "0.5.9", self.path)


if __name__ == "__main__":
    unittest.main()
