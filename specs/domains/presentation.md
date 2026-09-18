# Appearance, website and product copy

Load for: Native appearance, icons, README/website copy, roadmap presentation and license/privacy claims.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## Appearance

- Approved UI/UX v1 uses three explicit sidebar groups: File Creation (Templates
  & Types, Creation), Extensions (File & Folder Tools, Resource Tools), and
  Preferences (General, Finder & Folders, About). Arrow-key navigation follows
  that visual order. Future implemented tools join Extensions without placeholders.
- Use restrained adaptive porcelain/graphite surfaces and a muted mint accent,
  shared row/section/button spacing, a quiet breadcrumb and a fixed New File action.
  Status reflects real extension/login/update state; no sample metrics or claimed
  permissions from the design prototype may reach the product.
- Resource Tools separates Use Tools from Finder Menu Settings. The first shows
  six usable actions; the second manages the default-off Finder integration.
  Native processing windows use a bounded image preview, parameter inspector,
  thumbnail selection and fixed bottom actions. OCR puts source and editable
  result side-by-side; conversion never displays a fabricated compressed size.
  The creation panel uses a filename-first form, destination and content with
  persistent labels, familiar keyboard shortcuts and adaptive native fields.
- No looping animation, eager model loading, remote assets or extra UI library.
  Use a single sidebar material at most, with native reduce-transparency behavior;
  the remaining surfaces are inexpensive adaptive colors.

- Native controls and adaptive system colors. Settings switches use the native
  small control size, preserving readable labels and keyboard/accessibility support. Settings use a persistent leading
  sidebar and a resizable detail area, with General, Creation, Templates & Types,
  Finder & Folders, File & Folder Tools and Resource Tools under Extensions, and About, grouped as above. Each page has a title, concise explanation and
  functional sections; list actions stay next to their list. No decorative cards
  or disabled placeholders for future roadmap features. Follow system language
  by default; English and Chinese can be selected explicitly.
- General owns language, startup/menu bar and automatic-check preferences.
  Creation owns quick-creation collisions and reveal-after-creation. Templates &
  Types owns the existing enabled/order/custom-type management. Finder & Folders
  owns extension status, folder scope/access and optional Full Disk Access guidance.
  About retains its credits and update actions. New File remains reachable from
  every page. Settings navigation itself never writes preferences or creates files.
- Use a 900 × 650 initial content size and an 840 × 600 minimum, with scrolling
  for long content. Sidebar labels, focus/selection and controls remain readable
  in English/Chinese and system light/dark appearances. Native keyboard and
  accessibility labels must remain available; icons supplement text, not replace it.
- Sidebar navigation uses a continuous background and a subdued mint selection
  with a stronger label/icon, rather than the system List's bright selection fill.
  The selected row has a lightly visible mint surface in addition to its fine
  outline, so the active page remains clear without becoming a solid highlight.
  Hover and keyboard focus remain distinct from the selected page; arrow keys
  move between page buttons and the current page is exposed to accessibility.
- File & Folder Tools retains its module and Menu actions headings, using native
  small switches and softly bordered grouped rows for the tools.
  Align menu-position pickers on the trailing side; keep descriptions and secondary
  options next to their tool. Use compact spacing, adaptive surfaces and mint
  accents. Menu-position picker values use the adaptive system control text color,
  reserving mint for enabled accents and selected controls. When the module is off
  the entire child area stays visible, grayscale
  and noninteractive. An individual disabled tool retains its available checkbox,
  with a muted icon and disabled secondary controls. Preserve readable contrast,
  wrapping, scrolling and native keyboard/accessibility behavior at minimum size.
- The top-level New File Finder entry has the small FileMint logo; its label
  maps to the resolved app language. File & Folder Tools uses the system
  `wrench.and.screwdriver` symbol in mint/blue; the temporary Move Selected
  Items Here entry uses `arrow.right.square` in mint/teal. Both are 16 × 16
  palette-colored images that keep their theme colors in the native menu and
  remain readable with menu selection. Each file-tool action has a matching
  colored SF Symbol in settings and Finder, at both main-menu and submenu levels:
  names use blue `doc.on.doc`, paths indigo `link`, move teal `folder`, permanent
  deletion orange `trash`, AirDrop purple `airplayaudio`, and desktop aliases blue
  `arrowshape.turn.up.right`. The temporary move
  destination retains its mint/teal icon in either location. Use 16 × 16 non-template
  menu images; color supplements recognizable shapes and text. New-file format
  choices and creation controls remain text only. The Finder
  toolbar and macOS menu bar retain the small template glyph those entry points
  require. No icon preference.
- App logo: a distinctive folded-paper F in fresh mint on a warm porcelain
  macOS tile. Dock/application assets use the image master; menu bar and Finder
  toolbar use a separately drawn crisp monochrome F silhouette. No medical-style
  plus badge. `make icon` regenerates the asset catalog from the masters.
  The generated Xcode project is never edited directly.
- Optional modules show enabled, applicable entries at their configured main-menu
  or submenu level; empty submenu roots are hidden. Chinese copy uses 拷贝 for Copy; the file-tools root is 文件（夹）工具.

## Product presentation

- README leads with the pain solved, actual features, screenshots, download and
  a brief install guide. Chinese first, English separate. Developer instructions
  live in docs. Optional donations link the supplied ReceivePayment images.
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

## Working context

- Implementation entry points: `Resources/`, `scripts/generate_app_icon.swift`, `website/`, `README.md`, `README.en.md`, `PRIVACY.md`, `LICENSE`; visible controls in `App/FileMint/` and `SharedUI/`.
- Verification: [Verification matrix](../HARNESS.md#choose-checks-by-change), using the website or appearance row.
- Expand context only when needed: For feature claims, load only the domain being described. Load [updates](updates.md) for About credits; [distribution](distribution.md) for installation/release claims. Read [future roadmap](../../docs/ROADMAP.md) only for planned work, never as evidence of shipped behavior.
