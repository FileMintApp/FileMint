# Task: Eight file drawer positions

Status: complete
Next action: —

## Objective and scope

- Offer four edge centers and four corners as a single saved appearance choice.
- Apply the position to the existing drawer window, width grip and all three effects. Cover open, close and reverse with Genie at every position.
- Preserve existing settings and the current browsing session when repositioning. Keep active interactions in place until they complete.

## Selected context

- [File drawer contract](../../specs/domains/file-drawer.md#window-and-interaction) and [startup preferences](../../specs/domains/startup.md)
- `FileDrawerPreferences` and `FileDrawerGenieGeometry` in Core, plus the app's drawer settings, controller and transition
- [Harness matrix](../../specs/HARNESS.md#choose-checks-by-change) and [signed drawer fixtures](../../specs/verification/native-qa.md#automated-local-checks)

## Decisions and progress

- Keep the persisted field and the legacy left and right values. The pointer display's usable area and the position's normalized anchor drive placement and transitions.
- Keep the horizontal taper and add a vertical axis and a mirrored two-axis corner taper. The same grid supplies the rendered controls and full glass outline.
- Treat a change of anchor as geometry invalidation even if a constrained panel has the same frame. Reuse the visible panel when applying a new position.
- Focus the position grid as a group for arrow navigation. Individual buttons remain accessible and indicate which position is selected.

## Evidence

Tested worktree based on `988691e`, arm64 macOS 27.2.1 and Xcode 27.2.

| Check | Status | Observed result |
| --- | --- | --- |
| `make verify` | passed | 471 Swift tests and the offline checks. Log in `build/drawer-positions.7zcdQE/verify-final.log`. |
| Unsigned Release build | passed | The FileMint and embedded Finder extension arm64 executables were present. Log in `build/drawer-positions.7zcdQE/build-final.log`. |
| Signed `file-drawer` | passed | Eight positions set through the picker, arrow navigation, deferred reposition after rename, opening and reversing, equal-frame anchor invalidation, diagonal Slide and Scale, and transfer between the attached displays during a corner opening. The 32 composited midpoints had at most 0.91 backing pixels of sampled outline error. |
| Signed `file-drawer-cadence` | passed | The 60 Hz, 2× display presented 28–31 frames in each of 36 sampled motions. All medians were 16.67 ms and the largest interval was 33.33 ms. The right, top and top-right were tested with live glass and solid backgrounds. |

The signed report and logs are in `build/native-checks.noindex/run.ma9p6rhn/`.
The fixture saves captures in the runtime root named in `file-drawer.log`.
An earlier cadence run, `run.wxnzh9md`, recorded six presented frames in one
top glass opening. The cause was unconfirmed. The final run passed the same
60 Hz threshold without reproducing the short sample.

## Handoff

- The signed fixture transferred an opening drawer between the attached displays.
  Physical disconnection, changing display scaling and runtime on older macOS
  versions remain unverified.
