#!/usr/bin/env python3
"""Offline evidence regressions; no GUI, signing, production data or URL opening."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from urllib.parse import parse_qs, urlsplit

sys.dont_write_bytecode = True
import url_probe as probe


class TransportEvidenceTests(unittest.TestCase):
    def test_corpus_has_exact_wire_and_decoded_boundaries(self):
        cases = {item["case"]: item for item in probe.corpus("1dc08aa0-532c-45e7-bdc7-0055cb93c3dc")}
        for size in [16383, 16384, 16385]:
            self.assertEqual(len(cases[f"url-{size}"]["systemArgument"].encode()), size)
        for size in [8191, 8192, 8193]:
            self.assertEqual(len(cases[f"decoded-text-{size}"]["expectedSingleDecodedText"].encode()), size)
        self.assertIn("text=%FF", cases["invalid-utf8-byte"]["systemArgument"])
        self.assertEqual(cases["double-encoded-slash"]["expectedSingleDecodedText"], "%2F")
        self.assertTrue(all("probe=filemint-p0" in item["systemArgument"] for item in cases.values()))

    def test_edited_manifest_cannot_dispatch_arbitrary_input(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "new-run"
            with contextlib.redirect_stdout(io.StringIO()):
                probe.prepare(output)
            path = output / "manifest.json"
            manifest = probe.load_manifest(path)
            manifest["cases"][0]["systemArgument"] = "filemint://new?directory=/Users"
            path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, "fixed synthetic corpus"):
                probe.load_manifest(path)

    def test_open_success_without_receiver_event_is_unknown(self):
        attempt = dict(case="bare-percent", receiverMode="raw", requestID="qa-id",
                       buildRunID="build-1", systemArgument="filemint-launcher-qa://draft?text=%",
                       dispatchStatus="open-returned", openExitCode=0)
        result = probe.compare_attempt(attempt, [])
        self.assertEqual(result["receiverObservation"], "unknown")
        self.assertEqual(result["deliveryCount"], 0)

    def test_derived_conversion_is_not_reported_as_system_delivery(self):
        attempt = dict(case="bare-percent", receiverMode="delegate", requestID="qa-id",
                       buildRunID="build-1", systemArgument="filemint-launcher-qa://draft?text=%",
                       dispatchStatus="open-returned", openExitCode=0)
        event = dict(event="url-received", requestID="qa-id", buildRunID="build-1",
                     source="foundation-derived", representation="filemint-launcher-qa://draft?text=%25")
        self.assertEqual(probe.compare_attempt(attempt, [event])["receiverObservation"], "unknown")
        event["source"] = "appkit"
        observed = probe.compare_attempt(attempt, [event])
        self.assertFalse(observed["representations"][0]["unchangedFromSystemArgument"])
        event["buildRunID"] = "old-build"
        self.assertEqual(probe.compare_attempt(attempt, [event])["deliveryCount"], 0)

    def test_raycast_script_does_not_evaluate_shell_metacharacters(self):
        with tempfile.TemporaryDirectory() as temporary:
            marker = Path(temporary) / "must-not-exist"
            payload = f'FileMint-QA $(touch "{marker}") `touch "{marker}"` & # + %'
            result = subprocess.run(["/bin/bash", str(Path(__file__).with_name("raycast-probe.sh")), payload],
                                    env={**os.environ, "FILEMINT_QA_PROBE_PRINT_ONLY": "1"},
                                    capture_output=True, text=True, check=True, timeout=5)
            self.assertIn("&name=" + payload + "&text=", result.stdout)
            self.assertFalse(marker.exists())

    @unittest.skipUnless(Path("/usr/bin/osascript").exists(), "Requires macOS system JXA")
    def test_system_jxa_encodes_argv_once_without_execution(self):
        with tempfile.TemporaryDirectory() as temporary:
            marker = Path(temporary) / "must-not-exist"
            sample = f'FileMint-QA 中文 & # + % ? = \' " `touch {marker}` $(touch {marker})\n'
            result = subprocess.run(["/usr/bin/osascript", "-l", "JavaScript",
                                     str(Path(__file__).with_name("alfred_encode.js")), sample],
                                    capture_output=True, text=True, check=True, timeout=10)
            values = parse_qs(urlsplit(result.stdout.strip()).query)
            self.assertEqual(values["name"], [sample])
            self.assertEqual(values["probe"], ["filemint-p0"])
            self.assertFalse(marker.exists())


if __name__ == "__main__":
    unittest.main()
