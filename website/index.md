---
layout: home
hero:
  name: FileMint
  text: 把文件工具，放回 Finder。
  tagline: 在 Finder 里新建文件、复用文档模板、打开常用 App，顺手处理文件与图片。原生 macOS 应用，本地完成，按需启用。
  image:
    src: /filemint-icon.png
    alt: FileMint
  actions:
    - theme: brand
      text: 下载 macOS 版
      link: https://github.com/FileMintApp/FileMint/releases/latest
    - theme: alt
      text: 查看 GitHub
      link: https://github.com/FileMintApp/FileMint
---

<p class="guide-entry">第一次使用？从 <a href="./guide.html">使用指南</a> 开始，跟着步骤完成第一份文件。</p>

<div class="hero-proof" aria-label="FileMint product facts">
  <span><strong>Swift + AppKit</strong> 原生应用</span>
  <span><strong>小体积</strong> 无网页运行时</span>
  <span><strong>6</strong> 个正式版图片工具</span>
  <span>本地处理，不绕远程服务</span>
</div>

<nav class="feature-nav" aria-label="功能导航">
  <a href="#finder">Finder</a>
  <a href="#create">新建文件</a>
  <a href="#templates">模板与图片粘贴</a>
  <a href="#open-with">使用 App 打开</a>
  <a href="#resources">图片工具</a>
  <a href="#qa-preview">0.6.1 新增</a>
  <a href="#file-tools">文件工具</a>
</nav>

<div class="architecture-strip">
  <article>
    <span class="mini-label">NATIVE MAC APP</span>
    <h3>菜单、窗口和编辑器都是原生的</h3>
    <p>Swift + AppKit + SwiftUI，直接接入 Finder 和 macOS 的权限、分享与窗口行为。</p>
  </article>
  <article>
    <span class="mini-label">SMALL FOOTPRINT</span>
    <h3>小体积，不带网页运行时</h3>
    <p>不嵌网页、不要求账号、不驻留后台扫描；打开就做事，做完回到你的工作。</p>
  </article>
  <article>
    <span class="mini-label">LOCAL PERFORMANCE</span>
    <h3>文件操作在本机完成</h3>
    <p>创建、图片处理和 OCR 不经过远程服务；Finder 入口只在明确点按时工作。</p>
  </article>
</div>

<section id="finder" class="landing-section landing-section--quiet">
  <p class="section-kicker">01 / FINDER FIRST</p>
  <h2>你在 Finder 哪，就从哪开始。</h2>
  <p class="section-intro">不用先打开编辑器、另存为，再找回刚才的目录。FileMint 把创建入口放回你正在工作的地方：右键、选类型，文件就在这里。</p>

  <div class="feature-grid feature-grid--three">
    <article class="feature-card">
      <span class="feature-index">01</span>
      <h3>当前目录</h3>
      <p>桌面背景和已授权 Finder 文件夹都能直接开始，不猜目标位置。</p>
    </article>
    <article class="feature-card">
      <span class="feature-index">02</span>
      <h3>常用类型</h3>
      <p>14 种内置文本与代码格式，可按需启用、排序，也能添加自己的模板。</p>
    </article>
    <article class="feature-card">
      <span class="feature-index">03</span>
      <h3>明确的边界</h3>
      <p>Finder 扩展和文件夹授权分开管理，不静默扩大范围，也不后台扫描。</p>
    </article>
  </div>

</section>

<section id="create" class="landing-section">
  <p class="section-kicker">02 / CREATE WITH CONTEXT</p>
  <h2>需要掌控时，仍然只是一个小面板。</h2>
  <p class="section-intro">完整文件名、后缀、保存位置和初始内容在创建前一次完成。你可以从一个真实的 Markdown 草稿开始，而不是先生成空文件。</p>

  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--panel">
      <div class="screen-window screen-window--creation"><img width="1120" height="1226" loading="lazy" decoding="async" src="/images/create-panel-zh.jpg" alt="FileMint 新建文件面板，填写 project-kickoff.md 和初始内容"></div>
      <figcaption>界面示例 · Markdown 草稿；文件名与后缀同步，初始内容原样保存。</figcaption>
    </figure>
    <div class="copy-stack">
      <div class="mini-label">CREATE ONCE, KEEP THE CONTEXT</div>
      <h3>文件名、位置、内容，一次写好</h3>
      <p>输入 <strong>project-kickoff.md</strong>，粘贴第一段内容，然后创建。命名、位置和内容都在同一条路径里完成。</p>
      <ul class="benefit-list">
        <li><strong>⌘↩</strong> 创建，<strong>Esc</strong> 取消</li>
        <li>自定义后缀仍然是 UTF-8 文本，不会假装转换成别的文档格式</li>
        <li>快速创建默认自动编号，也可设为报错；文本草稿替换前会询问</li>
      </ul>
    </div>
  </div>
