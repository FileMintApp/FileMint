# File drawer

Status: implemented and verified locally on the working tree based on `53be850`.

The current drawer has a dedicated path row, collapsible locations, keyboard file navigation and a contextual selection action panel. The earlier iterations below record the underlying per-location access, inline rename and window sizing.

Implement the approved interactive drawer as a native accessory window. The [drawer contract](../../specs/domains/file-drawer.md) owns this feature. Integrate with [startup](../../specs/domains/startup.md), [creation](../../specs/domains/creation.md), [favorites](../../specs/domains/favorite-locations.md), [file access](../../specs/domains/finder-permissions.md) and [presentation](../../specs/domains/presentation.md).

Acceptance follows the app, Core and native rows of the [Harness](../../specs/HARNESS.md). Verify actual fixture file operations, settings migration, width bounds, delayed preview admission and the native window. Environment-specific gaps are listed below.

## Drawer refinements

### Genie cadence at 60 Hz — 2026-11-23

The owner reported stuttering on a 60 Hz screen and paused 0.8.3 publication.
On arm64 macOS 27.2.1, the signed fixture reproduced it on a 5K external
display at 60 Hz and 2× scale. The first glass opening with the old mask
presented 15 frames, with a 33.3 ms median interval and a 66.7 ms maximum.
The baseline measures that first opening because the fixture compared two
spellings of its temporary folder path before the next motion.

The live glass and tint now share a `CAShapeLayer` mask at the window's backing
scale. The compositor rasterizes the mesh outline without a new AppKit bitmap
for every frame. The glass and moving controls still present in the same Core
Animation transaction.

- `run.7gq_zdez` passed `file-drawer-cadence` on `d6856c8` with the local fix.
  Three open/close cycles each for glass and solid backgrounds all presented
  28–31 frames with 16.7 ms medians. The worst interval was 33.3 ms.
- The same run stopped the general `file-drawer` suite at a settings-window
  focus assertion. The isolated rerun `run.t1tc2x2n` passed with the same code,
  including composited captures at three sizes on both edges in both directions,
  restored file rows, tint, reversal, resize and Reduce Motion.
- `make verify` passed with 467 Swift tests. The unsigned Release build produced
  arm64 executables for both FileMint and its embedded Finder extension.
  Logs are in `build/drawer-genie-cadence.IczG4I/`.
- The native reports in `build/native-checks.noindex/` cover the isolated
  signed drawer and the measured display. Moving an active transition between
  physical displays and running it on macOS 13/14 remain unverified.

At the owner's request, Developer ID signed Debug 0.8.2 (31) with the fix was
installed at `/Applications/FileMint.app`. Both running processes mapped the
new installed executables and Finder had one enabled registration. The prior
bundle archive and installation logs are in
`build/local-debug-install.noindex/genie-cadence.RkAF6E/`. The owner will check
animation quality on the installed build at 60 Hz.

When 0.8.3 release preparation resumes, feature the drawer prominently on the
Chinese and English website and include multiple real screenshots of its use.

### Drawer animations — 2026-11-22

Appearance settings offer Genie, Scale, and Slide and Fade. Genie is the default
when no valid effect is saved. AppKit supplies a temporary drawer image and a
Metal-backed view bends it into the selected edge. The snapshot uses the system
window background during the transition. Opening reverses the shape, and
interrupting the animation preserves the drawer session.

The first native runs stopped an opening before its intermediate frames
(`run.5mtu_z3k`, `run.6xzyg7ek`, `run.7qlaylao`). AppKit rounded a requested Y
origin of 329.5 pt to 329 pt. The drawer now compares requested frames so a
preference notification with identical layout does not end the animation.
The signed suite then passed on both edges in `run.5xtvggk2` before Genie became
the default.

Tested the final default on the worktree based on `a139fd6` on arm64 macOS 27.2.1
with Xcode 27.2.

| Check | Status | Observed result |
| --- | --- | --- |
| `make verify` | passed | 440 Core and 25 image Swift tests passed, plus the offline Harness checks. Local log `build/file-drawer-animation.gccoH3/verify-genie-default.log`. |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | The Release app and embedded Finder extension executables were present. Local log `build/file-drawer-animation.gccoH3/build-genie-default.log`. |
| `make verify-native-affected` | passed | Opening from settings played Genie by default. The fixture checked both edges, reversal, Scale, saved readback, and interrupting an animation with Reduce Motion. Local report and rendered intermediate frames in `build/native-checks.noindex/run.glu316rk/`. |

