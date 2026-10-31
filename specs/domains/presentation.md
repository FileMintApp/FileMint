# Appearance, website and product copy

Load for: Native appearance, icons, README/website copy, GitHub issue forms, roadmap presentation and license/privacy claims.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## Appearance

- Approved UI/UX v1 uses three explicit sidebar groups: File Creation (Templates
  & Types, Creation), Extensions (File & Folder Tools, Resource Tools, Open with App,
  Favorite Locations), and
  Preferences (General, Shortcuts & Launchers, Finder & Folders, About). Arrow-key navigation follows
  that visual order. Future implemented tools join Extensions without placeholders.
- Use restrained adaptive porcelain/graphite surfaces and a muted mint accent,
  shared row/section/button spacing, a quiet breadcrumb and a fixed New File action.
  Status reflects real extension/login/update state; no sample metrics or claimed
  permissions from the design prototype may reach the product.
- Creation, File & Folder Tools, Resource Tools, Open with App and Favorite
  Locations put a Finder Menu group first, using shared settings rows and trailing
  controls while preserving each module's switch semantics. Resource Tools shows
  its default-off Finder integration and seven app actions on one scrollable page;
  child settings may collapse, while the master and enabled count stay visible.
  App actions remain usable when Finder integration is off.
  Native processing windows use a bounded image preview, parameter inspector,
  thumbnail selection and fixed bottom actions. OCR puts source and editable
  result side-by-side; conversion never displays a fabricated compressed size.
  The creation panel uses a filename-first form, destination and content with
  persistent labels, familiar keyboard shortcuts and adaptive native fields.
- A selected post-creation application shows its native icon beside its name in
  the template editor and creation panel, including an unsaved temporary choice.
  Resolve only an explicitly selected local reference; an unavailable application
  or portable hint keeps its name and uses a generic application icon. Icons are
  decorative, add no focus stop, and perform no lookup while opening is disabled.
- No looping animation, eager model loading, remote assets or extra UI library.
  Use a single sidebar material at most, with native reduce-transparency behavior;
  the remaining surfaces are inexpensive adaptive colors.
- Quick Search uses a quiet command-palette layout: a large borderless native
  search field, a compact category strip, grouped results and a fixed keyboard
  action footer. A restrained mint search mark, tinted symbol tiles and a fine
  selected-row border provide FileMint identity on porcelain/graphite surfaces.
  Hide redundant title-bar controls while retaining a named, movable, resizable
  native panel and a visible accessible Close button. Start at 680 × 500 points,
  with a 520 × 360 minimum, clamped to the available screen. Keep results scrollable,
  hints readable, hover distinct from selection, and errors visible above the
  footer. Keep a fixed 12-point gap outside the results scroll view above the
  footer separator, including while the list is scrolled. Preserve native text
  editing, IME, accessibility and both languages.

- Native controls and adaptive system colors. Settings switches use the native
  small control size, preserving readable labels and keyboard/accessibility support. Settings use a persistent leading
  sidebar and a resizable detail area, with General, Creation, Templates & Types,
  Finder & Folders, File & Folder Tools, Resource Tools and Open with App under Extensions, and About, grouped as above. Each page has a title, concise explanation and
  functional sections; list actions stay next to their list. No decorative cards
  or disabled placeholders for future roadmap features. Follow system language
  by default; English and Chinese can be selected explicitly.
- General owns appearance, language, startup/menu bar, Quick Search's global
  shortcut switch/recorder and automatic-check preferences.
  Its Appearance group contains Theme (Follow System, Light, Dark), interface
  language and Finder Menu Icons (Colored, System Monochrome). Settings pickers
  use native small menu controls with adaptive primary
  text and a shared trailing edge aligned with switches; fixed control columns
  must not center a narrower visible control. Preference labels, supporting text,
  section headings and secondary actions share the same sizing and spacing.
  Creation owns New File menu location, quick-creation collisions and reveal-after-creation. Templates &
  Types owns the existing enabled/order/custom-type management. Finder & Folders
  owns extension status, folder scope/access and optional Full Disk Access guidance.
  About retains its credits and update actions. New File remains reachable from
  every page. Settings navigation itself never writes preferences or creates files.