</section>

<section id="templates" class="landing-section landing-section--quiet">
  <p class="section-kicker">03 / START FROM A TEMPLATE</p>
  <h2>常用的起点，不必每次重写。</h2>
  <p class="section-intro">同一种格式，可以有不同用途的模板。会议记录、项目说明、工作表，各自保留名称和内容，从 Finder 或创建面板直接选择。</p>
  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--panel">
      <div class="screen-window"><img width="1800" height="1300" loading="lazy" decoding="async" src="/images/file-types-zh.jpg" alt="FileMint 模板与类型页面，显示新建文本模板和导入文档模板入口"></div>
      <figcaption>内置类型按需启用；同格式可保存多个模板，并指定默认项。</figcaption>
    </figure>
    <div class="copy-stack">
      <div class="mini-label">TEXT / WORD / EXCEL</div>
      <h3>从空白文件，到你的文档模板</h3>
      <ul class="benefit-list">
        <li><strong>文本模板</strong>：保存默认文件名与初始内容，支持文件名、日期和年份变量</li>
        <li><strong>Word / Excel</strong>：导入 .docx 或 .xlsx，创建保留原格式与内容的独立副本</li>
        <li><strong>本地保存</strong>：导入后不再依赖原文档的位置，也不会修改原文档</li>
      </ul>
    </div>
  </div>
  <div class="feature-grid feature-grid--three">
    <article class="feature-card"><span class="feature-index">COPY</span><h3>图片粘贴为文件</h3><p>拷贝一张截图或图片，在 FileMint 或 Finder 的新建文件菜单中选择“图片粘贴为文件”。</p></article>
    <article class="feature-card"><span class="feature-index">PREVIEW</span><h3>先预览，再命名</h3><p>创建面板显示图片预览，填写文件名并确认保存位置。只有明确点按时才读取剪贴板。</p></article>
    <article class="feature-card"><span class="feature-index">PNG</span><h3>保存为 PNG</h3><p>保留透明度，同名自动编号。点击创建才写入；取消就不生成文件。</p></article>
  </div>
</section>

<section id="open-with" class="landing-section">
  <p class="section-kicker">04 / OPEN WITH YOUR APPS</p>
  <h2>选好文件，交给顺手的 App。</h2>
  <p class="section-intro">把常用编辑器、终端或其他应用加入 Finder 右键菜单。文件、文件夹和多选项目都能一起交给所选 App，由它决定支持的类型。</p>
  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--panel">
      <div class="screen-window"><img width="1800" height="1300" loading="lazy" decoding="async" src="/images/open-with-zh.jpg" alt="FileMint 使用 App 打开页面，展示三个已添加应用及独立菜单位置"></div>
      <figcaption>配置示例 · 新安装时列表为空，由你选择要添加的应用。</figcaption>
    </figure>
    <div class="copy-stack">
      <div class="mini-label">YOUR APPS / YOUR MENU</div>
      <h3>常用的放外面，其他的收起来</h3>
      <ul class="benefit-list">
        <li>每个 App 独立选择一级菜单或“使用 App 打开”子菜单</li>
        <li>保留系统默认打开方式，只为当前选择增加一个入口</li>
        <li>添加、移除和调整位置，都在同一个设置页完成</li>
      </ul>
    </div>
  </div>
</section>

