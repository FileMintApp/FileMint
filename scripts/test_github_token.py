#!/usr/bin/env python3
"""Offline token transport regressions through production API/Git consumers."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
import verify_github_token as check

ROOT = Path(__file__).resolve().parent.parent
REAL_GH = shutil.which("gh")
TOKENS = {
    "classic": "ghs_" + "A1b2" * 9,
    # Deliberately unsigned fixtures with underscores, hyphens and two dots.
    "stateless_520": "ghs_12345_" + "a_B-" * 20 + "." + "c_D-" * 60 + "." + "s_T-" * 47,
    "stateless_long": "ghs_12345_" + "a_B-" * 100 + "." + "c_D-" * 200 + "." + "s_T-" * 300,
    "oauth": "gho_" + "C3d4" * 9,
}

FAKE_GH = r'''#!/usr/bin/env python3
import hashlib, json, os, sys
args = sys.argv[1:]
token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN") or os.environ.get("FIXTURE_LOGIN_TOKEN", "")
if not token or hashlib.sha256(token.encode()).hexdigest() != os.environ["FIXTURE_TOKEN_HASH"]:
    sys.exit(1)
if args[:2] == ["auth", "token"]:
    print(token)
elif args[:2] == ["auth", "git-credential"]:
    sys.stdin.read()
    if os.environ.get("FIXTURE_TRUNCATE"):
        token = token[:40]
    print("username=x-access-token\npassword=" + token + "\n")
elif args[0] == "api":
    failure = os.environ.get("FIXTURE_API_ERROR")
    if failure and failure in args[1]:
        print(token, file=sys.stderr)  # A failing tool must not leak into check logs.
        sys.exit(1)
    data = {"object": {"type": "commit", "sha": "a" * 40}} if args[1].endswith("git/ref/heads/main") else {"full_name": "FileMintApp/homebrew-tap"}
    if "--include" in args:
        print("HTTP/2.0 200 OK\nContent-Type: application/json\n")
    print(json.dumps(data))
else:
    sys.exit(1)
'''


class GitHubTokenTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="filemint-token-tests-")
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        binary = self.directory / "gh"
        binary.write_text(FAKE_GH)
        binary.chmod(0o755)
        self.environment = dict(os.environ, PATH=str(self.directory) + os.pathsep + os.environ["PATH"],
                                GH_HOST="github.com", GH_PROMPT_DISABLED="1")
        for key in ("GH_TOKEN", "GITHUB_TOKEN", "FIXTURE_LOGIN_TOKEN", "FIXTURE_TRUNCATE", "FIXTURE_API_ERROR"):
            self.environment.pop(key, None)

    def run_check(self, token, source="GH_TOKEN", **environment):
        env = dict(self.environment, FIXTURE_TOKEN_HASH=hashlib.sha256(token.encode()).hexdigest(),
                   **{source: token}, **environment)
        result = subprocess.run([sys.executable, str(ROOT / "scripts/verify_github_token.py")],
                                cwd=ROOT, env=env, capture_output=True, text=True, timeout=30)
        self.assertNotIn(token, result.stdout + result.stderr)
        return result

    def test_all_token_shapes_reach_release_tap_and_git_consumers_intact(self):
        self.assertEqual(len(TOKENS["classic"]), 40)
        self.assertEqual(len(TOKENS["stateless_520"]), 520)
        self.assertGreater(len(TOKENS["stateless_long"]), 2048)
        for label, token in TOKENS.items():
            with self.subTest(format=label):
                result = self.run_check(token)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout), {
                    "status": "passed", "release_api": "passed", "tap_api": "passed",
                    "git_credential": "passed", "installation_token": label != "oauth",
                    "token_length": len(token), "token_dots": token.count(".")})

    def test_github_token_and_existing_login_fallbacks(self):
        for source in ("GITHUB_TOKEN", "FIXTURE_LOGIN_TOKEN"):
            with self.subTest(source=source):
                self.assertEqual(self.run_check(TOKENS["stateless_520"], source).returncode, 0)

    def test_truncated_credentials_fail_without_printing_token(self):
        result = self.run_check(TOKENS["stateless_long"], FIXTURE_TRUNCATE="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("did not preserve the complete token", result.stderr)

    def test_failed_apis_do_not_relay_sensitive_tool_stderr(self):
        for repository in ("repos/FileMintApp/FileMint/", "repos/FileMintApp/homebrew-tap"):
            with self.subTest(repository=repository):
                result = self.run_check(TOKENS["stateless_520"], FIXTURE_API_ERROR=repository)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("API request failed", result.stderr)

    def test_missing_credential_fails(self):
        env = dict(self.environment, FIXTURE_TOKEN_HASH="missing")
        result = subprocess.run([sys.executable, str(ROOT / "scripts/verify_github_token.py")],
                                env=env, capture_output=True, text=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No existing GitHub credential", result.stderr)

    @unittest.skipUnless(REAL_GH, "GitHub CLI is unavailable; fixture checks still run offline")
    def test_real_git_and_github_cli_preserve_synthetic_tokens_without_network(self):
        for label, token in TOKENS.items():
            with self.subTest(format=label):
                environment = dict(os.environ, GH_TOKEN=token, GH_HOST="github.com",
                                   GH_PROMPT_DISABLED="1")
                environment.pop("GH_DEBUG", None)
                check.credential_round_trip(token, environment)


if __name__ == "__main__":
    unittest.main()
