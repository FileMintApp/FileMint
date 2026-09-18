---
layout: home
hero:
  name: FileMint
  text: Put file tools back in Finder.
  tagline: A small native macOS app for creating, processing and organizing files and images from Finder.
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

<div class="hero-proof" aria-label="FileMint product facts">
  <span><strong>Swift + AppKit</strong> native app</span>
  <span><strong>Small footprint</strong> no web runtime</span>
  <span><strong>6</strong> image tools</span>
  <span>Local processing, no remote detour</span>
</div>

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
      <p>Text, Markdown, JSON, Swift, HTML, CSS and Shell are ready when you need them.</p>
    </article>
    <article class="feature-card">
      <span class="feature-index">03</span>
      <h3>Clear boundaries</h3>
      <p>Finder enablement and folder authorization stay separate. Nothing expands its scope silently.</p>
    </article>
  </div>

  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--menu">
      <img src="/images/finder-resource-menu-zh.png" alt="Current FileMint Finder context menu with New File, File and Folder Tools, and Resource Tools">
      <figcaption>Current install example: select longmao.navigator.png and keep the three entry layers distinct.</figcaption>
    </figure>
    <div class="copy-stack">
      <div class="mini-label">ONE CONTEXT MENU, CLEAR LAYERS</div>
      <h3>Create and handle, each in its place</h3>
      <p>New File creates. File &amp; Folder Tools acts on selected items. Resource Tools handles images. Optional modules start off, and enabling them does not turn the menu into one long list.</p>
      <ul class="benefit-list">
        <li>Color icons make the three entry groups easy to scan</li>
        <li>File and Resource Tools appear only for applicable selections</li>
        <li>Each action can live in Finder's main menu or its own submenu</li>
      </ul>
    </div>
  </div>
</section>

<section id="create" class="landing-section">
  <p class="section-kicker">02 / CREATE WITH CONTEXT</p>
  <h2>When you need control, it is still one small panel.</h2>
  <p class="section-intro">Set the full filename, suffix, destination and starter content in one place. Begin with a real Markdown draft instead of creating an empty file first.</p>

  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--panel">
      <img src="/images/create-panel-en.png" alt="FileMint New File panel with project-kickoff.md and starter content">
      <figcaption>The full filename and suffix stay in sync; multiline text and Unicode stay literal.</figcaption>
    </figure>
    <div class="copy-stack">
      <div class="mini-label">CREATE ONCE, KEEP THE CONTEXT</div>
      <h3>More than an empty file</h3>
      <p>Enter <strong>project-kickoff.md</strong>, paste the first lines and create it. Naming, location and content stay in one path.</p>
      <ul class="benefit-list">
        <li><strong>⌘↩</strong> creates; <strong>Esc</strong> cancels</li>
        <li>Custom suffixes remain UTF-8 text instead of pretending to be another document format</li>
        <li>Quick creation increments names; custom creation asks before replacement</li>
      </ul>
    </div>
  </div>
</section>

<section id="resources" class="landing-section landing-section--tint">
  <p class="section-kicker">03 / RESOURCE TOOLS</p>
  <h2>Image work, next to the selected files.</h2>
  <p class="section-intro">Select images, choose Resource Tools from Finder, or start from the FileMint app. Six tools share one local panel for preview, parameters and output.</p>

  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--panel">
      <img src="/images/resource-tools-en.png" alt="FileMint Resource Tools page with six image actions">
      <figcaption>Convert, compress, resize, generate icons, stitch and extract text.</figcaption>
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

  <div class="visual-grid visual-grid--wide visual-grid--reverse">
    <div class="copy-stack">
      <div class="mini-label">LOCAL PREVIEW / ORIGINALS STAY UNCHANGED</div>
      <h3>Start with one real image</h3>
      <p>The panel below uses <strong>longmao.navigator.png</strong>. Output format, destination and original preservation are visible before you run anything; the image never leaves your Mac.</p>
      <div class="quote-card">
        <span class="quote-mark">“</span>
        <p>Preview first. Process when ready. Originals stay unchanged.</p>
      </div>
    </div>
    <figure class="screen-card screen-card--panel">
      <img src="/images/resource-panel-longmao-en.png" alt="FileMint Convert Image panel using longmao.navigator.png">
      <figcaption>Real resource example: longmao.navigator.png.</figcaption>
    </figure>
  </div>
</section>

<section id="file-tools" class="landing-section">
  <p class="section-kicker">04 / FILE &amp; FOLDER TOOLS</p>
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
      <img src="/images/file-tools-en.png" alt="FileMint File and Folder Tools settings with menu placement and individual switches">
      <figcaption>Independent switches and menu placement; destructive actions start off.</figcaption>
    </figure>
  </div>
</section>

<section id="settings" class="landing-section landing-section--quiet">
  <p class="section-kicker">05 / A QUIETER NATIVE UI</p>
  <h2>Clear hierarchy, less searching.</h2>
  <p class="section-intro">The current version uses a persistent sidebar for creation, extensions and preferences. Templates &amp; Types, Creation, File &amp; Folder Tools, Resource Tools, Finder &amp; Folders and About each have a clear home.</p>

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
      <p>Chinese, English, light and dark appearances share the same native window and controls.</p>
    </article>
  </div>
</section>

<section id="privacy" class="landing-section landing-section--tint">
  <p class="section-kicker">06 / LOCAL BY DEFAULT</p>
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
      <p>The main app reaches GitHub only when you check for or download an update. The Finder extension stays offline.</p>
    </article>
  </div>
</section>

<section id="roadmap" class="landing-section">
  <p class="section-kicker">07 / TODO</p>
  <h2>Keep making the small things better.</h2>
  <p class="section-intro">Only unfinished directions belong here. Delivered capabilities do not get repackaged as roadmap promises.</p>

  <div class="roadmap-todos">

<!--@include: ../../README.en.md#roadmap-->

  </div>

  <p class="roadmap-links">Read the <a href="https://github.com/FileMintApp/FileMint/blob/main/docs/ROADMAP.md">implementation roadmap</a> or <a href="https://github.com/FileMintApp/FileMint/issues">share a use case on GitHub</a>.</p>
</section>

<section id="download" class="landing-section landing-section--last">
  <div class="callout-band">
    <div>
      <div class="mini-label">FILEMINT 0.5.7</div>
      <h2>Start in Finder. Finish the task. Get back to work.</h2>
      <p>For macOS 13+, Apple silicon and Intel. Developer ID signed and Apple notarized; first use still follows macOS prompts for Finder enablement and folder authorization.</p>
    </div>
    <div class="callout-actions">
      <a href="https://github.com/FileMintApp/FileMint/releases/latest">Download the latest release</a>
      <a href="./install.html">Read installation help</a>
    </div>
  </div>
</section>
