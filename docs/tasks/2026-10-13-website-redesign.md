# Task: Workflow-led website and live release metadata

Status: in-progress
Next action: Commit, push and deploy the approved website update.

## Objective and scope

- Redesign the existing VitePress website around real file workflows and make
  current-version labels follow GitHub's latest public stable Release.
- Keep GitHub Pages, the existing publication gates and the product unchanged.
  No new dependencies or application release. The user subsequently authorized
  committing, pushing and deploying the website.
- Preserve bilingual guides, privacy, historical installation exceptions and
  the README-backed planned-feature lists.

## Selected context

- [Presentation](../../specs/domains/presentation.md),
  [distribution](../../specs/domains/distribution.md); existing feature contracts
  for creation/templates, images, favorites and Open with App.
- Entry points: `website/`, VitePress theme and config.
- [Website verification](../../specs/HARNESS.md): base-path build, local browser
  inspection in both languages and mobile/dark appearances, release-data tests.

## Decisions and progress

- Runtime public API request, no build-time version snapshot. Offline, invalid
  data and rate limits retain the latest-release download link without a number.
- Real repository screenshots and matching-language captions; no generated UI.
- Added an explicit website-only deployment path, bound to current main and a
  successful push build/artifact. Its guard rejects unpublished application-code
  differences; existing release-bound deployment remains unchanged.

## Evidence

Tested primary checkout on 2026-10-13, with uncommitted website changes.

| Check | Status | Observed result |
| --- | --- | --- |
| `SITE_BASE=/FileMint/ pnpm run site:build` | passed | Includes 17 release-data/deployment-policy tests, then client/server bundles and all static pages. No release network request during build. |
| `make verify-context` | passed | 22 context documents, 122 local links. |
| `git diff --check` | passed | No whitespace errors. |
| Built-page link audit | passed | 199 local links/images across 9 pages; all fragments resolve. Home HTML contains no baked-in current release version. |
| Browser desktop/mobile | passed | Chinese/English, 1440px desktop and 390px mobile, light/dark; no horizontal overflow in inspected views or console errors. |
| Browser interactions | passed | Scene switching, arrow-key selection, screenshot dialog open/close, FAQ, roadmap and English guide search. |
| Live release metadata | passed | Public GitHub request displayed v0.7.0 at observation time; one request served both homepage badges. |
| Browser release fixtures | passed | A simulated 403 retained neutral labels and latest-release links; a simulated future stable tag changed both labels without a rebuild. Test tab closed. |
| Screenshot capture | passed | New Chinese creation-panel capture from the installed app using only a temporary demo folder and sample text; draft cancelled without creating a document. |
| Public deployment | pending | User authorized publication; adding a distinct website-only dispatch while preserving existing application-release gates. |

Preview screenshot: `build/website-preview/home-desktop.jpg` (ignored local output).
The live preview uses the existing VitePress dev server on loopback port 5173.
Current-version metadata requires GitHub availability; failure intentionally omits
the number. Historical compatibility and updater exceptions remain in install docs.

## Handoff

- No app/Finder behavior changes or application release; website deployment is authorized.
