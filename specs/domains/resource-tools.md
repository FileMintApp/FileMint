# Image resource tools

Load for: Resource Tools menus, image processing, icon generation, stitching and OCR.

## Entry and privacy

- Resource Tools / 资源工具 is an independent Finder root and settings page under
  Extensions. Master defaults off; the original six child actions default on and
  retain choices when disabled. The new private-metadata child is visible in app
  tools, defaults on for new installs under the off master, and starts off for
  older saved child lists so it is not silently added to existing Finder menus.
- The app's Use Tools tab can explicitly choose local images even while Finder
  menu integration is disabled. The system file picker authorizes those files;
  this app-local request is never accepted from a URL/ticket. It does not expand
  monitored folders or enable Finder switches. Serialize it with all file requests,
  retain selected-file grants until close, and ask for an output folder if needed.
  Finder requests continue to recheck module, child and configured scope.
- Offer actions only for a complete, bounded selection of local image-file names
  inside configured scope, never background/toolbar/sidebar selections. Stitch
  requires at least two. Menu construction reads no image contents or thumbnails.
- Supported input names: jpg/jpeg/png/heic/heif/tif/tiff/bmp/gif. The decoder must
  also validate actual bytes. WebP, PDF, SVG, RAW, animation/multiple frames and
  HDR/high-bit-depth input are outside this first version; never silently take a
  first frame or infer encoding solely from an extension.
- A private single-use expiring operation ticket opens a main-app panel. Capture
  the complete selection; authorize exact parents, validate regular-file identity,
  and reject links, placeholders, directories or replaced inputs before reading.
  Recheck module/action/scope before execution and before publishing each result.
- Processing is entirely local, with no resource network calls, folder crawling,
  clipboard monitoring, content/path logs or persistent image/OCR history. Native
  output-folder selection grants access without broadening Finder menu scope.
- Original files are never changed. Each existing tool requires explicit Run;
  the Remove Private Metadata Finder command itself is the explicit Run, and app
  selection confirmation starts its job. Closing or cancelling before that
  writes nothing. Default output is a sibling copy;
  an explicit folder picker may select a different output. Collisions increment.
  Write in private staging on the destination volume, publish exclusively, and
  remove only owned staging. Never expose a partial file or overwrite a dangling link.

## Performance and lifecycle

- Heavy code lives in the app-only FileMintImages package target. The Finder
  extension links only lightweight Core rules and transports the selected URLs.
- One resource panel/task at a time, serialized with file operations. Quit and
  updater relaunch wait while the panel/request is active. No work is started on
  opening settings or building a Finder menu; no model is prewarmed.
- Maximum 100 inputs, each at most 64 MiB encoded and 64 million source pixels.
  Decode/render at most 16 million pixels and at most 16,384 pixels per dimension;
  OCR downsamples to longest edge 4096, icons to 1024. Validate dimensions and
  arithmetic before allocation. These are input/working limits, not an OS RSS guarantee.
- Preview uses at most 512-pixel thumbnails, built serially and on explicit panel
  demand; retain at most 20. A new selected item can replace an older cached preview.
  Original dimensions are captured in the same source read. Image data and decoded
  buffers are released per item. Parameter changes reuse thumbnails without decoding.
- Use background execution with balanced quality, sequential batch items and
  cooperative cancellation. In-flight system encoding may finish before stopping;
  cancellation suppresses publication, keeps previous completed outputs, and
  releases resources. Report completed, failed and cancelled outcomes accurately.
- A failure with zero completed outputs allows changing options and retrying in
  the same panel. Partial batches retain outputs and never automatically replay
  successful items.

## Actions

- Convert: JPEG, PNG, HEIC, TIFF only when Image I/O reports destination support.
  Normalize orientation; standard output is 8-bit sRGB. JPEG uses a visible white
  background choice/notice for transparency. Preserve alpha in compatible formats.
- Compress: keep JPEG/PNG/HEIC/TIFF source type; quality controls apply only to
  lossy destinations. PNG/TIFF use standard lossless encoding; no promised size
  reduction. No repeated target-byte search or extra optimization libraries.
- Resize: longest edge in pixels, preserving aspect ratio without enlargement;
  decode via Image I/O downsampling. User explicitly chooses output format.
- Icons: ICNS (16/32/64/128/256/512/1024), ICO (16/32/48/64/128/256), or a new
  folder of those PNG sizes through 1024. Fit source centered into transparent
  squares, never distort its aspect ratio. Only expose system-writable formats.
- Stitch: user-confirmed list order, vertical/horizontal, common short-edge size,
  no automatic content matching. Show bounded individual thumbnails; validate
  entire output geometry before allocating a canvas. Publish one PNG.
- OCR: Vision accurate text recognition with supported English and Simplified
  Chinese languages, performed locally. Show text and allow explicit Copy or Save
  TXT, including user edits in the result pane. No text is distinct from failure. Keep output at most 1 MiB per image and
  4 MiB per batch. Copy occurs only on the explicit Copy button.
  The editable result uses the shared plain-text editor with smart substitutions disabled.
- Remove Private Metadata: create a new `-clean` sibling copy (numbering
  collisions), never overwrite or modify the original. Initially accept standard
  single-image JPEG, PNG, TIFF and HEIC within the existing source limits. Reject
  unsupported, animated/multiple-frame, HDR, gain/depth, replaced or unavailable
  inputs; never downscale merely to remove metadata. Remove EXIF, GPS, MakerNote,
  IPTC, XMP, comments and text metadata while preserving visual orientation.
  Rebuild from decoded pixels as an sRGB image at the original dimensions, up to
  the 16 MP working limit. Explain that re-encoding may change file size or color;
  never claim lossless image-data preservation. Verify every
  staged output's metadata before exclusive publication. A failed verification
  publishes no copy. Work is local, cancellable and sequential; partial batches
  retain already verified copies with accurate counts. Filename text and private
  information visible in pixels are outside this action's claim.

## Working context

- Rules: `ResourceTools.swift`, `ResourceStrings.swift`; preferences and tickets
  in FileMintCore. Native engine: `CorePackage/Sources/FileMintImages/`.
- App: `ResourceToolsController.swift`, `ResourceToolsView.swift`;
  Finder adapter: `FinderSync.swift`; serialized routing: `FileOperationCoordinator`.
- Task: [image resource tools](../../docs/tasks/image-resource-tools.md).
- Checks: [Core](../verification/core.md), [native](../verification/finder.md).
