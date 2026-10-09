# Image compression runtime

Only `ImageProcessor.run(tool: .compress, ...)` uses this runtime. Image I/O
continues to validate and decode inputs and Core Graphics produces bounded,
oriented, 8-bit sRGB pixels. The small C bridge encodes those pixels with libvips:
MozJPEG for JPEG, lossless libpng for PNG and libtiff Deflate for TIFF. HEIC stays
with the system encoder. It has no API for opening source files, discovering
formats, networking or accepting arbitrary libvips operations. A successful
encoding is always published, regardless of its size relative to the original.

## Distribution and provenance

`CorePackage/Artifacts/FileMintCompression.xcframework` contains one arm64 macOS
13 dynamic framework. Its private libvips, GLib, PCRE2, proxy-libintl, MozJPEG,
libpng and libtiff code is linked into that framework; only two C symbols are
exported. Its external dependencies are macOS system libraries/frameworks. The
Finder extension and FileMintCore do not link or embed it. The framework is
ad-hoc signed in source; application packaging signs it with the host identity
before signing the app. No signing keys are stored in the artifact.

The exact unmodified source archives accompany the binary in `sources/`;
`sources.lock.json` records official URLs, versions and SHA-256 hashes. The C
bridge and `scripts/build_image_compression.py` are available under
LGPL-2.1-or-later. All dependency licenses are retained in those archives, and
`THIRD-PARTY-NOTICES.txt` accompanies the framework and main app. FileMint's
license does not replace these third-party licenses or restrict the LGPL
permissions described in the notices.

Keep this directory, the bridge, build recipe and artifact together in every
source tag distributing the runtime. The public source tag/source archive must
be available with each released binary. The existing GitHub release assets stay
DMG, checksum and appcast; GitHub's matching repository source archive contains
the corresponding dependency sources. A local working-tree build is not a public
source release. Do not publish a binary whose matching sources are unavailable.

## Rebuild

Normal app builds and offline tests consume the checked-in XCFramework. They
neither download dependencies nor rebuild this runtime. To replace the runtime,
use Xcode and Python 3.12+ with Meson 1.10.2, CMake 3.31.6, Ninja 1.13.0 and
pkg-config (the local build uses pkgconf 2.5.1). Put the tools on PATH or use an
isolated tools directory:

```sh
python3 scripts/build_image_compression.py --tools-bin /path/to/tools/bin
```

The recipe checks every source hash, builds everything for arm64/macOS 13 in
`build/image-compression.noindex`, generates the framework and records its hashes
in `artifact-manifest.json`. It performs no network requests or system installs.
Translation catalogs, optional codecs, C++ bindings, loadable modules, JIT,
introspection, docs, example programs and build tools are not shipped. Optional
dependency discovery is restricted to the private build prefix and macOS SDK.
Native sRGB conversion makes LCMS unnecessary for this encoding-only bridge.

The raw input buffer remains alive until synchronous libvips evaluation and
encoding finish. Operations use two workers, no operation cache and no disk
spill API. These settings do not impose a process RSS ceiling. Swift's existing
pixel limits, sequential batches and cancellation/publication checks still apply.

## Replacement and verification

Rebuild a compatible framework with the same header/ABI, then rebuild a separate
local FileMint app from the matching source checkout. Xcode embeds the replacement
from the local Swift package. For local library development, an unsigned build
can be generated without a Developer ID key:

```sh
make project
xcodebuild -project FileMint.xcodeproj -scheme FileMint -configuration Release \
  -derivedDataPath build/compression-replacement.noindex \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO ENABLE_HARDENED_RUNTIME=NO build
```

This affects only that development copy; keep the distributed app's hardened
runtime and signatures intact. No global Gatekeeper change is needed. Retain
the LGPL right to modify/replace the library and debug those modifications.
Local source rebuilds do not retain the distributor's signature/notarization.

Run `python3 scripts/verify_image_compression.py` to verify the checked-in
artifact, source hashes, architecture, deployment target and load paths. App
packaging additionally verifies the embedded framework with
`scripts/verify_bundle.sh`. Run the image regression suite and the applicable
checks from `specs/HARNESS.md` after changing the bridge or runtime. Record actual
tests separately from macOS 13, sandbox, native UI or publication evidence.
