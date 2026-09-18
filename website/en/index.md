---
layout: home
hero:
  name: FileMint
  text: A new file. Right here.
  tagline: Right-click in Finder and create a file exactly where you are working.
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
features:
  - icon: ⌘
    title: Native Finder entry point
    details: Create a familiar file type from the desktop or an authorized folder.
  - icon: ✦
    title: Name it before you create it
    details: Set the filename, suffix, location and starter content in one compact panel.
  - icon: ◌
    title: Private and offline
    details: No account, analytics or background scanning. Creating files needs no network.
  - icon: ↔
    title: Optional File & Folder Tools
    details: Copy names, paths or deliberately move selected items inside authorized folders.
---

<section id="finder" class="landing-section">
  <p class="section-kicker">01 / FINDER FIRST</p>
  <h2>A new file, right where you are already working.</h2>
  <p class="section-intro">No opening an editor, choosing Save As, then finding your folder again. FileMint puts the action back in Finder: right-click, choose a type, and the file is there.</p>
  <div class="visual-grid">
    <figure class="screen-card">
      <img src="/images/finder-desktop-context-menu-zh.png" alt="FileMint New File menu in a desktop context menu">
      <figcaption>Create directly from the desktop background.</figcaption>
    </figure>
    <figure class="screen-card">
      <img src="/images/finder-folder-context-menu-zh.png" alt="FileMint New File menu in a Finder folder context menu">
      <figcaption>In a working folder, the file stays exactly where you are.</figcaption>
    </figure>
  </div>
</section>

<section id="create" class="landing-section">
  <p class="section-kicker">02 / CREATE WITH CONTEXT</p>
  <h2>When you need more control, it is still one small panel.</h2>
  <p class="section-intro">Enter the full filename, choose a suffix, confirm the location and write the first lines if you need to. Markdown, code, notes and configuration do not need an empty-file detour.</p>
  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--panel">
      <img src="/images/create-panel-zh.png" alt="FileMint creation panel with filename, suffix, destination and starter content">
      <figcaption>The full filename and suffix stay in sync; content is read only when you explicitly type or paste it.</figcaption>
    </figure>
    <div class="copy-stack">
      <h3>More than a blank file</h3>
      <p>Put the content you need straight into the panel, then create. Multiline text, Unicode, whitespace and template tokens are saved exactly as entered.</p>
      <ul class="benefit-list">
        <li><strong>⌘↩</strong> creates from anywhere; <strong>Esc</strong> cancels</li>
        <li>The full filename wins; FileMint never silently rewrites the suffix</li>
        <li>Quick creation increments names; custom creation asks before replacement</li>
      </ul>
    </div>
  </div>
</section>

<section id="types" class="landing-section">
  <p class="section-kicker">03 / YOUR MENU, YOUR TYPES</p>
  <h2>Keep only the file types you actually use.</h2>
  <p class="section-intro">Common formats work immediately, with more available when you need them. Add your own text suffixes and starter templates, then arrange their Finder menu order.</p>
  <div class="copy-stack">
    <h3>Organize around your workflow</h3>
    <p>Text, Markdown, JSON, Swift, HTML, CSS and Shell are ready from the start. CSV, YAML, XML, JavaScript, TypeScript, Python and SQL are one toggle away.</p>
    <ul class="benefit-list">
      <li>Enable, disable and reorder without a menu full of clutter</li>
      <li>Keep custom text suffixes such as <strong>.toml</strong>, <strong>.vue</strong> and <strong>.log</strong></li>
      <li>Templates and the Finder menu stay in sync</li>
    </ul>
  </div>
</section>

<section id="settings" class="landing-section">
  <p class="section-kicker">04 / SETTINGS, WITH A PLACE FOR EVERYTHING</p>
  <h2>Clearer settings, without doing anything on your behalf.</h2>
  <p class="section-intro">FileMint now uses a persistent sidebar, so each preference has a clear home. Changing pages is navigation only; it never rewrites settings, and New File… stays at the bottom of the sidebar.</p>
  <div class="visual-grid visual-grid--wide">
    <div class="copy-stack">
      <h3>Basic Settings</h3>
      <ul class="benefit-list">
        <li><strong>General</strong>: language, launch at login, menu bar and automatic update checks</li>
        <li><strong>Creation</strong>: collision handling and revealing the completed file in Finder</li>
        <li><strong>Templates &amp; Types</strong>: common formats, custom suffixes and starter content</li>
        <li><strong>Finder &amp; Folders</strong>: extension status, menu scope and folder authorization</li>
      </ul>
    </div>
    <div class="copy-stack">
      <h3>Extensions and About</h3>
      <ul class="benefit-list">
        <li><strong>Extensions</strong>: opt into File &amp; Folder Tools without affecting New File</li>
        <li><strong>About</strong>: version, license, privacy, manual update checks and Update and Restart</li>
        <li>Arrow-key navigation and native readability across Chinese, English, light and dark appearances</li>
      </ul>
    </div>
  </div>
</section>

<section id="file-tools" class="landing-section">
  <p class="section-kicker">05 / FILE &amp; FOLDER TOOLS</p>
  <h2>Handle selected items only when you explicitly ask.</h2>
  <p class="section-intro">Select local files or folders inside an authorized scope, then enable File &amp; Folder Tools to see a root menu beside New File. It is off by default, so existing creation menus stay exactly as they are.</p>
  <div class="visual-grid visual-grid--wide">
    <div class="copy-stack">
      <h3>Copy without surveillance</h3>
      <ul class="benefit-list">
        <li><strong>Copy Names</strong>: preserves suffixes, with one line per selected item</li>
        <li><strong>Copy Paths</strong>: writes complete local filesystem paths</li>
        <li>No file-content reads, folder crawling or clipboard monitoring; the clipboard changes only when you choose a Copy action</li>
      </ul>
    </div>
    <div class="copy-stack">
      <h3>Move in two deliberate steps</h3>
      <ul class="benefit-list">
        <li>Choose <strong>Move File / Folder</strong> on source items; nothing moves yet</li>
        <li>Right-click the target folder background and choose <strong>Move Selected Items Here</strong></li>
        <li>Existing names never overwrite or merge; pending items remain until they complete or a new source selection replaces them</li>
      </ul>
    </div>
  </div>
</section>

<section id="roadmap" class="landing-section">
  <p class="section-kicker">06 / TODO</p>
  <h2>More useful, one small step at a time.</h2>
  <p class="section-intro">These plans grow out of everyday file creation. Unchecked items are still future work, and the list will evolve with use and feedback.</p>

<div class="roadmap-todos">

<!--@include: ../../README.en.md#roadmap-->

</div>

  <p class="roadmap-links">Read the <a href="https://github.com/FileMintApp/FileMint/blob/main/docs/ROADMAP.md">implementation roadmap (Chinese)</a> or <a href="https://github.com/FileMintApp/FileMint/issues">share your use case on GitHub</a>. Templates, translations and reproduction steps are welcome too.</p>
</section>

<section id="download" class="landing-section">
  <div class="callout-band">
    <div>
      <h2>Small, native and focused on one useful thing.</h2>
      <p>For macOS 13+, with one universal build for Apple silicon and Intel Macs. File creation works offline, with no account, subscription, telemetry or background folder scanning.</p>
    </div>
    <div class="callout-actions">
      <a href="https://github.com/FileMintApp/FileMint/releases/latest">Download the latest release</a>
      <a href="./install.html">Read installation help</a>
    </div>
  </div>
</section>