- Use a 1040 × 720 initial content size and a 960 × 680 minimum where the display
  permits. Clamp to the screen's visible content area on small displays and keep
  the page scrollable without clipped controls. The creation panel size stays compact.
  Settings detail pages share a 30-point bottom inset outside their scroll or
  list area, keeping content and bottom actions clear of the window edge even
  when long content is scrolled to the end.
  Sidebar labels, focus/selection and controls remain readable
  in English/Chinese and system light/dark appearances. Native keyboard and
  accessibility labels must remain available; icons supplement text, not replace it.
- Sidebar navigation uses a continuous background and a subdued mint selection
  with a stronger label/icon, rather than the system List's bright selection fill.
  The selected row has a lightly visible mint surface in addition to its fine
  outline, so the active page remains clear without becoming a solid highlight.
  Hover and keyboard focus remain distinct from the selected page; arrow keys
  move between page buttons and the current page is exposed to accessibility.
- File & Folder Tools groups its module switch, root icon and Menu actions under
  the first Finder Menu heading, using native small switches and softly bordered
  grouped rows for the tools.
  Align menu-position pickers on the trailing side; keep descriptions and secondary
  options next to their tool. Use compact spacing, adaptive surfaces and mint
  accents. Menu-position picker values use the adaptive system control text color,
  reserving mint for enabled accents and selected controls. When the module is off
  the entire child area stays visible, grayscale
  and noninteractive. An individual disabled tool retains its available checkbox,
  with a muted icon and disabled secondary controls. Preserve readable contrast,
  wrapping, scrolling and native keyboard/accessibility behavior at minimum size.
- In Colored mode, the New File Finder entry in submenu mode has the small FileMint logo by default and a
  localized label. New File… carries that logo by default at either menu level. File & Folder Tools uses the system
  `wrench.and.screwdriver` symbol in mint/blue; the temporary Move Selected
  Items Here entry uses `arrow.right.square` in mint/teal. Both are 16 × 16
  palette-colored images that keep their theme colors in the native menu and
  remain readable with menu selection. Each file-tool action has a matching
  colored SF Symbol in settings and Finder, at both main-menu and submenu levels:
  names use blue `doc.on.doc`, paths indigo `link`, file contents blue/teal
  `doc.text`, move teal `folder`, permanent
  deletion orange `trash`, AirDrop purple `airplayaudio`, and desktop aliases blue
  `arrowshape.turn.up.right`. The temporary move
  destination retains its mint/teal icon in either location. Default icons use
  16 × 16 non-template menu images; color supplements recognizable shapes and
  text. New-file actions and every template choice have a meaningful default
  system symbol. The Finder toolbar and macOS menu bar retain the small template
  glyph those entry points require.
- Finder menu icon customization covers the New File root and its actions,
  every template, the File & Folder Tools root and children (including Move Here),
  the Resource Tools root and children, and the Open with App and Favorite
  Locations roots. Users search and browse a bundled catalog of system symbol
  names, choose an available SF Symbol and primary/secondary colors with a live
  preview, and can reset each entry to its default. The catalog excludes
  restricted and deprecated names, rejects known restricted names even when
  entered manually except for an action's own referential default, presents
  results incrementally, and checks
  actual availability on the running macOS version. An exact name field permits
  newer symbols not yet in the bundled catalog. Use the
  system's symbol and palette rendering APIs; do not import arbitrary images or
  fetch icon assets. The selected icon follows the action across main-menu and
  submenu placement. Keep text labels, keyboard access and light/dark/menu
  selection legibility. Configured App entries continue to use their app icons;
  Favorite Locations child actions and saved-item entries keep their existing
  icons. Their icons are not customizable.
- Finder Menu Icons is one global style for FileMint's own menu symbols, template
  entries and logo. Colored retains the existing palette. System Monochrome uses
  native monochrome SF Symbols and the existing F silhouette. Each Finder menu
  carries non-template monochrome bitmaps resolved from the extension's current
  system appearance: white in dark menus and black in light menus, including the
  F logo and template choices. Their legibility must survive image-only transfer
  and highlighted rows, without relying on Finder to tint template metadata. Rebuild from the
  current appearance when opening a menu; a system theme change needs no relaunch
  and the main app's window theme never overrides Finder's theme. The default New
  File logo uses the existing monochrome F silhouette. Configured App entries
  retain their native application icons; Finder toolbar and menu-bar glyphs keep
  their existing template behavior. Style changes never alter targets or labels.
  Icon editor and settings previews use native template tinting and follow the global style; color controls are
  disabled in monochrome mode with guidance that saved colors return in Colored.
  Users may still change a symbol or reset an override while in monochrome mode.
