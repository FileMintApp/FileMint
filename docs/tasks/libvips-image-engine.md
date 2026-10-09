# Task: Dedicated image compression engine

Status: implemented; local verification passed
Related issue: [#7 — 压缩后的图片体积比原始文件还大](https://github.com/FileMintApp/FileMint/issues/7)
Next action: macOS 13 device acceptance and public distribution are separate follow-up work.

## Objective and scope

Route only the existing `compress` action through a dedicated compression engine.
Keep conversion, resize, icons, stitching, OCR, metadata cleanup, previews and
clipboard-image creation on their current system implementations. Preserve all
source authorization, input limits, output staging and cancellation boundaries.

The user explicitly clarified on 2026-10-09 that encoded size must never decide
whether to output a successful result. Equal-size and larger results are valid
outputs. Do not introduce a skip/no-gain state, target-byte search, hidden quality
reduction, resizing or palette quantization to force a smaller file. Show actual
original/output sizes and signed size change as information only.

## Selected context

- Contracts: [Resource tools](../../specs/domains/resource-tools.md),
  [Distribution](../../specs/domains/distribution.md) and
  [Presentation](../../specs/domains/presentation.md) for notices and result copy.
- Workflow/checks: [AI Playbook](../AI_PLAYBOOK.md), [HARNESS](../../specs/HARNESS.md),
  [Core checks](../../specs/verification/core.md) and the image-resource section of
  [native QA](../FINDER_QA.md#image-resource-tools).
- Entry points: `ImageProcessor.swift`, `ImageCompressionEngine.swift`,
  `ImageInput.swift`, `ResourceToolsView.swift`, `ResourceStrings.swift`,
  `CorePackage/Package.swift`, `project.yml` and runtime build/bundle checks.
- Dependency source, build and replacement documentation:
  [ImageCompression](../../ThirdParty/ImageCompression/README.md).

## Decisions and implementation

| Format | Compression provider | Policy |
| --- | --- | --- |
| JPEG | libvips + MozJPEG | Selected quality, progressive encoding and coding/scan optimization |
| PNG | libvips + libpng / system zlib | Lossless, filter optimization and compression level 9 |
| TIFF | libvips + libtiff / system zlib | Lossless Deflate with horizontal prediction |
| HEIC | Existing Image I/O encoder | Selected quality, same validation and publication path |

- Native inspection/decoding and Core Graphics normalize orientation, dimensions,
  sRGB and premultiplied alpha before the synchronous C call. No third-party
  decoder receives a source path or unvalidated encoded bytes. Native color
  conversion avoids adding LCMS to this encoding-only runtime.
- The C bridge accepts only bounded RGBA pixels and an owned staging path; it
  unpremultiplies for encoders and embeds a standard sRGB profile. JPEG's native
  context fills transparency white. Two libvips workers and no operation cache
  keep batches bounded without claiming an RSS ceiling.
- The bridge and its private static dependencies form a single dynamic
  `FileMintCompression.framework`, distributed as a local arm64 XCFramework.
  Only FileMintImages/the main app use it; Core and Finder stay independent.
  Offline builds/tests consume the checked-in artifact. Source archives, hashes,
  rebuild instructions and notices accompany it in the repository.
- Compression checks staged encoding/type/dimensions and then uses the existing
  exclusive publication path. Results and per-item byte counts are retained only
  for completed outputs. Partial failures retain previous results; cancellation
  suppresses unpublished outputs. There is no size comparison in publication.
- The selected item's result panel shows original bytes, output bytes and signed
  percentage change. Batch counts retain their existing meaning.
- Direct-link native harnesses embed the runtime through one shared helper. The
  release signer signs it before the app; bundle checks verify its architecture,
  deployment target, load paths, notices and absence from the Finder extension.

## Current implementation evidence

Verified on 2026-10-09 in the primary checkout at
`f029331b1d11c7fdc8a8810f776095a390208b96` plus these working-tree changes, on
macOS 27.2 arm64 with Xcode's macOS 27 SDK. The runtime itself targets macOS 13.

| Check | Status | Observed result |
| --- | --- | --- |
| Runtime build from locked source archives | passed | A clean build directory required no host image/GLib libraries or network; all seven dependency archives accompany the binary |
| Runtime artifact verification | passed | arm64, minimum macOS 13.0, two exported C symbols, system-only load paths, source/recipe/artifact hashes and notices |
| Runtime size | measured | Complete checked-in XCFramework: 4,099,602 bytes (about 3.91 MiB); source archives and build tools are outside the installed app |
| Compression regression tests | passed | Eight cases cover real smaller/equal/larger outputs, JPEG quality/progressive encoding, PNG/TIFF alpha/orientation, P3 color, HEIC, partial batches/collisions, revocation/replaced sources and cancellation |
| `make verify` | passed | 22 image tests, 220 Core tests, 5/5 public JSON cases, 10 CLI regressions and all applicable offline script checks |
| `make project`; unsigned Release `make build` | passed | Main app embeds the compression framework; Finder extension has no link or embedded copy |
| Local signing and `verify_bundle.sh` | passed | Nested framework signing, arm64-only binaries, deployment target, notices and existing sandbox/Sparkle entitlements |
| Hardened Runtime + App Sandbox execution | passed | Independently identified probe and framework signed with the same existing Developer ID; JPEG/PNG/TIFF encoded and decoded inside its own container, then owned sample files removed |
| Native resource fixture | passed | Final run exercised all seven production panels in Chinese/light and English/dark, checked compression byte counts for both inputs, and preserved originals |
| Visible compression panel | passed | Inspected both languages and selected-item switching at 820×560; shortened the hint after observing the English result needed scrolling |
| macOS 13 device, installed Finder, public release | not-run | Deployment/load-command checks and isolated fixtures do not prove these environments |

The initial broad native-fixture attempt stopped before completing OCR with a
generic fixture failure; the final separately identified fixture completed all
14 panel scenarios. The first sandbox probe used ad-hoc signing, which macOS
rejected under library validation. Signing that isolated probe and framework
with the same Developer ID passed without changing sandbox/library-validation
entitlements. This was a local test, not notarization or publication.

The last runtime rebuild after adding build-directory guards produced the exact
same framework binary as the verified native fixture (SHA-256
`68a3ca859ee9dcc2f91ca5a34fb31d47221fc5e760442802815234b484ee5ca7`).

Local ignored evidence:
[clean runtime build](../../build/image-compression.noindex/clean-rebuild.log),
[offline checks](../../build/image-compression.noindex/verify-final.log),
[Release build](../../build/image-compression.noindex/app-build-final.log),
[native fixture](../../build/image-compression.noindex/native-run-final.log),
[sandbox readback](../../build/image-compression.noindex/sandbox-qa/result.log).
Historical measurements below are not measurements of this runtime.

## Historical isolated probe evidence


Tested checkout: primary FileMint checkout at
`f029331b1d11c7fdc8a8810f776095a390208b96`, with product sources unchanged.
Environment: macOS 27.2 arm64, Apple Clang 21, libvips 8.18.7, Meson 1.10.2.
The probe uses existing host GLib 2.80 and libjpeg-turbo 3.0.2, plus system expat
and zlib. These host libraries are experimental inputs, not production pins.

| Check | Status | Observed result |
| --- | --- | --- |
| JPEG-only C API library build | passed | Optional format libraries, C++ binding and dynamic modules disabled |
| Relocated runtime dependency closure | passed | Eight bundled dylibs; no `/opt/homebrew` load commands remain |
| JPEG decode, resize and encode | passed | 480×320 input produced a decodable 240×160 JPEG; disabled PNG/TIFF/HEIC save operations absent |
| Runtime payload size | passed | 6,159,584 bytes, including the 2,008,320-byte libvips core and all non-system dynamic dependencies |
| Size-only UDZO comparison | passed | FileMint 0.6.8 App copies: 6,704,286-byte baseline DMG and 9,386,351-byte probe-payload DMG; delta 2,682,065 bytes |
| Production JPEG/PNG/TIFF/ICC runtime | not-run | Requires pinned source builds and the actual selected JPEG backend |
| macOS 13 compatibility | not-run | Some host dependencies target macOS 14; rebuild the entire production closure for macOS 13 |
| App integration, sandbox and native UI | not-run | Probe is a standalone C client; payload-only App copy does not link or execute the added runtime |
| Performance and peak RSS comparison | not-run | The small functional fixture is not a representative benchmark |
| Context documentation checks | passed | `make verify-context`; 21 documents, 117 local links and entry size 6,998/7,000 bytes |
| Task document links and whitespace | passed | Seven local links exist; no trailing whitespace |

Recorded configuration and measurements:
[runtime manifest](../../build/libvips-minimal-2026-10-09.noindex/runtime-manifest.json),
[build options](../../build/libvips-minimal-2026-10-09.noindex/build-options.json),
[configure log](../../build/libvips-minimal-2026-10-09.noindex/meson-log.txt).
These are local ignored evidence artifacts and may be regenerated after cleanup.
The temporary source, C client and relocated dylibs remain under
`/private/tmp/filemint-vips-minimal.7DrP8O` for the current session.

The earlier general-purpose arm64 package reference added 8,561,873 DMG bytes
and 18,263,147 App bytes. Neither reference measures the proposed complete
first-stage runtime or a shipped integration.

## Handoff

- Preserve the user-confirmed output policy: every successful encoding produces
  a copy, including equal or larger results. Size feedback is informational.
- Keep native fixture, build, macOS 13 and public-release evidence distinct.
  Git delivery associates the implementation with Issue #7; it does not establish
  installed-device or public-release acceptance.
