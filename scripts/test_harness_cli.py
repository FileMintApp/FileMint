#!/usr/bin/env python3
"""Exercise the freshly built Harness as a real process; no optional/skip paths."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


def run_process(command, **kwargs):
    result = subprocess.run(command, capture_output=True, text=True, timeout=kwargs.pop("timeout", 15), **kwargs)
    if result.returncode < 0:
        raise RuntimeError(f"Process terminated by signal {-result.returncode}: {result.stderr[:500]}")
    return result


def case(identifier="sample"):
    return {"id": identifier, "name": "Sample", "templateID": "plain-text", "existingFiles": [],
            "expect": {"fileName": "Untitled.txt", "content": {"mode": "exact", "value": ""}}}


def suite(*cases):
    return {"schemaVersion": 1, "cases": list(cases) or [case()]}


class HarnessCLITests(unittest.TestCase):
    binary: Path

    def check(self, value, code, *, text=False, extra_args=(), missing_input=False):
        raw = value if isinstance(value, bytes) else json.dumps(value, ensure_ascii=False).encode("utf-8")
        with tempfile.TemporaryDirectory(prefix="filemint-cli-test-") as tmp, tempfile.TemporaryDirectory(prefix="filemint-cli-cwd-") as cwd:
            root = Path(tmp)
            path = root / "suite.json"
            if not missing_input:
                path.write_bytes(raw)
            old = root / "FileMintHarness"
            old.mkdir()
            marker = old / "keep.txt"
            marker.write_bytes(b"old owner")
            outside = root / "outside.txt"
            outside.write_bytes(b"outside sentinel")
            args = [str(self.binary), str(path)]
            if not text:
                args += ["--format", "json"]
            result = run_process(args + list(extra_args), cwd=cwd, env=dict(os.environ, TMPDIR=tmp + "/"))
            self.assertEqual(result.returncode, code, result.stdout + result.stderr)
            self.assertEqual(result.stderr, "")
            self.assertEqual(marker.read_bytes(), b"old owner")
            self.assertEqual(outside.read_bytes(), b"outside sentinel")
            self.assertEqual(sorted(p.name for p in root.iterdir()),
                             sorted(["FileMintHarness", "outside.txt"] + ([] if missing_input else ["suite.json"])))
            if text:
                self.assertIn({0: "PASSED", 1: "FAILED", 2: "ERROR", 64: "ERROR"}[code] + " suite:", result.stdout)
                return result.stdout
            report = json.loads(result.stdout)  # Reject extra logging or multiple JSON values.
            self.assertEqual(report["schemaVersion"], 1)
            self.assertEqual(report["exitCode"], code)
            self.assertEqual(report["status"], {0: "passed", 1: "failed", 2: "error", 64: "error"}[code])
            self.assertEqual(report["summary"]["executedCases"], len(report["cases"]))
            return report

    def test_public_suite_and_text_json_reports(self):
        public = json.loads((ROOT / "specs/harness/cases/file_creation_cases.json").read_text())
        report = self.check(public, 0)
        self.assertEqual(report["summary"]["executedCases"], 5)
        self.assertEqual(report["summary"]["passedCases"], 5)
        self.assertTrue(all(item["assertions"] for item in report["cases"]))
        text = self.check(public, 0, text=True)
        for item in public["cases"]:
            self.assertIn(item["id"], text)

    def test_bad_inputs_are_errors_with_zero_executions(self):
        invalid = [[], {}, {"schemaVersion": 1, "cases": []}, {"schemaVersion": 2, "cases": []},
                   b'{"schemaVersion":', b'\xff', b'{} {}', b' ' * (1_048_576 + 1)]
        for value in invalid:
            with self.subTest(input_type=type(value).__name__, size=len(value)):
                report = self.check(value, 2)
                self.assertEqual(report["summary"]["executedCases"], 0)
                self.assertTrue(report["errors"])
        self.check(suite(), 2, missing_input=True)

    def test_unknown_fields_at_every_level(self):
        for level in ("root", "case", "fixture", "expect", "content"):
            with self.subTest(level=level):
                value = suite()
                item = value["cases"][0]
                target = value
                if level == "case":
                    target = item
                elif level == "fixture":
                    item["existingFiles"] = [{"name": "seed.txt", "content": "seed"}]
                    target = item["existingFiles"][0]
                elif level == "expect":
                    target = item["expect"]
                elif level == "content":
                    target = item["expect"]["content"]
                target["ignored"] = True
                report = self.check(value, 2)
                self.assertEqual(report["errors"][0]["code"], "unknownField")
                self.assertIn("ignored", report["errors"][0]["path"])
        item = case()
        item["requestedFileNmae"] = "Wrong.txt"
        self.check(suite(item), 2)
        item = case()
        item["collisionStrategy"] = "replace"
        self.check(suite(item), 2)

    def test_duplicate_json_keys_cannot_hide_assertions(self):
        raw = json.dumps(suite(), separators=(",", ":"))
        variants = [raw.replace('"schemaVersion":1', '"schemaVersion":1,"schemaVersion":1'),
                    raw.replace('"value":""', '"value":"","value":"wrong"'),
                    raw.replace('"fileName":"Untitled.txt"', '"fileName":"Untitled.txt","file\\u004eame":"WRONG"')]
        for value in variants:
            with self.subTest(value=value[:80]):
                report = self.check(value.encode(), 2)
                self.assertEqual(report["errors"][0]["code"], "duplicateKey")

    def test_semantic_validation_and_whole_suite_preflight(self):
        variants = []
        for key, value in [("id", ""), ("name", " "), ("templateID", "missing"), ("id", 3), ("name", None)]:
            item = case()
            item[key] = value
            variants.append(suite(item))
        variants.append(suite(case(), case()))
        for name in ("../outside.txt", "../../outside.txt", "/tmp/outside.txt", "nested/file", "bad\x00name"):
            item = case()
            item["existingFiles"] = [{"name": name, "content": "TRUNCATE"}]
            variants.append(suite(item))
        for content in ({"mode": "skip"}, {"mode": "contains", "values": []},
                        {"mode": "contains", "values": [""]}, {"mode": "exact"},
                        {"mode": "exact", "value": "", "values": ["wrong"]}):
            item = case()
            item["expect"]["content"] = content
            variants.append(suite(item))
        for value in variants:
            with self.subTest(value=value):
                self.assertEqual(self.check(value, 2)["summary"]["executedCases"], 0)
        last = case("last")
        last["unknown"] = True
        self.assertEqual(self.check(suite(case("first"), last), 2)["summary"]["executedCases"], 0)

    def test_assertion_failures_and_mixed_results(self):
        for expected in ("\n", " \n", "\r\n", "wrong"):
            with self.subTest(expected=expected):
                bad = case("bad")
                bad["expect"]["content"]["value"] = expected
                report = self.check(suite(bad, case("good")), 1)
                self.assertEqual([item["status"] for item in report["cases"]], ["failed", "passed"])
                self.assertIn("first difference at byte", report["cases"][0]["assertions"][1]["actual"])
        bad = case()
        bad["expect"]["fileName"] = "Wrong.txt"
        self.check(suite(bad), 1, text=True)
        # Use already-decomposed filename input, avoiding assumptions about macOS
        # URL normalization of composed filenames during template expansion.
        decomposed = case()
        decomposed.update(templateID="markdown", requestedFileName="cafe\u0301.md")
        decomposed["expect"] = {"fileName": "cafe\u0301.md", "content": {"mode": "exact", "value": "# cafe\u0301.md\n\n"}}
        self.check(suite(decomposed), 0)
        composed = copy.deepcopy(decomposed)
        composed["expect"]["content"]["value"] = "# café.md\n\n"
        self.check(suite(composed), 1)
        fragments = copy.deepcopy(decomposed)
        fragments["expect"]["content"] = {"mode": "contains", "values": ["cafe\u0301", "\n\n"]}
        self.check(suite(fragments), 0)
        fragments["expect"]["content"]["values"] = ["café"]
        self.check(suite(fragments), 1)

    def test_file_sanitization_and_collision_preservation(self):
        item = case()
        item.update(templateID="json", requestedFileName="api/config.json")
        item["expect"] = {"fileName": "api-config.json", "content": {"mode": "exact", "value": "{}\n"}}
        self.check(suite(item), 0)
        item = case()
        item["existingFiles"] = [{"name": "Untitled.txt", "content": "Keep nonempty bytes\r\n🌱"}]
        item["expect"]["fileName"] = "Untitled 2.txt"
        report = self.check(suite(item), 0)
        self.assertTrue(any(a["path"] == "existingFiles[0].unchanged" and a["passed"] for a in report["cases"][0]["assertions"]))

    def test_usage_errors(self):
        self.check(suite(), 64, extra_args=("--unknown",))
        self.check(suite(), 64, extra_args=("--format", "json"))
        self.check(suite(), 64, text=True, extra_args=("--format", "unsupported"))
        result = run_process([str(self.binary), "--format", "json"])
        self.assertEqual(result.returncode, 64)
        self.assertEqual(json.loads(result.stdout)["exitCode"], 64)

    def test_concurrent_runs_own_separate_workspaces(self):
        with tempfile.TemporaryDirectory(prefix="filemint-cli-concurrent-") as tmp:
            root = Path(tmp)
            path = root / "suite.json"
            path.write_text(json.dumps(suite(*(case(f"case-{i}") for i in range(60)))))
            marker = root / "keep.txt"
            marker.write_text("keep")
            env = dict(os.environ, TMPDIR=tmp + "/")
            def run(_):
                return run_process([str(self.binary), str(path), "--format", "json"], cwd=tmp, env=env)
            with ThreadPoolExecutor(max_workers=4) as pool:
                results = list(pool.map(run, range(4)))
            for result in results:
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(json.loads(result.stdout)["summary"]["passedCases"], 60)
            self.assertEqual(marker.read_text(), "keep")
            self.assertEqual(sorted(p.name for p in root.iterdir()), ["keep.txt", "suite.json"])

    def test_regression_driver_does_not_hide_process_failures(self):
        with tempfile.TemporaryDirectory(prefix="filemint-driver-") as tmp:
            with self.assertRaises(FileNotFoundError):
                run_process([str(Path(tmp) / "missing")])
            with self.assertRaises(subprocess.TimeoutExpired):
                run_process([sys.executable, "-c", "import time; time.sleep(2)"], timeout=0.05)
            with self.assertRaises(RuntimeError):
                run_process([sys.executable, "-c", "import os, signal; os.kill(os.getpid(), signal.SIGTERM)"])
            missing = run_process([sys.executable, str(Path(__file__).resolve()), "--binary", str(Path(tmp) / "missing")])
            self.assertNotEqual(missing.returncode, 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True, type=Path)
    args = parser.parse_args()
    if not args.binary.is_file() or not os.access(args.binary, os.X_OK):
        print("ERROR Harness binary is missing or not executable; build it first", file=sys.stderr)
        return 2
    HarnessCLITests.binary = args.binary.resolve()
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(HarnessCLITests))
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
