#!/usr/bin/env python3
"""Resolve Xcode build variables before passing entitlements to manual codesign."""
import argparse
import plistlib
import re
from pathlib import Path


def expand_entitlements(value, bundle_identifier):
    if not isinstance(bundle_identifier, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]+", bundle_identifier):
        raise ValueError("Missing or invalid bundle identifier")

    def expand(item):
        if isinstance(item, str):
            resolved = item.replace("$(PRODUCT_BUNDLE_IDENTIFIER)", bundle_identifier)
            resolved = resolved.replace("${PRODUCT_BUNDLE_IDENTIFIER}", bundle_identifier)
            if "$(" in resolved or "${" in resolved:
                raise ValueError("Unresolved entitlement build variable")
            return resolved
        if isinstance(item, list):
            return [expand(child) for child in item]
        if isinstance(item, dict):
            return {expand(key): expand(child) for key, child in item.items()}
        return item

    if not isinstance(value, dict):
        raise ValueError("Entitlements must be a dictionary")
    return expand(value)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("info_plist", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    info = plistlib.loads(args.info_plist.read_bytes())
    resolved = expand_entitlements(plistlib.loads(args.source.read_bytes()), info.get("CFBundleIdentifier"))
    # Resolve everything before writing; an invalid input must never reach codesign.
    args.output.write_bytes(plistlib.dumps(resolved))


if __name__ == "__main__":
    main()
