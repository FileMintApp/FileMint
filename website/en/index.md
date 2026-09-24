---
layout: home
hero:
  name: FileMint
  text: Put file tools back in Finder.
  tagline: Create files, reuse document templates, open your go-to apps and handle images right from Finder. Native to macOS. Processed locally.
  image:
    src: /filemint-icon.png
    alt: FileMint
  actions:
    - theme: brand
      text: Download for macOS
      link: https://github.com/FileMintApp/FileMint/releases/latest
    - theme: alt
      text: View on GitHub
      link: https://github.com/FileMintApp/FileMint
---

<p class="guide-entry">New to FileMint? Follow the <a href="./guide.html">user guide</a> to create your first file.</p>

<div class="hero-proof" aria-label="FileMint product facts">
  <span><strong>Swift + AppKit</strong> native app</span>
  <span><strong>Small footprint</strong> no web runtime</span>
  <span><strong>6</strong> image tools in the stable release</span>
  <span>Local processing, no remote detour</span>
</div>

<nav class="feature-nav" aria-label="Explore features">
  <a href="#finder">Finder</a>
  <a href="#create">Create</a>
  <a href="#templates">Templates &amp; paste</a>
  <a href="#open-with">Open with App</a>
  <a href="#resources">Image tools</a>
  <a href="#qa-preview">QA preview</a>
  <a href="#file-tools">File tools</a>
</nav>

<div class="architecture-strip">
  <article>
    <span class="mini-label">NATIVE MAC APP</span>
    <h3>Native menus, windows and editing</h3>
    <p>Swift, AppKit and SwiftUI connect directly to Finder and macOS permissions, sharing and window behavior.</p>
  </article>
  <article>
    <span class="mini-label">SMALL FOOTPRINT</span>
    <h3>Small by design, no web runtime</h3>
    <p>No embedded web app, account or background crawl. Open it, do the work and get back to your task.</p>
  </article>
  <article>
    <span class="mini-label">LOCAL PERFORMANCE</span>
    <h3>File work stays on your Mac</h3>
    <p>Creation, image processing and OCR do not go through a remote service; Finder acts only when you ask.</p>
  </article>
</div>

<section id="finder" class="landing-section landing-section--quiet">
  <p class="section-kicker">01 / FINDER FIRST</p>
  <h2>Start wherever you are in Finder.</h2>
  <p class="section-intro">No editor detour, no Save As hunt and no guessing the destination. FileMint puts the action back in the place where you are already working.</p>

  <div class="feature-grid feature-grid--three">
    <article class="feature-card">
      <span class="feature-index">01</span>
      <h3>Current location</h3>
      <p>The desktop background and authorized Finder folders are both first-class entry points.</p>
    </article>
    <article class="feature-card">
      <span class="feature-index">02</span>
      <h3>Useful types</h3>
      <p>Enable and reorder 14 built-in text and code formats, or add your own templates.</p>
    </article>
    <article class="feature-card">
      <span class="feature-index">03</span>
      <h3>Clear boundaries</h3>
      <p>Finder enablement and folder authorization stay separate. Nothing expands its scope silently.</p>
    </article>
  </div>

</section>

<section id="create" class="landing-section">
  <p class="section-kicker">02 / CREATE WITH CONTEXT</p>
  <h2>When you need control, it is still one small panel.</h2>
  <p class="section-intro">Set the full filename, suffix, destination and starter content in one place. Begin with a real Markdown draft instead of creating an empty file first.</p>

  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--panel">
      <div class="screen-window screen-window--creation"><img width="1120" height="1226" loading="lazy" decoding="async" src="/images/create-panel-en.jpg" alt="FileMint New File panel with project-kickoff.md and starter content"></div>
      <figcaption>Interface example · A Markdown draft, with a synchronized suffix and literal starter content.</figcaption>
    </figure>
    <div class="copy-stack">
      <div class="mini-label">CREATE ONCE, KEEP THE CONTEXT</div>
      <h3>More than an empty file</h3>
      <p>Enter <strong>project-kickoff.md</strong>, paste the first lines and create it. Naming, location and content stay in one path.</p>
      <ul class="benefit-list">
        <li><strong>⌘↩</strong> creates; <strong>Esc</strong> cancels</li>
        <li>Custom suffixes remain UTF-8 text instead of pretending to be another document format</li>
        <li>Quick creation numbers names by default, with an option to fail; text drafts ask before replacing</li>
      </ul>
    </div>
  </div>
