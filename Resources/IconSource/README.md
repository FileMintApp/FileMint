# Folded F identity

The icon combines FileMint's F with the folded corner of a fresh sheet of paper.
A porcelain tile and mint material form the Dock/app icon; a separately fitted
monochrome F serves the menu bar and Finder toolbar at 18 points.

`FileMint-Concept.png` is the built-in ImageGen concept reference. The production
icons are independently constructed from vector geometry in
`scripts/generate_app_icon.swift`, so the alpha boundary and small glyphs stay
precise. `make icon` rebuilds all PNGs from that native master.

The concept prompt and production decisions are in `BRIEF.md`.
The top-level Finder entry uses a small mint F plus a localized function label.
Submenu rows and creation controls remain text only.