Inspected both rendered intermediate frames. Actual refresh rate, physical display
changes, macOS 13 runtime, and frame-by-frame comparison with the Dock effect
remain unverified.

#### Installed Debug — 2026-11-22

Rebuilt the direct-executable Debug configuration on the same working tree and
signed it with the existing Developer ID. Bundle verification passed for the
arm64 executables and the host and extension sandbox entitlements. Backed up
the prior installation, quit FileMint normally and installed 0.8.2 (31) at
`/Applications/FileMint.app`.

After launch, the App and the enabled Finder extension both mapped the new
installed executables. Their SHA-256 values matched the verified build. The old
bundle archive and the build, signing, install and runtime logs are under
`build/local-debug-install.noindex/drawer-genie.NbJ0Ii/`.

#### Genie opening and dismissal handoff — 2026-11-22

The user reported that the opening frame showed the desktop through the drawer,
and that the full drawer briefly appeared again at the end of dismissal. The
added native close check reproduced the live surface returning to full opacity
as the window closed in `run.j255ge48`.

The animation bitmap now composites the window background under the captured
controls and keeps the rounded silhouette. The live window material returns
when opening finishes. Closing orders the panel out before disposing of the
animation and keeps the live surface hidden during teardown.

The final working tree based on `a139fd6` passed `make verify` with 440 Core and
25 image tests. Unsigned Release compilation passed after regenerating the
project following the removal of a temporary indexing probe. Logs are in
`build/file-drawer-genie-handoff.Wkqg5i/`.

The signed drawer suite passed with the initial composition fix in
`run.w6u398pn`. After unifying the captured background tint, `run.d0hj6tzx`
stopped at an action-palette focus assertion before reaching animation. In
`run.bk8ji4q7` and `run.0o5bk961` the complete suite exited successfully and
checked opening and closing frame pixels on both sides, reversal, and the
hidden live surface after dismissal. The runner marked both reports blocked
because temporary Zed indexing probes changed its input fingerprint during
execution. Comparison showed only the indexing probes changing outside the
tested snapshot. The final observed frames are in `run.0o5bk961`.

The Developer ID signed Debug bundle passed bundle checks and was installed at
`/Applications/FileMint.app`. After launch, the running app and Finder extension
both mapped the verified replacement executables. The installation logs and the
previous app archive are in `build/local-debug-install.noindex/drawer-genie-handoff.6ZdEIj/`.

#### Genie material in both directions — 2026-11-22

The user clarified that the translucent glass should remain visible during both
opening and closing. The animation now warps a snapshot of the controls and
masks the native behind-window material with the same outline. The material
and controls present in the same transaction. With glass off or Reduce
Transparency enabled, the snapshot includes the system window background.
The panel still leaves the screen before the animation is discarded.

On the worktree based on `a139fd6`, `make verify` passed with 440 Core and 25
image tests, and the unsigned Release build passed. The signed drawer suite
passed in `build/native-checks.noindex/run.cw7mgy4x/`. It verified that both
directions mask the live glass along the moving outline on the right, use a
solid background on the left with glass disabled, and clear the mask at handoff
and dismissal. The saved PNGs are renderer frames, with the glass composed
separately by AppKit.

The Developer ID signed Debug 0.8.2 (31) bundle passed verification and was
installed at `/Applications/FileMint.app`. The running app and Finder extension
mapped the verified replacement executables. The former app archive and local
logs are in `build/local-debug-install.noindex/drawer-genie-glass.mafGir/`.

#### Genie backing pixels and motion — 2026-11-22

On a 2× display, a 420 × 820 pt probe put the original glass center at pixel
384 and the controls at pixel 820. The glass mask now uses the material view's
backing dimensions. A resize or a change of backing scale retires the old
transition. The 28 pt landing thumbnail preserves the resolved panel's aspect
ratio in automatic and fixed sizing modes.

A fixture minimized and restored its own marked window using the Mac's existing
Dock Genie setting. The near-edge sample took about half a second. Its attached
end narrowed while the body held position for roughly the first third. The
drawer follows that timing and a cosine taper relative to its own edge. The
window hands off after the endpoint is presented, with a timeout for occlusion.
A restored listing refreshes the moving controls once during opening.