</section>

<section id="templates" class="landing-section landing-section--quiet">
  <p class="section-kicker">03 / START FROM A TEMPLATE</p>
  <h2>A familiar starting point, every time.</h2>
  <p class="section-intro">Keep different templates for the same format. Meeting notes, project briefs and worksheets each retain their own name and content, ready in Finder or the creation panel.</p>
  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--panel">
      <div class="screen-window"><img width="1800" height="1300" loading="lazy" decoding="async" src="/images/file-types-en.jpg" alt="FileMint Templates and Types with New Text Template and Import Document Template actions"></div>
      <figcaption>Enable the formats you need, save multiple templates per format and choose a default.</figcaption>
    </figure>
    <div class="copy-stack">
      <div class="mini-label">TEXT / WORD / EXCEL</div>
      <h3>From blank files to your own documents</h3>
      <ul class="benefit-list">
        <li><strong>Text templates</strong>: save a filename and starter content, with filename, date and year variables</li>
        <li><strong>Word / Excel</strong>: import .docx or .xlsx and create independent copies with formatting and content intact</li>
        <li><strong>Stored locally</strong>: imported templates no longer depend on the original document's location or change its contents</li>
      </ul>
    </div>
  </div>
  <div class="feature-grid feature-grid--three">
    <article class="feature-card"><span class="feature-index">COPY</span><h3>Paste Image as File</h3><p>Copy a screenshot or image, then choose Paste Image as File in the app or Finder's New File menu.</p></article>
    <article class="feature-card"><span class="feature-index">PREVIEW</span><h3>Preview and name it</h3><p>See the image, enter a filename and choose its destination. The clipboard is read only when you ask.</p></article>
    <article class="feature-card"><span class="feature-index">PNG</span><h3>Save as PNG</h3><p>Keep transparency and number existing names automatically. Nothing is written until you click Create.</p></article>
  </div>
</section>

<section id="open-with" class="landing-section">
  <p class="section-kicker">04 / OPEN WITH YOUR APPS</p>
  <h2>Your files. Your go-to apps.</h2>
  <p class="section-intro">Add your editor, terminal or other applications to Finder's context menu. Pass files, folders or a mixed selection together; the chosen app decides which types it supports.</p>
  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--panel">
      <div class="screen-window"><img width="1800" height="1300" loading="lazy" decoding="async" src="/images/open-with-en.jpg" alt="FileMint Open with App settings with three configured applications and menu positions"></div>
      <figcaption>Example configuration · New installations start with an empty app list.</figcaption>
    </figure>
    <div class="copy-stack">
      <div class="mini-label">YOUR APPS / YOUR MENU</div>
      <h3>Keep frequent actions close</h3>
      <ul class="benefit-list">
        <li>Give each app a main-menu entry or a place in the Open with App submenu</li>
        <li>Keep your system's default file associations unchanged</li>
        <li>Add, remove and choose menu positions from one settings page</li>
      </ul>
    </div>
  </div>
</section>

<section id="resources" class="landing-section landing-section--tint">
  <p class="section-kicker">05 / RESOURCE TOOLS</p>
  <h2>Image work, next to the selected files.</h2>
  <p class="section-intro">Select images, choose Resource Tools from Finder, or start from the FileMint app. The six tools in the stable release work locally, even with Finder menu integration off. Preview first, then choose parameters and output.</p>

  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--panel">
      <div class="screen-window"><img width="1800" height="1300" loading="lazy" decoding="async" src="/images/resource-tools-en.jpg" alt="FileMint Resource Tools page with six image actions"></div>
      <figcaption>Stable release interface example · Six local image tools. Originals stay intact; results are saved separately.</figcaption>
    </figure>
    <div class="copy-stack">
      <div class="mini-label">SIX SMALL TOOLS, ONE NATIVE SURFACE</div>
      <h3>Keep repetitive image work together</h3>
      <ul class="benefit-list">
        <li><strong>Convert Image</strong>: JPEG, PNG, HEIC and TIFF</li>
        <li><strong>Compress and Resize</strong>: preserve proportions without enlarging originals</li>
        <li><strong>Generate Icons</strong>: ICNS, ICO and PNG size sets</li>
        <li><strong>Stitch and Extract Text</strong>: reorder, preview and edit OCR output</li>
      </ul>
    </div>
  </div>

