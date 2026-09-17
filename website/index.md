---
layout: home
hero:
  name: FileMint
  text: 新文件，就在此刻。
  tagline: 在 Finder 右键，立即创建一份恰好在你当前位置的文件。
  image:
    src: /filemint-icon.png
    alt: FileMint
  actions:
    - theme: brand
      text: 下载 macOS 版
      link: https://github.com/FileMintApp/FileMint/releases/latest
    - theme: alt
      text: 在 GitHub 查看
      link: https://github.com/FileMintApp/FileMint
features:
  - icon: ⌘
    title: Finder 原生入口
    details: 桌面或已授权文件夹右键，直接创建常用类型。
  - icon: ✦
    title: 命名后再创建
    details: 文件名、后缀、位置和初始内容在一个紧凑面板里完成。
  - icon: ◌
    title: 私密且离线
    details: 不要账号、没有分析或后台扫描；文件创建不依赖网络。
---

<section id="finder" class="landing-section">
  <p class="section-kicker">01 / FINDER FIRST</p>
  <h2>文件，就在你已经在工作的地方。</h2>
  <p class="section-intro">不必先打开编辑器，再“另存为”，最后回到刚才的目录。FileMint 把新建文件放回 Finder：右键、选类型，文件就在那里。</p>
  <div class="visual-grid">
    <figure class="screen-card">
      <img src="/images/finder-desktop-context-menu-zh.png" alt="在桌面右键打开 FileMint 新建文件菜单">
      <figcaption>桌面背景也能直接新建。</figcaption>
    </figure>
    <figure class="screen-card">
      <img src="/images/finder-folder-context-menu-zh.png" alt="在 Finder 文件夹右键打开 FileMint 新建文件菜单">
      <figcaption>在常用文件夹里，文件始终创建在当前的位置。</figcaption>
    </figure>
  </div>
</section>

<section id="create" class="landing-section">
  <p class="section-kicker">02 / CREATE WITH CONTEXT</p>
  <h2>需要多一点掌控时，仍然只是一个小面板。</h2>
  <p class="section-intro">输入完整文件名、选择后缀、确认位置，再按需写下第一段内容。Markdown、代码、笔记或配置都不必先生成空文件再打开别的应用。</p>
  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--panel">
      <img src="/images/create-panel-zh.png" alt="FileMint 新建文件面板，包含文件名、后缀、位置和初始内容">
      <figcaption>完整文件名会同步后缀；内容只在你明确输入或粘贴时读取。</figcaption>
    </figure>
    <div class="copy-stack">
      <h3>不只是“新建一个空白文件”</h3>
      <p>直接把想要的内容写进去，然后创建。多行文本、中文、空格和模板符号都会按原文保存。</p>
      <ul class="benefit-list">
        <li><strong>⌘↩</strong> 随时创建，<strong>Esc</strong> 取消</li>
        <li>完整文件名优先，不会偷偷改写后缀</li>
        <li>同名时快速创建自动递增；自定义创建先询问</li>
      </ul>
    </div>
  </div>
</section>

<section id="types" class="landing-section">
  <p class="section-kicker">03 / YOUR MENU, YOUR TYPES</p>
  <h2>让右键菜单只留下你真正会用的类型。</h2>
  <p class="section-intro">常用格式开箱即用；其余格式可以按需启用。你也能添加自己的文本后缀和初始模板，并调整它们在 Finder 里的顺序。</p>
  <div class="visual-grid visual-grid--wide">
    <div class="copy-stack">
      <h3>按你的工作流整理</h3>
      <p>文本、Markdown、JSON、Swift、HTML、CSS、Shell 默认可用；CSV、YAML、XML、JavaScript、TypeScript、Python 和 SQL 随时可打开。</p>
      <ul class="benefit-list">
        <li>启用、停用、排序，不堆满无关选项</li>
        <li>保存自己的 <strong>.toml</strong>、<strong>.vue</strong> 或 <strong>.log</strong> 等文本后缀</li>
        <li>模板和右键菜单保持同步</li>
      </ul>
    </div>
    <figure class="screen-card">
      <img src="/images/file-types-zh.png" alt="FileMint 文件类型管理界面">
      <figcaption>所有类型都能在一个原生设置页里管理。</figcaption>
    </figure>
  </div>
</section>

<section id="roadmap" class="landing-section">
  <p class="section-kicker">04 / TODO</p>
  <h2>未来规划，一件件慢慢做好。</h2>
  <p class="section-intro">从日常创建文件的小事出发，逐步打磨这些功能。未勾选的项目还未完成，清单会随着实际使用和反馈持续更新。</p>

<div class="roadmap-todos">

<!--@include: ../README.md#roadmap-->

</div>

  <p class="roadmap-links"><a href="https://github.com/FileMintApp/FileMint/blob/main/docs/ROADMAP.md">查看实施路线</a>，或在 <a href="https://github.com/FileMintApp/FileMint/issues">GitHub 分享你的使用场景</a>。也欢迎贡献模板、翻译和复现步骤。</p>
</section>

<section id="download" class="landing-section">
  <div class="callout-band">
    <div>
      <h2>小、原生、安静地把一件小事做好。</h2>
      <p>macOS 13+，Apple 芯片和 Intel 均可使用。文件创建离线完成，没有账号、订阅、遥测或后台目录扫描。</p>
    </div>
    <div class="callout-actions">
      <a href="https://github.com/FileMintApp/FileMint/releases/latest">下载最新版本</a>
      <a href="./install.html">查看安装指引</a>
    </div>
  </div>
</section>
