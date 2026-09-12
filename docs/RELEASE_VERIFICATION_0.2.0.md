# FileMint 0.2.0 — published artifact verification

Verified on 2026-09-13 (Asia/Shanghai).

- [Public release](https://github.com/FileMintApp/FileMint/releases/tag/v0.2.0)
- [Release workflow](https://github.com/FileMintApp/FileMint/actions/runs/34706651412)
- [CI](https://github.com/FileMintApp/FileMint/actions/runs/34706649687)
- Tag: `v0.2.0`
- Source commit: `b5ba4459237f111ac8d95617cfd2007657a90ce8`
- Asset: `FileMint-0.2.0.dmg` (3,946,055 bytes)
- SHA-256: `b22fe4f12e0f01055453a0d72537f85f198b7f8fe3df1431aa6c2f30face5ac8`

The public DMG was downloaded after publication, rather than substituting a local
build. Its checksum matched the published manifest. GitHub attestation verification
passed with a matching SLSA provenance subject. The mounted DMG and its app passed
nested ad-hoc code-signature, arm64/x86_64, version and bundled-license checks.
The DMG's LICENSE.txt and the app's Resources/LICENSE matched the repository license.

That downloaded app was installed at /Applications/FileMint.app and launched
successfully. The app displayed the saved enabled startup/menu bar switches,
Follow System language, the Folded F icon and a ready Finder extension. PluginKit
showed one enabled installed extension. Obsolete development/staging registrations
and bundles were removed; source and user-created files were retained.

The detailed functional and performance checks are in [ACCEPTANCE.md](ACCEPTANCE.md).
This remains a GitHub provenance release with ad-hoc bundle signatures, not an
Apple Developer ID-signed or notarized release. Clean-machine Gatekeeper behavior,
physical Intel execution and a system reboot were not tested on this host.
