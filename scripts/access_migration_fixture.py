#!/usr/bin/env python3
"""Assemble/sign an isolated sandbox migration pair; never publish a release."""
import argparse
import json
from pathlib import Path
import plistlib
import shutil
import socket
import subprocess
import sys

sys.dont_write_bytecode = True
import native_qa as qa

IDENTIFIER = qa.KINDS["access-migration"][1]
APP = qa.KINDS["access-migration"][0]


def run(args):
    subprocess.run(list(map(str, args)), check=True)


def validate_root(root):
    root = Path(root).absolute()
    expected = qa.ROOT / "build/access-migration-harness.noindex"
    if root.is_symlink() or root.parent.resolve() != expected.resolve() or not root.name.startswith("run."):
        raise ValueError("Use an owned access-migration build run")
    return root


def entitlements(sandbox, extension=False):
    if not sandbox:
        return {}
    value = {"com.apple.security.app-sandbox": True,
             "com.apple.security.files.user-selected.read-write": True,
             "com.apple.security.files.bookmarks.app-scope": True,
             "com.apple.security.temporary-exception.files.home-relative-path.read-write":
                 ["/Library/Application Support/FileMintAccessQA/"]}
    if not extension:
        value["com.apple.security.network.client"] = True
        value["com.apple.security.temporary-exception.mach-lookup.global-name"] = [IDENTIFIER + "-spks", IDENTIFIER + "-spki"]
    return value


def assemble(root, framework):
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    config = dict(identifier=IDENTIFIER, port=port, application=str(qa.app_path("access-migration")),
                  runID=root.name, sourceCommit=subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
                  nas="not-run: no user-supplied NAS")
    (root / "fixture.json").write_text(json.dumps(config, indent=2) + "\n")
    (root / "server").mkdir()
    for folder, build, sandbox in [("installation", "27", True), ("payload", "28", False)]:
        app = root / folder / APP
        (app / "Contents/MacOS").mkdir(parents=True)
        (app / "Contents/Frameworks").mkdir()
        shutil.copy2(root / "FileMintAccessQA", app / "Contents/MacOS/FileMintAccessQA")
        run(["ditto", framework / "Sparkle.framework", app / "Contents/Frameworks/Sparkle.framework"])
        info = dict(CFBundleIdentifier=IDENTIFIER, CFBundleName="FileMint Access QA",
                    CFBundleDisplayName="FileMint Access QA", CFBundleExecutable="FileMintAccessQA",
                    CFBundlePackageType="APPL", CFBundleVersion=build,
                    CFBundleShortVersionString="0.6.8" if sandbox else "0.6.9",
                    LSMinimumSystemVersion="13.0", NSPrincipalClass="NSApplication",
                    FixtureRunID=root.name, FixtureSandboxed=sandbox,
                    CFBundleURLTypes=[dict(CFBundleURLName=IDENTIFIER, CFBundleURLSchemes=["filemint-access-qa"])],
                    SUFeedURL=f"http://127.0.0.1:{port}/appcast.xml", SUEnableInstallerLauncherService=True,
                    SUEnableDownloaderService=False, SUEnableAutomaticChecks=False, SUAutomaticallyUpdate=False,
                    SUEnableSystemProfiling=False, SUVerifyUpdateBeforeExtraction=True,
                    NSAppTransportSecurity=dict(NSAllowsLocalNetworking=True))
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
        extension = app / "Contents/PlugIns/AccessFinderSync.appex"
        (extension / "Contents/MacOS").mkdir(parents=True)
        shutil.copy2(root / "AccessFinderSync", extension / "Contents/MacOS/AccessFinderSync")
        ext_info = dict(CFBundleIdentifier=IDENTIFIER + ".finder", CFBundleName="FileMint Access QA Finder",
                        CFBundleDisplayName="FileMint Access QA Finder", CFBundleExecutable="AccessFinderSync",
                        CFBundlePackageType="XPC!", CFBundleVersion=build, CFBundleShortVersionString=info["CFBundleShortVersionString"],
                        LSMinimumSystemVersion="13.0", LSUIElement=True, FixtureRunID=root.name,
                        NSExtension=dict(NSExtensionAttributes={}, NSExtensionPointIdentifier="com.apple.FinderSync",
                                         NSExtensionPrincipalClass="AccessFinderSync.AccessFinderSync"))
        (extension / "Contents/Info.plist").write_bytes(plistlib.dumps(ext_info))
        (root / (folder + "-host.plist")).write_bytes(plistlib.dumps(entitlements(sandbox)))
    (root / "finder.plist").write_bytes(plistlib.dumps(entitlements(True, extension=True)))


def embedded_entitlements(app):
    value = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(app)], capture_output=True, check=True).stdout
    return plistlib.loads(value) if value.strip() else {}


def sign(root):
    identity = qa.signing_identity()
    requirements = []
    for folder, sandbox in [("installation", True), ("payload", False)]:
        app = root / folder / APP
        framework = app / "Contents/Frameworks/Sparkle.framework"
        for executable in ["Sparkle", "Autoupdate", "Updater.app/Contents/MacOS/Updater",
                           "XPCServices/Installer.xpc/Contents/MacOS/Installer", "XPCServices/Downloader.xpc/Contents/MacOS/Downloader"]:
            path = framework / "Versions/B" / executable
            architectures = subprocess.check_output(["lipo", "-archs", str(path)], text=True).strip()
            if architectures != "arm64":
                run(["lipo", path, "-thin", "arm64", "-output", str(path) + ".arm64"])
                Path(str(path) + ".arm64").replace(path)
        extension = app / "Contents/PlugIns/AccessFinderSync.appex"
        for target, entitlement in [(extension, root / "finder.plist"), (app, root / (folder + "-host.plist"))]:
            run(["codesign", "--force", "--options", "runtime", "--timestamp=none", "--sign", "-",
                 "--entitlements", entitlement, target])
        qa.sign_bundle(app, identity)
        requirements.append(qa.verified_requirement(app, identity))
        assert embedded_entitlements(app).get("com.apple.security.app-sandbox", False) == sandbox
        assert embedded_entitlements(extension).get("com.apple.security.app-sandbox") is True
    if requirements[0] != requirements[1]:
        raise ValueError("Old/new designated requirements must match")
    (root / "signature-evidence.json").write_text(json.dumps(dict(
        bundleID=IDENTIFIER, requirements= requirements, hostSandbox=[True, False], finderSandbox=[True, True],
        notarized=False, note="Local Developer ID prototype; not a public release"), indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["assemble", "sign"])
    parser.add_argument("root", type=validate_root)
    parser.add_argument("framework", type=Path, nargs="?")
    args = parser.parse_args()
    if args.mode == "assemble":
        assemble(args.root, args.framework)
    else:
        sign(args.root)