<section id="resources" class="landing-section landing-section--tint">
  <p class="section-kicker">05 / RESOURCE TOOLS</p>
  <h2>图片处理，也回到你选中的文件旁边。</h2>
  <p class="section-intro">从主应用选择图片，或启用 Finder 菜单后在选中的图片旁直接开始。正式版的六个工具都在本机处理，先看预览，再确定参数和输出位置。</p>

  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--panel">
      <div class="screen-window"><img width="1800" height="1300" loading="lazy" decoding="async" src="/images/resource-tools-zh.jpg" alt="FileMint 资源工具页面，显示六个图片处理工具"></div>
      <figcaption>正式版界面示例 · 六个本地图片工具，原图保留，输出单独保存。</figcaption>
    </figure>
    <div class="copy-stack">
      <div class="mini-label">SIX SMALL TOOLS, ONE NATIVE SURFACE</div>
      <h3>把重复的图片小事一次收好</h3>
      <ul class="benefit-list">
        <li><strong>转换图片格式</strong>：JPEG、PNG、HEIC、TIFF</li>
        <li><strong>压缩与调整尺寸</strong>：保留比例，批量处理，不放大原图</li>
        <li><strong>生成图标</strong>：ICNS、ICO 与多尺寸 PNG</li>
        <li><strong>拼接图片与 OCR</strong>：排序、预览，识别后还能编辑文字</li>
      </ul>
    </div>
  </div>

</section>

<section id="qa-preview" class="landing-section landing-section--quiet qa-preview-section">
  <p class="section-kicker">06 / FILEMINT 0.6.1</p>
  <h2>0.6.1 正式版新增的 Finder 与图片工具。</h2>
  <p class="section-intro">以下功能已包含在 FileMint 0.6.1 正式版中。截图来自正式包实际运行的界面；下载按钮始终指向最新稳定版。</p>

  <div class="qa-preview-grid">
    <article class="qa-preview-card">
      <img src="/images/finder-hidden-items-zh.jpg" width="1322" height="948" loading="lazy" decoding="async" alt="FileMint 0.6.1 Finder 与文件夹设置页的隐藏项目切换界面">
      <div class="qa-preview-copy">
        <span class="qa-preview-label">正式版 · 0.6.1</span>
        <h3>由你点按的 Finder 显示切换</h3>
        <p>“Finder 与文件夹”提供明确的切换入口。首次使用需要在 macOS 中授予辅助功能权限；FileMint 不猜测或保存 Finder 当前的隐藏项目状态。</p>
      </div>
    </article>
    <article class="qa-preview-card">
      <img src="/images/favorite-locations-zh.jpg" width="1800" height="1300" loading="lazy" decoding="async" alt="FileMint 0.6.1 常用文件（夹）管理页">
      <div class="qa-preview-copy">
        <span class="qa-preview-label">正式版 · 0.6.1</span>
        <h3>常用文件（夹）</h3>
        <p>手动保存文件和文件夹，按名称、路径或分组搜索，并固定常用项。Finder 快捷菜单只列出有限的固定和最近项目；定位文件会在 Finder 中选中它，打开文件则是单独操作。</p>
      </div>
    </article>
    <article class="qa-preview-card">
      <img src="/images/remove-private-metadata-zh.jpg" width="1800" height="1300" loading="lazy" decoding="async" alt="FileMint 0.6.1 资源工具中的移除隐私元数据入口">
      <div class="qa-preview-copy">
        <span class="qa-preview-label">正式版 · 0.6.1</span>
        <h3>移除图片隐私元数据</h3>
        <p>在本机清理 GPS、拍摄时间、设备标识、IPTC、XMP 等元数据，再生成经过读取校验的副本，不覆盖原图。目标格式为 JPEG、PNG、TIFF 和系统支持的普通单图 HEIC；重新编码可能改变文件大小或颜色。文件名和画面中可见的信息仍由你检查。</p>
      </div>
    </article>
  </div>
</section>

<section id="file-tools" class="landing-section">
  <p class="section-kicker">07 / FILE &amp; FOLDER TOOLS</p>
  <h2>处理已选项目，但只在你明确点按时发生。</h2>
  <p class="section-intro">文件（夹）工具默认关闭。开启后，每项操作都可以放在 Finder 一级菜单或工具子菜单里；新建文件菜单保持独立，不会被挤乱。</p>

  <div class="visual-grid visual-grid--wide">
    <div class="copy-stack">
      <div class="mini-label">OPT IN / CHOOSE THE MENU LEVEL</div>
      <h3>把右键菜单整理成你的工作流</h3>
      <ul class="benefit-list">
        <li><strong>拷贝名称 / 路径</strong>：多选时每项一行；只有点按时才写入剪贴板</li>
        <li><strong>两步移动</strong>：先捕获源项目，再到目标文件夹空白处确认</li>
        <li><strong>彻底删除</strong>：默认二次确认，绕过废纸篓，不碰符号链接目标</li>
        <li><strong>隔空投送 / 发送替身到桌面</strong>：交给 macOS 原生界面和 Finder 原生别名</li>
      </ul>
    </div>
    <figure class="screen-card screen-card--panel">
      <div class="screen-window"><img width="1800" height="1300" loading="lazy" decoding="async" src="/images/file-tools-zh.jpg" alt="FileMint 文件与文件夹工具设置页面，显示菜单位置和独立开关"></div>
      <figcaption>配置示例 · 各项开关与菜单位置独立设置。</figcaption>
    </figure>
  </div>
