#!/usr/bin/env python3
"""Verify the local compression artifact, or its signed copy in an app."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
THIRD = ROOT / "ThirdParty/ImageCompression"
ARTIFACT = ROOT / "CorePackage/Artifacts/FileMintCompression.xcframework"
INSTALL_NAME = "@rpath/FileMintCompression.framework/Versions/A/FileMintCompression"


def command(*args):
    return subprocess.check_output(list(map(str, args)), text=True).strip()


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def verify_framework(framework):
    binary = framework / "Versions/A/FileMintCompression"
    require(binary.is_file(), "Missing compression runtime")
    require(command("lipo", "-archs", binary) == "arm64", "Compression runtime must be arm64 only")
    build = command("xcrun", "vtool", "-show-build", binary)
    require(re.search(r"\bminos\s+13\.0(?:\.0)?\s", build + "\n"), "Compression runtime must target macOS 13.0")
    loads = [line.strip().split(" (", 1)[0] for line in command("otool", "-L", binary).splitlines()[1:]]
    require(loads and loads[0] == INSTALL_NAME, "Unexpected compression install name")
    require(all(p.startswith(("/usr/lib/", "/System/Library/Frameworks/")) for p in loads[1:]),
            "Compression runtime loads an unbundled third-party library")
    exports = {line.split()[-1] for line in command("nm", "-gU", binary).splitlines() if line.split()}
    require(exports == {"_fm_compression_encode", "_fm_compression_version"}, "Unexpected compression C ABI")
    notice = framework / "Resources/THIRD-PARTY-NOTICES.txt"
    require(notice.is_file() and notice.read_bytes() == (THIRD / notice.name).read_bytes(), "Missing or stale compression notices")
    subprocess.run(["codesign", "--verify", "--strict", str(framework)], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path)
    args = parser.parse_args()
    if args.app:
        framework = args.app / "Contents/Frameworks/FileMintCompression.framework"
        verify_framework(framework)
        app = args.app / "Contents/MacOS/FileMint"
        extension = args.app / "Contents/PlugIns/FileMintFinderSync.appex"
        require(INSTALL_NAME in command("otool", "-L", app), "Main app does not link compression runtime")
        require("FileMintCompression" not in command("otool", "-L", extension / "Contents/MacOS/FileMintFinderSync"),
                "Finder extension must not link compression runtime")
        require(not list(extension.rglob("FileMintCompression.framework")), "Finder extension embeds compression runtime")
        notice = args.app / "Contents/Resources/THIRD-PARTY-NOTICES.txt"
        require(notice.is_file() and notice.read_bytes() == (THIRD / notice.name).read_bytes(), "App compression notices are missing or stale")
    else:
        manifest = json.loads((THIRD / "artifact-manifest.json").read_text())
        locked = json.loads((THIRD / "sources.lock.json").read_text())
        require(manifest["sources"] == locked["sources"], "Runtime and source lock disagree")
        for entry in locked["sources"]:
            path = THIRD / "sources" / entry["file"]
            require(hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"], f"Source checksum mismatch: {path.name}")
        actual = {}
        for path in sorted(ARTIFACT.rglob("*")):
            if path.is_symlink():
                require(path.resolve().is_relative_to(ARTIFACT.resolve()), "Artifact symlink escapes its directory")
            elif path.is_file():
                actual[str(path.relative_to(ARTIFACT))] = hashlib.sha256(path.read_bytes()).hexdigest()
        require(actual == manifest["files"], "Compression artifact checksum mismatch")
        for name, digest in manifest["recipeFiles"].items():
            require(hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, "Compression build recipe changed; rebuild its artifact")
        verify_framework(ARTIFACT / "macos-arm64/FileMintCompression.framework")
    print("Verified arm64 macOS 13 compression runtime, load paths and notices.")


if __name__ == "__main__":
    main()
