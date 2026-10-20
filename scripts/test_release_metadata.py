#!/usr/bin/env python3
import tempfile
import unittest
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from release_metadata import check_successor, project_release, release_notes, validate_summary_format

ROOT = Path(__file__).resolve().parent.parent
SUMMARY_FIXTURE = ROOT / "CorePackage/Tests/FileMintCoreTests/Fixtures/update-release-notes.md"


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

    def test_new_notes_publish_the_same_bilingual_summary_without_other_versions(self):
        expected = SUMMARY_FIXTURE.read_text()
        self.path.write_text(expected + "\n# FileMint 0.8.0\n\nHistorical notes.\n")
        self.assertEqual(release_notes(self.path, "9.9.9"), expected)

    def test_future_release_requires_the_new_format_and_historical_notes_still_work(self):
        self.path.write_text("# FileMint 0.8.1\n\nOld-style notes.\n")
        with self.assertRaisesRegex(ValueError, "bilingual"):
            release_notes(self.path, "0.8.1")
        self.path.write_text("# FileMint 0.8.0\n\nHistorical notes.\n")
        self.assertIn("Historical notes.", release_notes(self.path, "0.8.0"))

    def test_bilingual_template_is_accepted(self):
        self.path.write_text((ROOT / "docs/RELEASE_NOTES_TEMPLATE.md").read_text().replace("VERSION", "0.8.1"))
        self.assertIn("## Highlights", release_notes(self.path, "0.8.1"))

    def test_missing_duplicate_empty_or_reordered_sections_fail(self):
        notes = SUMMARY_FIXTURE.read_text()
        for broken in (
            notes.replace("## Highlights", "## Summary"),
            notes.replace("## Highlights", "## 更新摘要"),
            notes.replace("## Highlights\n", "## Highlights\n## Highlights\n"),
            notes.replace("## 开始使用\n", "## 详细改进\n").replace("## 详细改进\n\n- ", "## 开始使用\n\n- "),
            notes.replace("测试数据，不代表实际发布。", ""),
            notes.replace("## 详细改进", "# Extra title\n\n## 详细改进"),
        ):
            with self.subTest(broken=broken), self.assertRaises(ValueError):
                validate_summary_format(broken)

    def test_invalid_summary_is_rejected_before_release(self):
        notes = SUMMARY_FIXTURE.read_text()
        headline = "Organize file names and compare file contents."
        highlight = "- Replace text or add numbering, with a preview before renaming."
        for replacement in ("", "x" * 121, "[Link](https://example.com)", "<script>run()</script>",
                            "**Bold**", "`code`", "Text\x00here", "Text\u202ehere"):
            with self.subTest(replacement=replacement), self.assertRaises(ValueError):
                validate_summary_format(notes.replace(headline, replacement))
        for replacement in ("- ", "- " + "x" * 241, "\n".join(["- Item"] * 5), "Not a bullet",
                            "- First line\n  continuation"):
            with self.subTest(replacement=replacement), self.assertRaises(ValueError):
                validate_summary_format(notes.replace(highlight, replacement))
        with self.assertRaisesRegex(ValueError, "64 KiB"):
            validate_summary_format(notes + "文" * 65_536)


if __name__ == "__main__":
    unittest.main()