The final working tree based on `a139fd6` passed `make verify` (440 Core and
25 image tests), unsigned Release compilation and the signed file-drawer suite
on arm64 macOS 27.2.1 with Xcode 27.2. The 2× window captures covered 640 × 929
pt adaptive, 320 × 1,100 pt tall/tinted and 1,443 × 480 pt wide drawers. Across
all 12 combinations of size, edge and direction, the sampled glass outline was
within 0.67 backing pixels of the mesh and the grip within one pixel of center.
The fixture checked file icons during expansion, motion endpoints, reversal
and resizing during opening. Its 1.94 s movie decoded to 80 frames. Inspection
showed the restored rows inside the expanding funnel.

The PNGs, movie and signed report are in `build/native-checks.noindex/run.vvry95f6/`.
The native reference measurements and final build and verification logs are in
`build/drawer-genie-motion.Um3Obd/`. The system comparison used one Mac and a
Dock target. A physical transfer between displays of different scales remains
unverified.

Built and installed Developer ID signed Debug 0.8.2 (31) at
`/Applications/FileMint.app`. Its drawer inputs matched the signed fixture.
The installed app and Finder extension mapped the verified new executables.
The prior bundle archive and the build, bundle and launch logs are in
`build/local-debug-install.noindex/drawer-genie-motion.f2rUWZ/`.

Earlier runs retain the first mask compilation error (`run.5s8wnphf`), the QA
recorder's background-color lifetime failures (`run.9efpxd66`, `run.4_xu_9qe`)
and a running-fixture guard (`run.g1372xju`). Using the recorder's default
background allowed `run.5fdq53zt` to capture the opening placeholder, which
led to the listing refresh verified in the final run.

### Drawer settings controls — 2026-11-21

Settings now shows the saved disk-root grant status and offers authorization when
the grant is missing or unusable. Opening from settings focuses an existing
drawer. Both sizing switches default on, with saved fixed sizes preserved.

Tested the worktree based on `d16477c` on arm64 macOS 27.2.1 with Xcode 27.2.

| Check | Status | Observed result |
| --- | --- | --- |
| `make verify` | passed | 437 Core and 25 image Swift tests passed, plus the offline Harness checks. Local log `build/file-drawer-settings.63oNb6/verify.log`. |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | Both Release executables were present. Local log `build/file-drawer-settings.63oNb6/build.log`. |
| `make verify-native-affected NATIVE_QA_SUITES=file-drawer` | failed on first run | The settings checks passed. The inline rename fixture timed out after retrying a colliding name. Local report `build/native-checks.noindex/run.ff89298x/report.json`. |
| `make verify-native-affected NATIVE_QA_SUITES=file-drawer` | passed on rerun | The fixture waited for the editor to become editable after a collision. The complete suite passed, including the grant status before saving, after saving and after revocation, and opening and refocusing the drawer. Local report `build/native-checks.noindex/run.sv67knkb/report.json`. |

The grant check used a temporary directory in the signed fixture. Real disk-root
consent remains a live acceptance boundary.

### Separate root authorization and location memory

The Full Disk Access row uses the native directory picker to save a root grant. The default location picker saves the display path. The Remember Last Location switch defaults on and restores the most recent authorized folder ahead of the selected default. The local position record carries only folder identities and a favorite reference, when applicable. Turning memory off clears that record.

On arm64 macOS 27.2.1, `make verify` passed with 429 Swift tests. The unsigned Release compilation passed. Signed `file-drawer` passed in `build/native-checks.noindex/run.pc1s5fhs/`. The fixture checked both picker targets, choosing a default without a grant, rejecting a subfolder during root authorization, the actual settings switch, current and fresh controllers restoring position, same-name replacement fallback, and reopening a session-only folder within its original controller. The root picker was inspected without granting real disk access.

Installed and launched Developer ID signed Debug 0.8.2 (31) from `/Applications/FileMint.app`. The host SHA-256 begins `a5d56413cc49`. The installed app and Finder extension matched the verified Debug build. The previous app archive is `build/debug-install-backups.noindex/location.eGoyPP/FileMint.previous.zip`.

### Open With, size limits and activation location

The drawer action palette offers Open With for complete file and folder selections. The app page combines configured apps with system suggestions and includes an explicit application picker. The original selection is checked again when opening it. Width and height each support minimum, maximum and fixed values. A valid fixed edit switches its axis out of automatic sizing, and the settings expose out-of-range drafts for correction. A configured default opens on each fresh presentation. An explicit folder choice sets the read/write grant root, while clearing the default retains saved permissions.