</section>

<section id="settings" class="landing-section landing-section--quiet">
  <p class="section-kicker">08 / A QUIETER NATIVE UI</p>
  <h2>层次清晰，设置少找一步。</h2>
  <p class="section-intro">文件创建、扩展功能、偏好设置，三组固定侧栏。主题可选择跟随系统、浅色或深色；界面语言支持中文、英文和跟随系统。</p>

  <div class="feature-grid feature-grid--three">
    <article class="feature-card">
      <span class="feature-index">01</span>
      <h3>按功能分组</h3>
      <p>文件创建、扩展功能和偏好设置互不混在一起，方向键也能在页面间移动。</p>
    </article>
    <article class="feature-card">
      <span class="feature-index">02</span>
      <h3>按需启用</h3>
      <p>资源工具和文件工具都可以单独关闭；关闭只隐藏对应入口，不改变已有创建设置。</p>
    </article>
    <article class="feature-card">
      <span class="feature-index">03</span>
      <h3>原生可读</h3>
      <p>主题即时应用到 FileMint 的设置、创建和图片处理窗口，不改变 macOS 的外观。</p>
    </article>
  </div>
  <figure class="screen-card screen-card--settings">
    <div class="screen-window"><img width="1800" height="1300" loading="lazy" decoding="async" src="/images/settings-zh.jpg" alt="FileMint 通用设置中的主题、界面语言和启动选项"></div>
    <figcaption>界面示例 · 外观与语言各自选择，设置随时可改。</figcaption>
  </figure>
</section>

<section id="privacy" class="landing-section landing-section--tint">
  <p class="section-kicker">09 / LOCAL BY DEFAULT</p>
  <h2>安静，不等于不透明。</h2>
  <p class="section-intro">FileMint 把权限、联网和文件处理边界写在产品里：你知道它什么时候工作，也知道它什么时候不会工作。</p>

  <div class="trust-grid">
    <article class="trust-card">
      <span class="trust-symbol">⌁</span>
      <h3>本地创建与处理</h3>
      <p>文件创建、图片转换、压缩、缩放、拼接和 OCR 都在本机完成。</p>
    </article>
    <article class="trust-card">
      <span class="trust-symbol">∅</span>
      <h3>没有账号与遥测</h3>
      <p>不要求登录，不收集使用分析，不在后台枚举文件或读取文件内容。</p>
    </article>
    <article class="trust-card">
      <span class="trust-symbol">↗</span>
      <h3>联网边界清楚</h3>
      <p>主应用可每 7 天最多自动检查一次更新，也支持手动检查；下载与安装由你决定。Finder 扩展不联网。</p>
    </article>
  </div>
</section>

<section id="roadmap" class="landing-section">
  <p class="section-kicker">10 / TODO</p>
  <h2>未来规划，继续把小事做好。</h2>
  <p class="section-intro">这些是尚未完成的方向，具体进展会在项目中持续更新。</p>

  <div class="roadmap-todos">

<!--@include: ../README.md#roadmap-->

  </div>

  <p class="roadmap-links"><a href="https://github.com/FileMintApp/FileMint/blob/main/docs/ROADMAP.md">查看实施路线</a>，或在 <a href="https://github.com/FileMintApp/FileMint/issues">GitHub 分享你的使用场景</a>。</p>
</section>

<section id="download" class="landing-section landing-section--last">
  <div class="callout-band">
    <div>
      <div class="mini-label">LATEST STABLE RELEASE</div>
      <h2>从 Finder 开始，做完，然后回到你的工作。</h2>
      <p>下载按钮始终指向最新稳定版；安装要求和首次启用 Finder 的步骤见安装指引。以上新增功能已包含在 0.6.1 正式版中。</p>
    </div>
    <div class="callout-actions">
      <a href="https://github.com/FileMintApp/FileMint/releases/latest">下载最新版本</a>
      <a href="./install.html">查看安装指引</a>
      <a href="./guide.html">阅读使用指南</a>
    </div>
  </div>
</section>
