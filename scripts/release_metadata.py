#!/usr/bin/env python3
"""Read the committed release version and extract its release notes."""

import argparse
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = re.compile(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\Z")
BUILD = re.compile(r"[1-9][0-9]*\Z")
SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
LEGACY_NOTES_THROUGH = (0, 8, 0)
NOTE_SECTIONS = ("更新摘要", "开始使用", "详细改进", "升级须知",
                 "Highlights", "Getting started", "Details", "Before you update")


def project_release(path: Path) -> tuple[str, str]:
    source = path.read_text(encoding="utf-8")
    values = {}
    for key in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION"):
        matches = re.findall(rf"^    {key}:\s*([^\s#]+)\s*$", source, re.MULTILINE)
        if len(matches) != 1:
            raise ValueError(f"Expected one settings.base {key} in project.yml")
        values[key] = matches[0].strip('"\'')
    version, build = values["MARKETING_VERSION"], values["CURRENT_PROJECT_VERSION"]
    if not VERSION.fullmatch(version) or not BUILD.fullmatch(build):
        raise ValueError("project.yml must contain a stable version and positive numeric build")
    return version, build


def release_notes(path: Path, version: str) -> str:
    source = path.read_text(encoding="utf-8")
    headings = list(re.finditer(r"^# FileMint ([^\n]+)\s*$", source, re.MULTILINE))
    if not headings or headings[0].group(1) != version:
        raise ValueError(f"The first release-notes heading must be '# FileMint {version}'")
    end = headings[1].start() if len(headings) > 1 else len(source)
    body = source[headings[0].end():end].strip()
    if not body:
        raise ValueError("Current release notes are empty")
    notes = f"# FileMint {version}\n\n{body}\n"
    if tuple(map(int, version.split("."))) > LEGACY_NOTES_THROUGH:
        validate_summary_format(notes)
    return notes


def validate_summary_format(notes: str) -> None:
    """Keep future GitHub notes compatible with the app's bounded text summaries."""
    if len(notes.encode("utf-8")) > 65_536:
        raise ValueError("Release notes must fit within 64 KiB for in-app summaries")
    lines = [line.strip() for line in notes.splitlines()]
    if sum(line.startswith("# ") for line in lines) != 1:
        raise ValueError("Only the release title may use a level-one heading")
    headings = [(index, line[3:]) for index, line in enumerate(lines) if line.startswith("## ")]
    if tuple(title for _, title in headings) != NOTE_SECTIONS:
        raise ValueError("Use the ordered bilingual sections in docs/RELEASE_NOTES_TEMPLATE.md")
    for position, (start, title) in enumerate(headings):
        end = headings[position + 1][0] if position + 1 < len(headings) else len(lines)
        content = [line for line in lines[start + 1:end] if line]
        if not content:
            raise ValueError(f"Release-note section is empty: {title}")
        if title not in ("更新摘要", "Highlights"):
            continue
        if not 2 <= len(content) <= 5 or content[0].startswith("- "):
            raise ValueError(f"{title} needs one headline and one to four single-line highlights")
        for index, line in enumerate(content):
            if index and not line.startswith("- "):
                raise ValueError(f"{title} highlights must start with '- '")
            text = line[2:].strip() if index else line
            limit = 240 if index else 120
            if (not text or len(text) > limit or any(char in "<>[]`*#" for char in text)
                    or any(unicodedata.category(char) in ("Cc", "Cf") for char in text)):
                raise ValueError(f"{title} needs plain text within {limit} characters per line")


def check_successor(version: str, build: str, previous_version: str, previous_feed: Path) -> None:
    if not VERSION.fullmatch(previous_version):
        raise ValueError("Latest published release has an invalid stable version")
    feed = ET.parse(previous_feed)
    items = feed.findall("./channel/item")
    if len(items) != 1:
        raise ValueError("Latest published release has no single appcast item")
    item = items[0]
    feed_version = item.findtext(f"{{{SPARKLE}}}shortVersionString")
    feed_build = item.findtext(f"{{{SPARKLE}}}version")
    if feed_version != previous_version or not feed_build or not BUILD.fullmatch(feed_build):
        raise ValueError("Latest published appcast version/build is invalid")
    if tuple(map(int, version.split("."))) <= tuple(map(int, previous_version.split("."))):
        raise ValueError("Release version must exceed the latest published version")
    if int(build) <= int(feed_build):
        raise ValueError("Release build must exceed the latest published build")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("show", "check", "notes", "successor"))
    parser.add_argument("--version")
    parser.add_argument("--build")
    parser.add_argument("--previous-version")
    parser.add_argument("--previous-feed", type=Path)
    args = parser.parse_args()
    version, build = project_release(ROOT / "project.yml")
    if args.mode in ("check", "notes", "successor"):
        if (args.version and args.version != version) or (args.build and args.build != build):
            raise ValueError(f"Requested version/build differs from project.yml ({version}, {build})")
        notes = release_notes(ROOT / "docs/RELEASE_NOTES.md", version)
    if args.mode == "show":
        print(version, build)
    elif args.mode == "notes":
        sys.stdout.write(notes)
    elif args.mode == "successor":
        if not args.previous_version or not args.previous_feed:
            raise ValueError("Latest release version and appcast are required")
        check_successor(version, build, args.previous_version, args.previous_feed)
        print(f"Release version/build exceeds {args.previous_version}")
    else:
        print(f"Release metadata verified: {version} ({build})")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, ET.ParseError) as error:
        print(f"Release metadata invalid: {error}", file=sys.stderr)
        sys.exit(1)
