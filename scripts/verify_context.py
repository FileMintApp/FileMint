#!/usr/bin/env python3
"""Check the repository's demand-loaded context without external dependencies.

This checks navigation and entry size, not contract semantics or agent compliance.
Context docs use inline Markdown links and ATX headings; reference-style links
and arbitrary HTML are outside this deliberately small checker's scope.
"""

from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parent.parent
ENTRY_BUDGET = 7_000


def prose(text):
    """Exclude fenced examples so sample links/headings are not treated as docs."""
    lines = []
    fence = None
    for line in text.splitlines():
        marker = re.match(r"^\s{0,3}(`{3,}|~{3,})", line)
        if marker:
            run = marker.group(1)
            if fence is None:
                fence = run
            elif run[0] == fence[0] and len(run) >= len(fence):
                fence = None
            continue
        if fence is None:
            lines.append(line)
    return "\n".join(lines)


def anchors(text):
    result = set()
    for heading in re.findall(r"^#{1,6}\s+(.+?)\s*#*\s*$", prose(text), re.M):
        slug = re.sub(r"[^\w\- ]", "", heading.lower()).replace(" ", "-")
        anchor = slug
        number = 0
        while anchor in result:
            number += 1
            anchor = f"{slug}-{number}"
        result.add(anchor)
    return result


def main():
    files = [ROOT / name for name in (
        "AGENTS.md", "docs/AI_PLAYBOOK.md", "docs/DEVELOPMENT.md",
        "docs/tasks/TEMPLATE.md",
    )]
    files += sorted((ROOT / "specs").rglob("*.md"))
    errors = []
    destinations = {}
    link_count = 0

    for source in files:
        label = source.relative_to(ROOT)
        if not source.is_file():
            errors.append(f"{label}: required context document is missing")
            continue
        destinations[source] = set()
        text = prose(source.read_text(encoding="utf-8"))
        for raw in re.findall(r"\[[^\]\n]+\]\(([^)\n]+)\)", text):
            url = urlsplit(raw.strip().removeprefix("<").removesuffix(">"))
            if url.scheme or url.netloc:
                continue  # Offline check: external URLs are not fetched.
            target = (source.parent / unquote(url.path)).resolve() if url.path else source
            link_count += 1
            destinations[source].add(target)
            if not target.is_relative_to(ROOT):
                errors.append(f"{label}: local link escapes repository: {raw}")
            elif not target.exists():
                errors.append(f"{label}: missing target: {raw}")
            elif url.fragment and target.suffix == ".md":
                if unquote(url.fragment) not in anchors(target.read_text(encoding="utf-8")):
                    errors.append(f"{label}: missing heading: {raw}")

    for entry, directory in (("specs/SPEC.md", "specs/domains"),
                             ("specs/HARNESS.md", "specs/verification")):
        entry_path = ROOT / entry
        if not entry_path.is_file():
            errors.append(f"{entry}: required index is missing")
        docs = sorted((ROOT / directory).glob("*.md"))
        if not docs:
            errors.append(f"{directory}: no context documents found")
        for doc in docs:
            if doc not in destinations.get(entry_path, set()):
                errors.append(f"{entry}: missing index link to {doc.relative_to(ROOT)}")

    entry_files = [ROOT / "AGENTS.md", ROOT / "specs/SPEC.md"]
    entry_bytes = sum(path.stat().st_size for path in entry_files if path.is_file())
    if entry_bytes > ENTRY_BUDGET:
        errors.append(f"entry context is {entry_bytes} bytes; budget is {ENTRY_BUDGET}; move detail behind links")

    if errors:
        for error in errors:
            print(f"FAIL {error}", file=sys.stderr)
        return 1
    print(f"PASS context: {len(files)} documents, {link_count} local links; "
          f"entry {entry_bytes}/{ENTRY_BUDGET} UTF-8 bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
