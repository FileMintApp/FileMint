#!/usr/bin/env python3
"""Check the distribution ZIP before extracting it with macOS ditto."""
import posixpath
import stat
import sys
import zipfile

MAXIMUM_SIZE = 1_073_741_824


def validate_archive(path):
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        if not entries or len(entries) > 100_000 or sum(item.file_size for item in entries) > MAXIMUM_SIZE:
            raise ValueError("ZIP expanded size or entry count exceeds its limit")
        names, links = set(), set()
        for item in entries:
            name = item.filename.rstrip("/")
            parts = name.split("/")
            if (not name or "\\" in name or any(part in ("", ".", "..") for part in parts)
                    or name in names or item.flag_bits & 1):
                raise ValueError("Invalid or duplicate ZIP entry")
            metadata = parts[0] == "__MACOSX"
            if parts[0] != "FileMint.app" and not (metadata and (len(parts) == 1
                    or parts[1] in ("FileMint.app", "._FileMint.app"))):
                raise ValueError("ZIP must contain only FileMint.app and its resource metadata")
            mode = stat.S_IFMT(item.external_attr >> 16)
            if mode not in (0, stat.S_IFREG, stat.S_IFDIR, stat.S_IFLNK):
                raise ValueError("Unsupported ZIP entry type")
            if mode == stat.S_IFLNK:
                if metadata or item.file_size > 4096:
                    raise ValueError("Invalid ZIP symlink")
                target = archive.read(item).decode("utf-8")
                resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), target))
                if (not target or target.startswith("/") or "\\" in target
                        or not resolved.startswith("FileMint.app/")):
                    raise ValueError("ZIP symlink escapes the application")
                links.add(name)
            names.add(name)
        for name in names:
            parts = name.split("/")
            if any("/".join(parts[:index]) in links for index in range(1, len(parts))):
                raise ValueError("ZIP payload traverses a symlink")
        if not {"FileMint.app/Contents/Info.plist", "FileMint.app/Contents/MacOS/FileMint"} <= names:
            raise ValueError("ZIP is missing the application payload")


if __name__ == "__main__":
    validate_archive(sys.argv[1])