On arm64 macOS 27.2.1, `make verify` passed with 429 Swift tests and the unsigned Release build succeeded. The signed drawer fixture passed in `build/native-checks.noindex/run.4w40_fxd/` and includes `drawer-open-with.png`. Real settings fields rejected 702 pt above the active 590 pt maximum, applied the pending width after the maximum was raised to 720 pt, and retained a subsequent 572 × 631 pt window across reopening. The fixture also checked default location precedence, precise reauthorization, cancellation and resuming a previously visited folder without a default.

The signed Open With fixture passed in `build/native-checks.noindex/run.9ef78s94/`. Its receiver confirmed ordered delivery of an unknown-extension file plus a folder, and of a folder alone. It also rejected a changed application bundle at the same path and identifier. The initial combined run `run.dljh_jup` found an incorrect settings-test focus assumption and an unlaunchable temporary receiver copy. The focused reruns used the real field editor and an executable target accepted by the app sandbox for the replacement test. The production app validation was preserved.

Installed and launched Developer ID signed Debug 0.8.2 (31) from `/Applications/FileMint.app`. The host SHA-256 begins `f121bc37a97e`. Both installed executables matched the Debug build. The previous app archive is `build/debug-install-backups.noindex/openwith.enEl1s/FileMint.previous.zip`.

### Selection actions and keyboard navigation

Click a component in the full-width path row to enter it. Its context menu offers child browsing. Command-L toggles Locations, Shift-Command-L lists all standard and saved folders in a native menu, and Option-Command-1 through 9 remain direct destinations. In the file area, Up and Down move by sorted item in all three layouts. Right enters a browsable folder. Left returns to the parent and selects the departed folder after checking its identity.

Command-K and the Actions button show commands for the captured selection. Search actions by English or Chinese title, choose with Up/Down and press Return. Eligible folders can open FileMint's template draft directly in that folder. Opening a draft preserves the browsing location. Action dispatch validates all captured identities on the directory worker.

On arm64 macOS 27.2.1, `make verify` passed with 428 Swift tests, the unsigned Release build passed, and the signed `file-drawer` suite passed in `build/native-checks.noindex/run.4v_hx56k/`. The report and three screenshots are in that directory. Native cases include position-menu tracking and cancellation, switching to a custom folder, keyboard browsing through 51 entries in each file layout, returning from an empty folder, action search, template creation destination, and stale selection rejection. AppKit logged a transient discarded layout attribute for an empty collection. The visible-selection, scrolling and return-navigation assertions passed.

Installed and started Developer ID signed Debug 0.8.2 (31) at `/Applications/FileMint.app`. The app and extension binaries matched the verified build. The host SHA-256 begins `2947aed0cfcc`. The previous bundle is archived under `build/debug-install-backups.noindex/actions.ap9emX/FileMint.previous.zip`.

### Finder-style places and direct editing

This iteration adds a responsive sidebar with twelve built-in destinations and custom folders from Favorite Locations. Command-L searches every location. A place's first explicit activation can request its exact folder. Selecting its sidebar row or breadcrumb name goes to the directory itself. The new transition uses a fade with an eight-point edge offset. Users can configure height independently of width. The native file collection edits names in place and keeps the filename draft on a collision.

On arm64 macOS 27.2.1, `make verify` passed with 428 Swift tests. The unsigned Release build and the signed `file-drawer` suite passed. The final report and wide/compact captures are in `build/native-checks.noindex/run.i8puendw/`. Earlier fixture runs identified a temporary-path alias, a chooser focus race, a stale breadcrumb assertion and a file-row layout issue after resizing. The final fixture exercised all four boundaries, including immediate chooser reopening, while editing and switching directories using disposable files and grants. The design suite passed in `run._aebvtzv`.

Installed and launched Developer ID signed Debug 0.8.2 (31) at `/Applications/FileMint.app`. Both the app and embedded extension matched the Debug build. The installed host SHA-256 begins `72f498b8c16f`. The previous installation is archived in `build/debug-install-backups.noindex/places.82sVkb/FileMint.previous.zip`. Physical display changes and permission prompts against the user's protected folders were not exercised.

### Earlier local iteration