- App logo: a distinctive folded-paper F in fresh mint on a warm porcelain
  macOS tile. Dock/application assets use the image master; menu bar and Finder
  toolbar use a separately drawn crisp monochrome F silhouette. No medical-style
  plus badge. `make icon` regenerates the asset catalog from the masters.
  The generated Xcode project is never edited directly.
- Optional modules show enabled, applicable entries at their configured main-menu
  or submenu level; empty submenu roots are hidden. Chinese copy uses 拷贝 for Copy; the file-tools root is 文件（夹）工具.
- Open with App uses the same grouped rows and trailing menu-position controls,
  with real application icons, a visible drag handle, accessible reorder actions
  and a nearby Add App action. Recognized terminal rows show a directory opening
  dropdown beside the menu-position dropdown; other apps keep a compact row. Actions for moving,
  repairing and removing an entry remain keyboard accessible. Its empty state is
  functional and concise; the entry and Finder group use `square.stack.3d.up` and child
  entries use the selected app's native icon.
- Favorite Locations uses a searchable virtualized list, compact rows with native
  icons and parent paths, clear pinned/unavailable states, adjacent add and batch
  actions, and a focused quick-search panel. Finder's direct Add action appears
  once; the separate submenu remains bounded to pinned/recent choices and Search
  All. Resource Tools adds a
  seventh card for private metadata removal and shows progress/results without
  an extra Run button after the user's explicit selection.
