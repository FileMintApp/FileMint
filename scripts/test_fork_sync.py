#!/usr/bin/env python3
"""Exercise the copied workflow's shell steps against offline Git repositories."""
import ast
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = (ROOT / ".github/workflows/sync-fork.yml").read_text()


def workflow_steps():
    """Extract this workflow's named steps and final literal run blocks."""
    steps = {}
    for block in WORKFLOW.split("\n      - name: ")[1:]:
        name, body = block.split("\n", 1)
        condition = re.search(r"^        if: (.+)$", body, re.M)
        shell = None
        if "        run: |\n" in body:
            lines = body.split("        run: |\n", 1)[1].splitlines()
            if any(line.strip() and not line.startswith("          ") for line in lines):
                raise ValueError(f"Unexpected run-block indentation in {name}")
            shell = "\n".join(line[10:] for line in lines) + "\n"
        steps[name] = (condition.group(1) if condition else None, shell)
    return steps


STEPS = workflow_steps()


def expression(value, context):
    """Evaluate only the boolean/comparison expressions used by this workflow."""
    value = value.removeprefix("${{").removesuffix("}}").strip()
    value = re.sub(r"\b(?:github|env|secrets|steps)(?:\.[a-zA-Z0-9_]+)+",
                   lambda match: repr(context[match.group()]), value)
    value = value.replace("&&", " and ").replace("||", " or ")
    tree = ast.parse(value, mode="eval")
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.Compare,
               ast.Eq, ast.NotEq, ast.Constant)
    if any(not isinstance(node, allowed) for node in ast.walk(tree)):
        raise ValueError(f"Unsupported workflow expression: {value}")
    return eval(compile(tree, "<workflow expression>", "eval"), {"__builtins__": {}})


class ForkSyncTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.repo = self.root / "checkout"
        self.repo.mkdir()
        self.remote = self.root / "fork.git"
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull,
                        GIT_CONFIG_NOSYSTEM="1", GIT_TERMINAL_PROMPT="0",
                        GITHUB_OUTPUT=str(self.root / "outputs"),
                        GITHUB_REPOSITORY="fixture/FileMint", UPSTREAM_BRANCH="main",
                        GH_TOKEN="fixture-built-in-token", GH_CALLS=str(self.root / "gh-calls"),
                        CI_WORKFLOW="ci.yml", GH_EXIT_CODE="0")
        self.git("init", "--quiet", "--initial-branch=main")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("init", "--quiet", "--bare", str(self.remote))
        self.commit({"source.txt": "base\n", ".github/workflows/existing.yml": "name: base\n"})
        self.base = self.git("rev-parse", "HEAD")
        self.git("remote", "add", "origin", str(self.remote))
        self.git("push", "--quiet", "origin", "HEAD:main")
        self.git("update-ref", "refs/remotes/upstream/main", self.base)
        binary_dir = self.root / "bin"
        binary_dir.mkdir()
        gh = binary_dir / "gh"
        gh.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > "$GH_CALLS"\nexit "$GH_EXIT_CODE"\n')
        gh.chmod(0o755)
        self.env["PATH"] = str(binary_dir) + os.pathsep + self.env["PATH"]

    def git(self, *args):
        result = subprocess.run(["git", *args], cwd=self.repo, env=self.env,
                                capture_output=True, text=True, check=True)
        return result.stdout.strip()

    def commit(self, changes):
        for name, content in changes.items():
            path = self.repo / name
            if content is None:
                path.unlink()
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
        self.git("add", "--all")
        self.git("commit", "--quiet", "-m", "Fixture change")

    def upstream_changes(self, changes, reverted=False):
        self.commit(changes)
        if reverted:
            self.commit({".github/workflows/existing.yml": "name: base\n"})
        self.git("update-ref", "refs/remotes/upstream/main", self.git("rev-parse", "HEAD"))
        self.git("reset", "--hard", self.base)

    def remote_head(self, branch="main"):
        return self.git("--git-dir", str(self.remote), "rev-parse", f"refs/heads/{branch}")

    def run_sync(self, token="", event="schedule", branch="main"):
        Path(self.env["GITHUB_OUTPUT"]).write_text("")
        Path(self.env["GH_CALLS"]).unlink(missing_ok=True)
        context = {"secrets.FORK_SYNC_TOKEN": token, "github.token": self.env["GH_TOKEN"],
                   "github.event_name": event, "github.event.repository.default_branch": branch}
        configured = re.search(r"^      SYNC_TOKEN_CONFIGURED: (.+)$", WORKFLOW, re.M).group(1)
        self.env["SYNC_TOKEN_CONFIGURED"] = str(expression(configured, context)).lower()
        self.env["TARGET_BRANCH"] = branch
        context["env.SYNC_TOKEN_CONFIGURED"] = self.env["SYNC_TOKEN_CONFIGURED"]
        results = {}
        for name in ("Merge upstream changes", "Check workflow update permission",
                     "Push merge to fork", "Dispatch fork CI after sync"):
            outputs = dict(line.split("=", 1) for line in
                           Path(self.env["GITHUB_OUTPUT"]).read_text().splitlines())
            context.update({f"steps.sync.outputs.{key}": value for key, value in outputs.items()})
            self.env["BEFORE_SYNC"] = outputs.get("before_sync", "")
            condition, shell = STEPS[name]
            if condition and not expression(condition, context):
                results[name] = None
                continue
            result = subprocess.run(["bash", "-e", "-c", shell], cwd=self.repo,
                                    env=self.env, capture_output=True, text=True)
            results[name] = result
            if result.returncode:
                break  # GitHub steps also require previous steps to succeed.
        return results

    def test_checkout_uses_dedicated_token_or_builtin_token(self):
        value = re.search(r"^          token: (.+)$", WORKFLOW, re.M).group(1)
        tokens = ("ghs_" + "a" * 36, "ghs_123_" + "a_B-" * 62 + "." + "c_D-" * 62 + "." + "s" * 14,
                  "ghs_123_" + "a_B-" * 200 + "." + "c_D-" * 200 + "." + "s_T-" * 200)
        for builtin in tokens:
            for token in ("", "fixture-sync-token", *tokens):
                with self.subTest(builtin_length=len(builtin), dedicated_length=len(token)):
                    self.assertEqual(expression(value, {"secrets.FORK_SYNC_TOKEN": token,
                                                        "github.token": builtin}), token or builtin)

    def test_source_only_update_pushes_and_dispatches_with_builtin_token(self):
        self.upstream_changes({"source.txt": "updated\n"})
        results = self.run_sync()
        self.assertEqual(results["Push merge to fork"].returncode, 0)
        self.assertEqual(self.remote_head(), self.git("rev-parse", "upstream/main"))
        self.assertEqual(results["Dispatch fork CI after sync"].returncode, 0)
        self.assertEqual(Path(self.env["GH_CALLS"]).read_text().splitlines(),
                         ["workflow", "run", "ci.yml", "--repo", "fixture/FileMint", "--ref", "main"])

    def assert_workflow_change_requires_token(self, changes):
        self.upstream_changes(changes)
        results = self.run_sync()
        failure = results["Check workflow update permission"]
        self.assertNotEqual(failure.returncode, 0)
        self.assertIn("FORK_SYNC_TOKEN", failure.stdout)
        self.assertNotIn("Push merge to fork", results)
        self.assertEqual(self.remote_head(), self.base)
        self.assertFalse(Path(self.env["GH_CALLS"]).exists())
        # Retry from the actual remote branch, as a fresh runner would.
        self.git("reset", "--hard", self.base)
        results = self.run_sync(token="fixture-sync-token")
        self.assertEqual(results["Push merge to fork"].returncode, 0)
        self.assertEqual(self.remote_head(), self.git("rev-parse", "upstream/main"))
        self.assertIsNone(results["Dispatch fork CI after sync"])

    def test_new_workflow_requires_token_before_remote_update(self):
        self.assert_workflow_change_requires_token({".github/workflows/new.yml": "name: new\n"})

    def test_modified_workflow_requires_token_before_remote_update(self):
        self.assert_workflow_change_requires_token({".github/workflows/existing.yml": "name: changed\n"})

    def test_deleted_workflow_requires_token_before_remote_update(self):
        self.assert_workflow_change_requires_token({".github/workflows/existing.yml": None})

    def test_workflow_change_then_revert_still_requires_token(self):
        self.upstream_changes({".github/workflows/existing.yml": "name: changed\n"}, reverted=True)
        self.assertEqual(self.git("diff", "--name-only", "HEAD", "upstream/main"), "")
        results = self.run_sync()
        self.assertNotEqual(results["Check workflow update permission"].returncode, 0)
        self.assertEqual(self.remote_head(), self.base)

    def test_divergent_fork_commits_are_preserved(self):
        self.upstream_changes({"source.txt": "upstream\n"})
        self.commit({"fork.txt": "downstream\n"})
        fork_commit = self.git("rev-parse", "HEAD")
        self.git("push", "--quiet", "origin", "HEAD:main")
        results = self.run_sync()
        self.assertEqual(results["Push merge to fork"].returncode, 0)
        self.git("merge-base", "--is-ancestor", fork_commit, self.remote_head())
        self.git("merge-base", "--is-ancestor", "upstream/main", self.remote_head())
        self.assertEqual((self.repo / "fork.txt").read_text(), "downstream\n")

    def test_merge_conflict_stops_before_push_and_dispatch(self):
        self.upstream_changes({"source.txt": "upstream\n"})
        self.commit({"source.txt": "downstream\n"})
        self.git("push", "--quiet", "origin", "HEAD:main")
        before = self.remote_head()
        results = self.run_sync(token="fixture-sync-token", event="workflow_dispatch")
        self.assertNotEqual(results["Merge upstream changes"].returncode, 0)
        self.assertNotIn("Push merge to fork", results)
        self.assertEqual(self.remote_head(), before)
        self.assertFalse(Path(self.env["GH_CALLS"]).exists())

    def test_push_rejection_stops_before_ci_dispatch(self):
        self.upstream_changes({"source.txt": "updated\n"})
        hook = self.remote / "hooks/pre-receive"
        hook.write_text("#!/bin/sh\nexit 1\n")
        hook.chmod(0o755)
        results = self.run_sync(event="workflow_dispatch")
        self.assertNotEqual(results["Push merge to fork"].returncode, 0)
        self.assertNotIn("Dispatch fork CI after sync", results)
        self.assertEqual(self.remote_head(), self.base)
        self.assertFalse(Path(self.env["GH_CALLS"]).exists())

    def test_manual_retry_dispatches_when_already_current_for_either_token(self):
        for token in ("", "fixture-sync-token"):
            with self.subTest(token_configured=bool(token)):
                results = self.run_sync(token=token)
                self.assertIsNone(results["Push merge to fork"])
                self.assertIsNone(results["Dispatch fork CI after sync"])
                results = self.run_sync(token=token, event="workflow_dispatch")
                self.assertIsNone(results["Push merge to fork"])
                self.assertEqual(results["Dispatch fork CI after sync"].returncode, 0)

    def test_dedicated_token_update_to_other_default_branch_dispatches_ci(self):
        self.upstream_changes({"source.txt": "updated\n"})
        results = self.run_sync(token="fixture-sync-token", branch="trunk")
        self.assertEqual(results["Push merge to fork"].returncode, 0)
        self.assertEqual(self.remote_head("trunk"), self.git("rev-parse", "upstream/main"))
        self.assertEqual(results["Dispatch fork CI after sync"].returncode, 0)
        self.assertEqual(Path(self.env["GH_CALLS"]).read_text().splitlines()[-2:], ["--ref", "trunk"])

    def test_dispatch_failure_can_be_retried_without_repeating_push(self):
        self.upstream_changes({"source.txt": "updated\n"})
        self.env["GH_EXIT_CODE"] = "1"
        results = self.run_sync()
        self.assertNotEqual(results["Dispatch fork CI after sync"].returncode, 0)
        published = self.remote_head()
        self.env["GH_EXIT_CODE"] = "0"
        results = self.run_sync(event="workflow_dispatch")
        self.assertIsNone(results["Push merge to fork"])
        self.assertEqual(results["Dispatch fork CI after sync"].returncode, 0)
        self.assertEqual(self.remote_head(), published)


if __name__ == "__main__":
    unittest.main()
