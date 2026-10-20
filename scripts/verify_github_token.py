#!/usr/bin/env python3
"""Read-only checks using the existing GitHub identity; never print credentials."""
import json
import os
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
import homebrew_tap as tap
import release_publication as publication


class TokenCheckError(RuntimeError):
    pass


def credential_round_trip(token, environment=None):
    """Use Git's actual helper protocol, isolated from repository/user Git config."""
    environment = dict(os.environ if environment is None else environment,
                       GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1",
                       GIT_CONFIG_COUNT="0", GIT_TERMINAL_PROMPT="0")
    with tempfile.TemporaryDirectory(prefix="filemint-token-check-") as directory:
        result = subprocess.run(
            ["git", "-c", "credential.helper=", "-c",
             "credential.helper=!gh auth git-credential", "credential", "fill"],
            cwd=directory, env=environment, input="protocol=https\nhost=github.com\n\n",
            text=True, capture_output=True, timeout=30)
    fields = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    if result.returncode or fields.get("password") != token:
        raise TokenCheckError("Git credential helper did not preserve the complete token")


def verify():
    if os.environ.get("GH_HOST", "github.com") != "github.com":
        raise TokenCheckError("This check requires github.com as the GitHub host")
    # Avoid HTTP debug output even if enabled in the calling shell.
    os.environ.pop("GH_DEBUG", None)
    result = subprocess.run(["gh", "auth", "token", "--hostname", "github.com"],
                            text=True, capture_output=True, timeout=30)
    token = result.stdout.rstrip("\r\n")
    if result.returncode or not token:
        raise TokenCheckError("No existing GitHub credential is available")

    try:
        reference = publication.GitHub().api("git/ref/heads/main")
        if reference.get("object", {}).get("type") != "commit":
            raise TokenCheckError("Release API returned an unexpected repository reference")
        repository = tap.TapGitHub().api("")
        if repository.get("full_name") != tap.TAP_REPO:
            raise TokenCheckError("Tap API returned an unexpected repository")
    except (publication.PublicationError, tap.TapError):
        # CLI stderr can contain sensitive debugging information. Do not relay it.
        raise TokenCheckError("Authenticated release or tap API request failed") from None
    credential_round_trip(token)
    # GitHub documents dot counts for diagnostics. Do not decode or validate JWTs,
    # or require a particular shape/length for authentication to succeed.
    return {"status": "passed", "release_api": "passed", "tap_api": "passed",
            "git_credential": "passed", "installation_token": token.startswith("ghs_"),
            "token_length": len(token), "token_dots": token.count(".")}


def main():
    try:
        print(json.dumps(verify(), sort_keys=True))
        return 0
    except TokenCheckError as error:
        print(f"GitHub token check failed: {error}", file=sys.stderr)
    except (OSError, subprocess.SubprocessError, AttributeError, ValueError):
        print("GitHub token check failed: tool execution or API response error", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