</section>

<section id="qa-preview" class="landing-section landing-section--quiet qa-preview-section">
  <p class="section-kicker">06 / QA FEATURE PREVIEW</p>
  <h2>Meet the next Finder tools in QA first.</h2>
  <p class="section-intro">These three features are in an unpublished QA build and are not in the current stable installer. The images below are consistent placeholders; we will replace them after the QA app icon and capture assets are updated. Download still points to the latest stable release.</p>

  <div class="qa-preview-grid">
    <article class="qa-preview-card">
      <img src="/images/feature-preview-placeholder-en.svg" width="1200" height="860" loading="lazy" decoding="async" alt="Placeholder for the QA screenshot of Finder hidden item switching">
      <div class="qa-preview-copy">
        <span class="qa-preview-label">QA preview · Unreleased</span>
        <h3>User-triggered Finder display toggle</h3>
        <p>Finder &amp; Folders adds a deliberate toggle command. First use requires the macOS Accessibility permission. FileMint does not guess or store Finder's current hidden-item state. Stable-release support will follow installed-app acceptance and release notes.</p>
      </div>
    </article>
    <article class="qa-preview-card">
      <img src="/images/feature-preview-placeholder-en.svg" width="1200" height="860" loading="lazy" decoding="async" alt="Placeholder for the QA screenshot of Favorite Locations">
      <div class="qa-preview-copy">
        <span class="qa-preview-label">QA preview · Unreleased</span>
        <h3>Favorite Locations</h3>
        <p>Save files and folders you choose, search saved names, paths or groups, and pin frequently used items. Finder shows a bounded list of pinned and recently located entries. Locating a file selects it in Finder; opening it is a separate action.</p>
      </div>
    </article>
    <article class="qa-preview-card">
      <img src="/images/feature-preview-placeholder-en.svg" width="1200" height="860" loading="lazy" decoding="async" alt="Placeholder for the QA screenshot of private image metadata removal">
      <div class="qa-preview-copy">
        <span class="qa-preview-label">QA preview · Unreleased</span>
        <h3>Remove private image metadata</h3>
        <p>Remove GPS, capture time, device identifiers, IPTC, XMP and other metadata in a locally processed copy, then verify it by reading the output back. The original stays unchanged. Target formats are JPEG, PNG, TIFF and ordinary single-image HEIC when supported by the system. Re-encoding may change size or color. Filenames and information visible in the pixels still need your review.</p>
      </div>
    </article>
  </div>
</section>

<section id="file-tools" class="landing-section">
  <p class="section-kicker">07 / FILE &amp; FOLDER TOOLS</p>
  <h2>Handle selected items only when you explicitly ask.</h2>
  <p class="section-intro">File &amp; Folder Tools starts off. Once enabled, each action can live in Finder's main menu or the tools submenu; New File remains independent and uncluttered.</p>

  <div class="visual-grid visual-grid--wide">
    <div class="copy-stack">
      <div class="mini-label">OPT IN / CHOOSE THE MENU LEVEL</div>
      <h3>Shape the context menu around your work</h3>
      <ul class="benefit-list">
        <li><strong>Copy Names / Paths</strong>: one line per selected item, written only when chosen</li>
        <li><strong>Two-step Move</strong>: capture sources first, confirm at the destination folder</li>
        <li><strong>Delete Permanently</strong>: confirmation by default, no following symlink targets</li>
        <li><strong>AirDrop / Send Alias to Desktop</strong>: use macOS sharing and native Finder aliases</li>
      </ul>
    </div>
    <figure class="screen-card screen-card--panel">
      <div class="screen-window"><img width="1800" height="1300" loading="lazy" decoding="async" src="/images/file-tools-en.jpg" alt="FileMint File and Folder Tools settings with menu placement and individual switches"></div>
      <figcaption>Example configuration · Each action has its own switch and menu position.</figcaption>
    </figure>
  </div>
