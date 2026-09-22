#!/usr/bin/env python3
import copy
from pathlib import Path
import plistlib
import sys
import unittest

sys.dont_write_bytecode = True
from prepare_signing_entitlements import expand_entitlements

ROOT = Path(__file__).resolve().parent.parent
MACH = "com.apple.security.temporary-exception.mach-lookup.global-name"


class SigningEntitlementsTests(unittest.TestCase):
    def test_production_app_services_are_resolved_without_changing_other_permissions(self):
        source = plistlib.loads((ROOT / "Config/FileMint.entitlements").read_bytes())
        snapshot = copy.deepcopy(source)
        resolved = expand_entitlements(source, "io.github.daigua.filemint")
        self.assertEqual(resolved[MACH], ["io.github.daigua.filemint-spks", "io.github.daigua.filemint-spki"])
        self.assertEqual(source, snapshot)
        self.assertEqual({k: v for k, v in resolved.items() if k != MACH}, {k: v for k, v in source.items() if k != MACH})

    def test_finder_entitlements_stay_unchanged(self):
        source = plistlib.loads((ROOT / "Config/FileMintFinderSync.entitlements").read_bytes())
        resolved = expand_entitlements(source, "io.github.daigua.filemint.findersync")
        self.assertEqual(resolved, source)
        self.assertNotIn(MACH, resolved)
        self.assertNotIn("com.apple.security.network.client", resolved)

    def test_actual_bundle_identifier_and_nested_variables(self):
        value = {"nested": [{"value": "${PRODUCT_BUNDLE_IDENTIFIER}-spki"}], "flag": True, "data": b"unchanged"}
        self.assertEqual(expand_entitlements(value, "io.example.test"),
                         {"nested": [{"value": "io.example.test-spki"}], "flag": True, "data": b"unchanged"})

    def test_unknown_variables_fail_closed(self):
        for value in [{"service": "$(UNKNOWN)-spki"}, {"service": ["${TEAM_ID}"]}, {"$(UNKNOWN)": True}]:
            with self.assertRaises(ValueError):
                expand_entitlements(value, "io.example.test")

    def test_invalid_bundle_identifiers_and_plists_are_rejected(self):
        for identifier in [None, "", "$(PRODUCT_BUNDLE_IDENTIFIER)", "io.example/other", "io.example test"]:
            with self.assertRaises(ValueError):
                expand_entitlements({}, identifier)
        with self.assertRaises(ValueError):
            expand_entitlements([], "io.example.test")


if __name__ == "__main__":
    unittest.main()
