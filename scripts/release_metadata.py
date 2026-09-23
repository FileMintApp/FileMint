#!/usr/bin/env python3
"""Read the committed release version and extract its release notes."""

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = re.compile(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\Z")
BUILD = re.compile(r"[1-9][0-9]*\Z")
SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"


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
    return f"# FileMint {version}\n\n{body}\n"


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