</section>

<section id="settings" class="landing-section landing-section--quiet">
  <p class="section-kicker">08 / A QUIETER NATIVE UI</p>
  <h2>Clear hierarchy, less searching.</h2>
  <p class="section-intro">Three sidebar groups keep creation, extensions and preferences together. Choose Follow System, Light or Dark, and use English, Chinese or your system language.</p>

  <div class="feature-grid feature-grid--three">
    <article class="feature-card">
      <span class="feature-index">01</span>
      <h3>Grouped by job</h3>
      <p>Creation, extensions and preferences do not collapse into one long settings page.</p>
    </article>
    <article class="feature-card">
      <span class="feature-index">02</span>
      <h3>Opt in by design</h3>
      <p>Resource Tools and File &amp; Folder Tools can be turned off without changing existing creation settings.</p>
    </article>
    <article class="feature-card">
      <span class="feature-index">03</span>
      <h3>Native readability</h3>
      <p>Theme changes apply immediately to FileMint settings, creation and image windows without changing macOS appearance.</p>
    </article>
  </div>
  <figure class="screen-card screen-card--settings">
    <div class="screen-window"><img width="1800" height="1300" loading="lazy" decoding="async" src="/images/settings-en.jpg" alt="FileMint General settings with theme, language and startup options"></div>
    <figcaption>Interface example · Independent theme and language choices, ready to change at any time.</figcaption>
  </figure>
</section>

<section id="privacy" class="landing-section landing-section--tint">
  <p class="section-kicker">09 / LOCAL BY DEFAULT</p>
  <h2>Quiet does not mean opaque.</h2>
  <p class="section-intro">FileMint keeps permission, network and file-processing boundaries explicit, so you know when it works and when it does not.</p>

  <div class="trust-grid">
    <article class="trust-card">
      <span class="trust-symbol">⌁</span>
      <h3>Local creation and processing</h3>
      <p>File creation, conversion, compression, resizing, stitching and OCR run on your Mac.</p>
    </article>
    <article class="trust-card">
      <span class="trust-symbol">∅</span>
      <h3>No account or telemetry</h3>
      <p>No sign-in, usage analytics, background file enumeration or file-content reads.</p>
    </article>
    <article class="trust-card">
      <span class="trust-symbol">↗</span>
      <h3>A clear network boundary</h3>
      <p>The app can check for updates at most once every 7 days, or when you ask. Downloads and installation are your choice. Finder stays offline.</p>
    </article>
  </div>
</section>

<section id="roadmap" class="landing-section">
  <p class="section-kicker">10 / TODO</p>
  <h2>Keep making the small things better.</h2>
  <p class="section-intro">These features are still planned. Follow the project for progress as they take shape.</p>

  <div class="roadmap-todos">

<!--@include: ../../README.en.md#roadmap-->

  </div>

  <p class="roadmap-links">Read the <a href="https://github.com/FileMintApp/FileMint/blob/main/docs/ROADMAP.md">implementation roadmap</a> or <a href="https://github.com/FileMintApp/FileMint/issues">share a use case on GitHub</a>.</p>
</section>

<section id="download" class="landing-section landing-section--last">
  <div class="callout-band">
    <div>
      <div class="mini-label">LATEST STABLE RELEASE</div>
      <h2>Start in Finder. Finish the task. Get back to work.</h2>
      <p>The download always points to the latest stable release. See the installation guide for system requirements and first-time Finder setup. Features labelled QA preview above are not in the current stable installer.</p>
    </div>
    <div class="callout-actions">
      <a href="https://github.com/FileMintApp/FileMint/releases/latest">Download the latest release</a>
      <a href="./install.html">Read installation help</a>
      <a href="./guide.html">Read the user guide</a>
    </div>
  </div>
</section>