- Hide & Unhide uses the existing file-tool switch/placement/icon row with an
  indigo/purple `eye.slash` default symbol. Its Finder entries use the explicit
  selection-based [file-tool labels](file-tools.md#hide-and-unhide-selected-items).
  The guide and privacy copy describe selected-item metadata changes and the
  dot-name limit; remove the old global-toggle permission flow and screenshots.

## File information presentation

- File Info uses one resizable native window, initially 600 × 560 pt with a
  520 × 480 pt minimum (bounded by screen), porcelain/graphite system surfaces
  and mint accent. A scrollable single column contains icon/name, metadata,
  algorithm picker with a persistent label and explanation, selectable monospaced
  results, and collapsed comparison. Bottom actions stay reachable. Long paths
  can be expanded, selected and explicitly copied; SHA-512 wraps at readable size.
- SHA-256 is labeled recommended; MD5/SHA-1 carry compatibility labels and quiet
  amber information warnings. Do not require additional confirmation. Show
  distinct not-calculated, waiting, progress, completed, cancelled and failed
  states. Completed results describe this read, without promising live validity.
- Use one Calculate/Recalculate primary action, Cancel while working, per-result
  Copy and Copy All in All mode. Disable algorithm changes during work. Comparison
  has explicit editable input and text/icon match state; All asks for one algorithm.
  Unsupported items/directories disable calculation with a reason.
- Escape and Command-W close and cancel. Return calculates only when enabled and
  outside multiline editing. Preserve visible keyboard focus, natural Tab order,
  Chinese/English, light/dark appearance, Reduce Transparency and VoiceOver labels.
  The settings row follows existing child enablement, placement and icon controls.

## Batch rename presentation

Implementation contract; phase evidence is tracked in the batch-rename task. [File tools](file-tools.md#batch-rename)
owns the rules, supported storage, counts, explicit actions and recovery behavior.

- Use one native app-owned window with a rule/list inspector, a virtualized table
  of every original/final filename and state, and fixed counts/actions. Preserve
  readable full names through accessible labels/details; an ellipsis is not the
  only way to inspect a proposed target. Show metadata preparation and rule errors
  plainly without technical backend details in the normal user flow.
- The rename workspace uses the shared porcelain/graphite surfaces and mint
  accent. A quiet header identifies the operation and selection count; the
  inspector groups the mode switch, ordered rule cards and adjacent Add Rule
  action. With no rules, offer clearly labeled starting actions for replacing
  text, adding a prefix and numbering, plus access to every other rule. These
  actions add one ordinary editable rule, never a saved preset or an execution.
- Keep original-name ordering next to the preview it affects. Give new names
  stronger emphasis than originals; use text and symbols for row states, never
  color alone. Keep every row visible in the virtualized table. Selecting a row
  exposes selectable full names and any issue/current location. A visible
  problem summary can select the first invalid/conflicting row without changing
  the plan or hiding other rows.
- Put the readiness/result summary, actual counts and naming guidance in a
  prominent notice above the right-hand preview table. Use a clear heading,
  status icon and contrasting surface/border; explain the next action and show
  the concrete first issue when invalid or conflicting names block submission.
  Keep Show First Issue next to that explanation. The protected-extension/hidden
  status reminder belongs here too, rather than in a quiet inspector footer.
  Preparation, ready, errors, running, stopping and results remain distinct;
  empty rules/no changes use guidance rather than warning styling. The fixed
  footer contains the commit/cancel/stop and applicable recovery actions, without
  duplicating the status notice. At minimum size, both inspector and names remain
  usable and long explanations scroll or wrap without displacing the actions.
- The preview supports ordinary local files and folders. Explain actual access,
  unavailable-item, collision and unsupported-operation failures at their failed
  stage; do not require a storage-ownership confirmation or claim that a location
  has been proved unmanaged. Compatibility notes do not add a separate gate to
  the normal preview/commit flow.
- Label the exclusive modes Rules / 规则 and Name List / 名称列表. The list editor
  says names exclude protected extensions and files without a suffix must stay
  suffixless; adding a period to such a file's body shows a row error. Ordinary
  directory names may still contain internal periods. Support explicit Paste and
  standard editing, and disable smart substitutions. Reassigning a populated list
  after an order change uses the owning contract's confirmation, with Cancel default;
  mode changes preserve in-memory drafts and invalidate the submitted preview.
  Confirmation uses a compact native sheet sized to its content and owned by the
  current workspace. Return and Escape cancel; only the explicit Reassign action
  applies the new mapping.
- Rename N Items / 重命名 N 个项目 and Undo N Items / 撤销 N 个项目 explicitly commit
  their complete previews. Ordinary Return edits/confirms the focused field or
  inserts a list newline; it never commits. Command-Return invokes only an enabled
  visible commit action; Escape closes before execution or requests Stop and Restore
  / 停止并恢复 during execution. Running close requests the same safe stop path;
  it does not discard remaining originals or imply rollback has already completed.
- Results distinguish success, fully restored cancellation/failure, and items still
  needing recovery. A durably committed batch awaiting cleanup offers Finish
  Operation Cleanup, not an action promising to restore original names; metadata-only
  finalization stays distinct from cleanup requiring the exact parent grant.
  Show actual counts/locations and explicit recovery/reveal actions; do not claim all-or-nothing success or send details to logs. A recovery
  card outside disabled settings remains usable without enabling new rename work.
- The recovery card also exposes Export Recovery Evidence and Unblock… /
  导出恢复证据并解除阻塞… under the [manual resolution protocol](file-tools.md#manual-resolution-of-recovery-records).
  Explain remaining staging files, loss of automatic recovery/current rename undo,
  and manual-handling acknowledgement before export, with Cancel as default.
  Show export/finalization failures without clearing the blocker; distinguish a
  manually closed operation from verified restoration. No automatic discard action.
- The new settings row follows existing file-tool switch/placement/disabled rules,
  with mint/teal pencil as the default SF Symbol and normal icon customization.
  Preserve Colored/System Monochrome, Chinese/English, minimum window size,
  keyboard focus, VoiceOver and Reduce Motion. Add no simulated Finder-menu mock,
  remote assets or new UI dependency.

## Product presentation

- The bilingual website uses a workflow-led landing page: a real product capture,
  selectable creation/image/app/Quick Search scenarios, a compact capability overview, local
  processing facts, installation FAQ and a clear download action. Keep the mint
  identity, readable mobile layouts, keyboard controls and reduced-motion support.
  Guides and privacy pages describe capabilities without stale release banners;
  historical compatibility and updater exceptions retain their actual versions.
  The Quick Search scenario shows a real matching-language panel capture, names
  the optional Control-Option-K shortcut and links to the usage guide. Preserve
  accessible tab selection, arrow/Home/End navigation and screenshot enlargement
  across all four scenarios, with readable labels at narrow widths.
- Give Batch Rename and File Info/checksums a prominent bilingual homepage
  showcase with real, matching-language captures and direct usage-guide links.
  Explain preview-before-commit, protected extensions, conflict blocking and
  explicit undo for rename; metadata-first opening, explicit calculation and
  copy/comparison for checksums. Identify both tools as opt-in and retain their
  actual selection/filesystem limits in the guide. Do not imply encryption,
  proof of origin, atomic batches or universal cloud/NAS compatibility.
- The homepage also introduces Quick Search and its optional global shortcut,
  Copy File Contents, direct creation drafts and compact/keyboard-friendly
  native interactions. Give each workflow a clear bilingual guide link and
  state its actual defaults and limits. Keep the current-release label dynamic;
  do not turn the homepage into a hard-coded release banner or simulated app UI.
- Promote Quick Search in the hero and navigation, with a dedicated bilingual
  showcase immediately after the hero. Use typographic Control-Option-K keycaps
  and the four actual search categories: creation actions, enabled templates,
  saved favorites and settings. Explain that the global shortcut starts off,
  can be customized and works while FileMint is running. Keycaps illustrate the
  shortcut; do not simulate a working native search panel or imply whole-disk
  search, inferred Finder targets or additional launcher integrations.
- Current-release labels come from the public GitHub `releases/latest` endpoint
  for FileMintApp/FileMint at page load, never from project.yml, README release
  includes or a hard-coded version. Accept only published, non-draft,
  non-prerelease stable tags. Share one bounded request per page session; fetch
  no credentials and render no remote HTML. On failure retain a working GitHub
  latest-release link and a neutral Latest stable release label, without claiming
  an unverified version. Site builds remain offline with respect to release data,
  so pre-publication builds cannot bake an unpublished release into the page.

- Release-related website changes are built before public Release availability
  and deployed afterward from that exact successful build artifact. A push can
  build the website but must not automatically deploy unpublished release copy.
  Website failures have a separate status from application publication.
- Website updates on main automatically deploy after a successful push build,
  independently of App source changes since the latest public stable tag. Publish
  only the exact successful Pages artifact, with validated repository, current
  main, stable-release ancestry, run and unexpired artifact IDs. Superseded builds
  are skipped with a clear reason; API/identity errors fail closed. Manual retry
  uses the same checks. This path never builds or publishes the App, moves tags
  or changes release assets. Website copy must describe publicly available
  features or clearly identified plans; new-release copy still follows the
  release-dispatched build and post-publication deployment workflow. Native path
  differences are not evidence that independently reviewed website copy is premature.
- Website homepages present the current creation, text/Office templates,
  clipboard-image creation, Open with App, file tools, image tools and appearance
  choices in both languages. Use real app captures with matching-language captions;
  identify example configuration without implying those apps or switches are defaults.
  Installation and privacy copy must also cover explicit clipboard-image capture,
  local document-template storage and optional weekly update metadata checks.
- The website provides a discoverable bilingual usage guide with task-based steps,
  matching-language screenshots with text alternatives, keyboard guidance and
  remedies for missing Finder menus or folder access. Keep installation details
  linked rather than duplicating release-specific download instructions.
- The app exposes User Guide / 使用指南 in its Help menu, menu-bar menu and
  About page. Each explicit action opens the existing official online guide in
  the default browser, selecting Chinese or English from the current app language.
  Identify the destination as online help in About; opening help never requests
  permissions, changes preferences, enables a module or starts an update check.
  There is no new settings page, embedded browser or bundled manual in this phase.
- README leads with the pain solved, actual features, screenshots, download and
  a brief install guide. English is the default `README.md`; Simplified Chinese
  lives in `README.zh-CN.md`, with reciprocal language links at the top. Developer
  instructions live in docs. Optional donations link the supplied ReceivePayment images.
- Repository description, Topics and bilingual introductory copy describe the
  implemented macOS Finder extension and its actual file/image tasks. Use natural
  search phrases and at most 20 relevant Topics. Website pages provide distinct
  titles/descriptions, absolute canonical and sharing URLs at the official Pages
  address, and reciprocal language links only for existing translations. Generate
  a sitemap with the production base path; exclude 404 pages and mark them noindex.
  Search metadata adds no tracking or build-time network requests.
- Both README languages and website homepages show a future roadmap as grouped
  TODO checklists. Describe concrete user outcomes without priorities, release
  assignments or delivery dates, and distinguish planned work from available
  features. Website checklists reuse the corresponding README content. Keep
  implementation guidance and completion criteria in docs/ROADMAP.md; checking
  off an item requires its implementation and verification to be complete.
- Non-commercial use is free for everyone, including personal, educational and
  research use. Commercial use, commercial redistribution and commercial
  derivatives require prior written authorization or a separately issued paid
  commercial license. Donations alone grant no commercial rights. Include the
  license in the app and DMG; do not label this as MIT or OSI open source.
- Keep the privacy policy.
  Do not promise valid Office/PDF/image output from a custom suffix.

## GitHub feedback

- The New issue chooser offers separate Simplified Chinese and English forms
  for Bug reports, feature requests and usage questions. Each form uses one
  language throughout and applies the existing `bug`, `enhancement` or `question`
  label respectively. Ordinary contributors use these forms instead of a blank
  issue; the chooser also links to Chinese and English help.
- Bug reports require a description, FileMint version, macOS version, Mac
  architecture, installation source, reproduction steps, expected result and
  actual result. Feature requests require a concrete scenario, proposed behavior
  and the outcome that would solve the need. Usage questions require a question
  and the user's intended task. Each form asks users to check existing Issues.
- Supporting screenshots, recordings, logs, configuration context and alternative
  solutions are optional. Explain where to find version information, allow an
  unknown value when it cannot be obtained, and remind users to remove private
  information from public attachments. Do not require users to upgrade, grant
  additional permissions or upload private files to submit feedback.

## Working context

- Implementation entry points: `Resources/`, `scripts/generate_app_icon.swift`, `website/`, `.github/ISSUE_TEMPLATE/`, `README.md`, `README.zh-CN.md`, `PRIVACY.md`, `LICENSE`; visible controls in `App/FileMint/` and `SharedUI/`.
- Verification: [Verification matrix](../HARNESS.md#choose-checks-by-change), using the documentation, website or appearance row.
- Expand context only when needed: For feature claims, load only the domain being described. Load [updates](updates.md) for About credits; [distribution](distribution.md) for installation/release claims. Read [future roadmap](../../docs/ROADMAP.md) only for planned work, never as evidence of shipped behavior.

## Settings information and shortcuts

- A distinct sidebar Quick Actions area has a split New File button: its main
  action opens the existing draft and its menu offers the two clipboard actions.
  Both parts have accessible labels and keyboard focus; the sidebar adds no
  duplicate Command-N binding. Existing app/menu-bar shortcuts and navigation
  selection remain unchanged.
  Keep the Finder extension status link below it and preserve minimum-size access.
- Remove the shared version/local-processing footer, retaining visible global
  errors. Version/build and full privacy links belong in About; local image
  processing copy belongs in Resource Tools and actual processing windows.
- About has a leading-aligned content column capped at 640 points, a horizontal
  icon/name/version identity group, compact credits and adjacent update actions
  that wrap when necessary. Preserve all credits/links and existing update states,
  progress, cancellation and restart protections.
- Available-update summaries use the existing About column: a clear localized
  heading, literal headline and readable wrapping bullets above update actions.
  When an update is available, put the update section immediately after the
  app identity and before credits, so its summary and actions are easy to find.
  With no offered update, retain the ordinary About ordering.
  The whole page remains scrollable at minimum size. The sidebar update entry
  remains one button with the version and a secondary headline, with a bounded
  visual preview and full accessibility text. Missing summaries retain the
  version-only sidebar entry. Preserve native keyboard access and light/dark
  appearance in both languages.
