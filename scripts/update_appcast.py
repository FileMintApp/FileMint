#!/usr/bin/env python3
"""Create/verify a single immutable release appcast; private keys stay in Keychain."""
import argparse
import base64
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
RELEASES = "https://github.com/FileMintApp/FileMint/releases"
ACCOUNT = "io.github.daigua.filemint.updates"
ET.register_namespace("sparkle", SPARKLE)


def tag(name):
    return f"{{{SPARKLE}}}{name}"


def public_key():
    with (ROOT / "Config/AppInfo.plist").open("rb") as source:
        key = plistlib.load(source)["SUPublicEDKey"]
    if len(base64.b64decode(key, validate=True)) != 32:
        raise ValueError("Invalid configured Sparkle public key")
    return key


def minimum_system_version(project=ROOT / "project.yml"):
    source = project.read_text(encoding="utf-8")
    targets = re.findall(r'^    macOS: ["\']?([0-9]+\.[0-9]+)["\']?$', source, re.MULTILINE)
    settings = re.findall(r'^    MACOSX_DEPLOYMENT_TARGET: ["\']?([0-9]+\.[0-9]+)["\']?$', source, re.MULTILINE)
    if len(targets) != 1 or len(settings) != 1 or targets[0] != settings[0]:
        raise ValueError("project.yml deployment targets must match")
    return targets[0]


def validate_inputs(archive, version, build):
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        raise ValueError("Invalid stable version")
    if not re.fullmatch(r"[1-9][0-9]*", build):
        raise ValueError("Invalid build number")
    if archive.name != f"FileMint-{version}.dmg" or not 0 < archive.stat().st_size <= 1073741824:
        raise ValueError("Archive name or size mismatch")


def make_feed(archive, version, build, signature):
    validate_inputs(archive, version, build)
    if len(base64.b64decode(signature, validate=True)) != 64:
        raise ValueError("Invalid Ed25519 signature")
    root = ET.Element("rss", version="2.0")
    channel = ET.SubElement(root, "channel")
    ET.SubElement(channel, "title").text = "FileMint"
    item = ET.SubElement(channel, "item")
    ET.SubElement(item, "title").text = f"FileMint {version}"
    ET.SubElement(item, tag("version")).text = build
    ET.SubElement(item, tag("shortVersionString")).text = version
    ET.SubElement(item, tag("minimumSystemVersion")).text = minimum_system_version()
    ET.SubElement(item, tag("hardwareRequirements")).text = "arm64"
    ET.SubElement(item, "link").text = f"{RELEASES}/tag/v{version}"
    ET.SubElement(item, "enclosure", {
        "url": f"{RELEASES}/download/v{version}/{archive.name}",
        "length": str(archive.stat().st_size), "type": "application/octet-stream",
        tag("edSignature"): signature,
    })
    ET.indent(root)
    return ET.ElementTree(root)


def validate_feed(feed, archive, version, build):
    validate_inputs(archive, version, build)
    raw = feed.read_bytes()
    if len(raw) > 65536 or b"<!DOCTYPE" in raw.upper() or b"<!ENTITY" in raw.upper():
        raise ValueError("Invalid appcast document")
    root = ET.fromstring(raw)
    items = root.findall("./channel/item")
    if root.tag != "rss" or len(items) != 1:
        raise ValueError("Expected one release item")
    item = items[0]
    signature = item.find("enclosure").get(tag("edSignature"))
    expected = make_feed(archive, version, build, signature).getroot()
    # Require exactly our generated fields, including URLs and no scripts/deltas/packages.
    def shape(node):
        return node.tag, dict(node.attrib), (node.text or "").strip(), [shape(child) for child in node]
    if shape(root) != shape(expected):
        raise ValueError("Appcast does not match this release")
    return signature


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["generate", "verify"])
    parser.add_argument("archive", type=Path)
    parser.add_argument("version")
    parser.add_argument("build")
    parser.add_argument("feed", type=Path)
    args = parser.parse_args()
    validate_inputs(args.archive, args.version, args.build)
    key = public_key()
    if args.mode == "generate":
        if args.feed.exists():
            raise ValueError("Refusing to replace an existing appcast")
        tools = Path(subprocess.check_output(["bash", str(ROOT / "scripts/sparkle_tools.sh")], text=True).strip())
        stored_key = subprocess.check_output([str(tools / "generate_keys"), "--account", ACCOUNT, "-p"], text=True).strip()
        if stored_key != key:
            raise ValueError("Local update key does not match the app's public key")
        signature = subprocess.check_output([str(tools / "sign_update"), "--account", ACCOUNT, "-p", str(args.archive)], text=True).strip()
        make_feed(args.archive, args.version, args.build, signature).write(args.feed, encoding="utf-8", xml_declaration=True)
    signature = validate_feed(args.feed, args.archive, args.version, args.build)
    subprocess.run(["swift", str(ROOT / "scripts/verify_update_signature.swift"), str(args.archive), key, signature], check=True)
    print(f"Verified appcast for FileMint {args.version} ({args.build})")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, AttributeError, OSError, ET.ParseError, subprocess.CalledProcessError) as error:
        print(f"Appcast validation failed: {error}", file=sys.stderr)
        sys.exit(1)
