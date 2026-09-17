# Appearance, website and product copy

Load for: Native appearance, icons, README/website copy, roadmap presentation and license/privacy claims.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## Appearance

- Native controls and adaptive system colors. Settings use a persistent leading
  sidebar and a resizable detail area, with General, Creation, Templates & Types,
  Finder & Folders, and About. Each page has a title, concise explanation and
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
  Hover and keyboard focus remain distinct from the selected page; arrow keys
  move between page buttons and the current page is exposed to accessibility.
- Only the top-level Finder entry has the small FileMint logo; its label maps
  to the resolved app language. Format choices, submenu rows and creation
  controls use text only. The Finder
  toolbar and macOS menu bar retain the small template glyph those entry points
  require. No icon preference.
- App logo: a distinctive folded-paper F in fresh mint on a warm porcelain
  macOS tile. Dock/application assets use the image master; menu bar and Finder
  toolbar use a separately drawn crisp monochrome F silhouette. No medical-style
  plus badge. `make icon` regenerates the asset catalog from the masters.
  The generated Xcode project is never edited directly.

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
