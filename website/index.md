---
layout: home
hero:
  name: FileMint
  text: 把文件工具，放回 Finder。
  tagline: 一个小体积的原生 macOS app：右键创建、处理、整理文件与图片。离线、按需启用。
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

<div class="hero-proof" aria-label="FileMint product facts">
  <span><strong>Swift + AppKit</strong> 原生应用</span>
  <span><strong>小体积</strong> 无网页运行时</span>
  <span><strong>6</strong> 个图片资源工具</span>
  <span>本地处理，不绕远程服务</span>
</div>

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
      <p>文本、Markdown、JSON、Swift、HTML、CSS、Shell 等格式一键创建。</p>
    </article>
    <article class="feature-card">
      <span class="feature-index">03</span>
      <h3>明确的边界</h3>
      <p>Finder 扩展和文件夹授权分开管理，不静默扩大范围，也不后台扫描。</p>
    </article>
  </div>

  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--menu">
      <img src="/images/finder-resource-menu-zh.png" alt="当前安装版 Finder 右键菜单，展示新建文件、文件工具和资源工具">
      <figcaption>当前安装版示例：选中 longmao.navigator.png 后，三类入口各自保持清楚。</figcaption>
    </figure>
    <div class="copy-stack">
      <div class="mini-label">ONE CONTEXT MENU, CLEAR LAYERS</div>
      <h3>创建和处理，各有自己的位置</h3>
      <p>“新建文件”负责创建；“文件（夹）工具”负责已选项目；“资源工具”负责图片。可选模块默认关闭，开启后也不会把所有操作混成一条长菜单。</p>
      <ul class="benefit-list">
        <li>彩色图标帮助你快速区分三类入口</li>
        <li>文件工具和资源工具只在适用的选中范围内出现</li>
        <li>每项操作可以放在一级菜单或自己的子菜单</li>
      </ul>
    </div>
  </div>
</section>

<section id="create" class="landing-section">
  <p class="section-kicker">02 / CREATE WITH CONTEXT</p>
  <h2>需要掌控时，仍然只是一个小面板。</h2>
  <p class="section-intro">完整文件名、后缀、保存位置和初始内容在创建前一次完成。你可以从一个真实的 Markdown 草稿开始，而不是先生成空文件。</p>

  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--panel">
      <img src="/images/create-panel-zh.png" alt="FileMint 当前版本的新建文件面板，填写 project-kickoff.md 和初始内容">
      <figcaption>完整文件名与后缀同步；多行文本、中文、空格和模板符号按原文保存。</figcaption>
    </figure>
    <div class="copy-stack">
      <div class="mini-label">CREATE ONCE, KEEP THE CONTEXT</div>
      <h3>不是“先建空文件再打开编辑器”</h3>
      <p>输入 <strong>project-kickoff.md</strong>，粘贴第一段内容，然后创建。命名、位置和内容都在同一条路径里完成。</p>
      <ul class="benefit-list">
        <li><strong>⌘↩</strong> 创建，<strong>Esc</strong> 取消</li>
        <li>自定义后缀仍然是 UTF-8 文本，不会假装转换成别的文档格式</li>
        <li>同名时快速创建自动递增；自定义创建在替换前询问</li>
      </ul>
    </div>
  </div>
</section>

<section id="resources" class="landing-section landing-section--tint">
  <p class="section-kicker">03 / RESOURCE TOOLS</p>
  <h2>图片处理，也回到你选中的文件旁边。</h2>
  <p class="section-intro">选中图片，右键打开“资源工具”，或从 FileMint 主应用直接选择。六个工具共享同一个本地面板，预览、参数和输出位置都在眼前。</p>

  <div class="visual-grid visual-grid--wide">
    <figure class="screen-card screen-card--panel">
      <img src="/images/resource-tools-zh.png" alt="FileMint 资源工具页面，显示六个图片处理工具">
      <figcaption>转换、压缩、调整尺寸、生成图标、拼接和提取文字。</figcaption>
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

  <div class="visual-grid visual-grid--wide visual-grid--reverse">
    <div class="copy-stack">
      <div class="mini-label">LOCAL PREVIEW / ORIGINALS STAY UNCHANGED</div>
      <h3>从一张真实图片开始</h3>
      <p>下面的面板使用 <strong>longmao.navigator.png</strong> 作为示例。输出格式、保存位置和原图保护都明确可见；处理在你的 Mac 上完成，不上传图片。</p>
      <div class="quote-card">
        <span class="quote-mark">“</span>
        <p>先看预览，再点处理。原图始终保留。</p>
      </div>
    </div>
    <figure class="screen-card screen-card--panel">
      <img src="/images/resource-panel-longmao-zh.png" alt="FileMint 使用 longmao.navigator.png 的图片格式转换面板">
      <figcaption>真实资源示例：longmao.navigator.png。</figcaption>
    </figure>
  </div>
</section>

<section id="file-tools" class="landing-section">
  <p class="section-kicker">04 / FILE &amp; FOLDER TOOLS</p>
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
      <img src="/images/file-tools-zh.png" alt="FileMint 文件与文件夹工具设置页面，显示菜单位置和独立开关">
      <figcaption>每项工具独立开关、独立菜单位置；危险操作默认关闭。</figcaption>
    </figure>
  </div>
</section>

<section id="settings" class="landing-section landing-section--quiet">
  <p class="section-kicker">05 / A QUIETER NATIVE UI</p>
  <h2>层次清晰，设置少找一步。</h2>
  <p class="section-intro">当前版本用固定侧栏把创建、扩展和偏好分开：模板与类型、创建行为、文件工具、资源工具、Finder 与文件夹、关于，各自有清楚的位置。</p>

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
      <p>中文、英文、浅色和深色外观共享同一套原生窗口与控件，不用记另一套网页交互。</p>
    </article>
  </div>
</section>

<section id="privacy" class="landing-section landing-section--tint">
  <p class="section-kicker">06 / LOCAL BY DEFAULT</p>
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
      <p>主应用只在你检查或下载更新时访问 GitHub；Finder 扩展不需要网络。</p>
    </article>
  </div>
</section>

<section id="roadmap" class="landing-section">
  <p class="section-kicker">07 / TODO</p>
  <h2>未来规划，继续把小事做好。</h2>
  <p class="section-intro">下面只列还没有完成的方向，不把已经交付的能力重新包装成路线图。</p>

  <div class="roadmap-todos">

<!--@include: ../README.md#roadmap-->

  </div>

  <p class="roadmap-links"><a href="https://github.com/FileMintApp/FileMint/blob/main/docs/ROADMAP.md">查看实施路线</a>，或在 <a href="https://github.com/FileMintApp/FileMint/issues">GitHub 分享你的使用场景</a>。</p>
</section>

<section id="download" class="landing-section landing-section--last">
  <div class="callout-band">
    <div>
      <div class="mini-label">FILEMINT 0.5.7</div>
      <h2>从 Finder 开始，做完，然后回到你的工作。</h2>
      <p>支持 macOS 13+、Apple 芯片和 Intel。Developer ID 签名并通过 Apple 公证；首次使用仍需按系统提示启用 Finder 扩展和文件夹授权。</p>
    </div>
    <div class="callout-actions">
      <a href="https://github.com/FileMintApp/FileMint/releases/latest">下载最新版本</a>
      <a href="./install.html">查看安装指引</a>
    </div>
  </div>
</section>
