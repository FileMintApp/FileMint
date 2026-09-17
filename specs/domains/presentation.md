# Appearance, website and product copy

Load for: Native appearance, icons, README/website copy, roadmap presentation and license/privacy claims.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## Appearance

- Native controls and system colors. Compact settings with General, File Types,
  Folders and About. No decorative cards. Follow system language by default; English
  and Chinese can be selected explicitly.
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