The root picker starts at the startup volume and accepts a narrower folder. A separate saved grant controls restoration. The file list offers four sort fields with reversible order and three persistent layouts. Command-F searches filenames in the open folder. The keyboard button explains local file-list commands when hints are enabled. The floating panel uses the native popover material and requests the active display's refresh rate for its full-width edge transition.

On this arm64 Mac, a local Debug measurement used 10,000 temporary files with Chinese and English names. The initial metadata read took 2.19 seconds and preparing the sorted snapshot took 168 ms. Forty queries over that snapshot took 15.6 ms at the median and 17.1 ms at the 95th percentile, excluding rendering. Network-volume latency was not measured.

`make verify` passed with 427 Swift tests. The unsigned Release app and Finder extension compiled. The signed `file-drawer` fixture passed in `build/native-checks.noindex/run.vjo62sko/report.json` on arm64 macOS 27.2.1. It exercised the unpinned creation and rename flows, search and sorting, view shortcuts with hints disabled, grant replacement and revocation during a sheet and during a draft opened elsewhere. The design suite passed in `run.8zcqi80r`. In that same earlier run the drawer fixture compared two spellings of the temporary directory. The corrected assertion checks the captured folder URL and independent grant.

The root picker and saved bookmark flows used disposable folders. Actual system-protected directories, physical multi-display transitions and delivered animation frame rates remain unverified. The installed app was not replaced in this iteration.

## Implementation and verification

The main app owns the panel, security-scoped browsing session and embedded Quick Look view. The settings and two menu commands use the existing preferences store. Core handles captured directory identities, exclusive file publication, same-volume moves and scoped copies. The drawer hands creation to the existing template draft with a verified destination. A same-session system Trash receipt offers Put Back when macOS returns an accessible location.

Tested on the local arm64 macOS 27.2.1 worktree based on `53be850`.

| Check | Observation |
| --- | --- |
| `make verify` | Passed, including 423 Swift tests, isolated filesystem fixtures and the Harness checks. |
| Unsigned Release compilation | App and embedded extension built with the project's macOS 13 deployment target. |
| Local trial bundle | Applied ad hoc signing with the project's entitlements. `scripts/verify_bundle.sh` verified the signatures, sandbox entitlements, arm64 executables and minimum OS. |
| Native drawer fixture | `run.qb08zxzr` passed window placement, width bounds, directory navigation, loading a selected text URL into the embedded Quick Look view, holding a large file until Space, stale selection cancellation and closing the browsing session. |
| Native creation integration | `run.3qve3d5_` passed the complete drawer suite and the real Create flow. The draft opened in the browsed subfolder, wrote the entered UTF-8 content there and refreshed the drawer. The default directory and parent listing were preserved. |
| Neighboring native fixtures | Creation opening and design UI passed in `run.1lp57390`. The drawer's initial test attempted a preference write during startup recovery. Its fixture now waits for settings readiness. Quick Search's focus assertion failed in that combined run and passed in isolation in `run.cvbqc69s`. The initial focus failure remains unexplained. |

Local reports live under `build/native-checks.noindex/<run>/report.json`. Multiple physical displays, macOS 13 runtime, protected-directory grants, real cross-volume transfers and system Trash restoration remain environment-specific checks.

## Navigation and shortcuts

The drawer has a searchable component menu below its selectable full path. An authorized component lists its direct children when opened. Selecting a file reveals it in its containing directory. Session tokens and file identity checks discard old results after dismissal, navigation or a same-name replacement. The command strip adapts to the selection and available width. The global drawer command defaults to Control-Option-D. Quick Search retains Control-Option-K and its saved combination.

The signed design and file-drawer suites passed in `run.mrxg85oa`, including AX activation of a component and file row, keyboard selection from a filtered sibling list, full-path reconstruction, stale item rejection and shortcut window toggling. The first hotkey run encountered an existing system registration while the installed FileMint had Quick Search enabled. After the previous Debug app quit, the same hotkey and Quick Search suites passed in `run.o2sku0pq`. The revised shortcut reservation is verified separately below.


Quick Search reserves its suggested shortcut and its saved combination even while disabled. A failed drawer edit preserves the prior registration. The final signed fixtures in `run.cdfcblxh` passed drawer navigation, independent Carbon delivery, reservation priority, opt-out, retry, import and rollback. An intermediate test exposed an entrance animation racing an immediate side/width change. Animating the contents leaves docking geometry under a single owner. The latest full `make verify` passed with 424 Swift tests, and the final unsigned Release and Debug builds succeeded.
