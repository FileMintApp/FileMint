<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import { withBase } from 'vitepress'
import LatestRelease from './LatestRelease.vue'
const props = withDefaults(defineProps<{ lang?: 'zh' | 'en' }>(), { lang: 'zh' })
const en = computed(() => props.lang === 'en')
const t = (zh: string, english: string) => en.value ? english : zh
const page = (path: string) => withBase(`${en.value ? '/en' : ''}/${path}.html`)
const asset = (name: string) => withBase(`/images/${name}-${props.lang}.jpg`)
const release = 'https://github.com/FileMintApp/FileMint/releases/latest'
const quickSearchGuide = computed(() => `${page('guide')}#${t('用快捷搜索找到操作、模板和设置', 'find-actions-templates-and-settings-with-quick-search')}`)
const active = ref(0)
const preview = ref<HTMLDialogElement | null>(null)
type Capture = { image: string; alt: string; class?: string }
const previewCapture = ref<Capture | null>(null)
async function openPreview(capture: Capture) {
  previewCapture.value = capture
  await nextTick()
  preview.value?.showModal()
}
const scenes = computed(() => [
  { label: t('新建文件', 'Create a file'), title: t('从一个好开头开始。', 'Start with a head start.'), detail: t('文件名、位置、初始内容，一次写好。', 'Name, location, and first lines. All in one place.'), image: en.value ? asset('create-panel') : withBase('/images/create-workflow-zh.png'), alt: t('真实新建文件面板，包含文件名、保存位置与 Markdown 内容', 'Real New File panel with filename, destination and Markdown content'), class: 'creation' },
  { label: t('处理图片', 'Process images'), title: t('给图片一个新的用途。', 'A new purpose for your images.'), detail: t('转换格式、预览结果，原图始终保留。', 'Choose a format. Preview it. Keep your original.'), image: withBase(`/images/resource-panel-longmao-${props.lang}.png`), alt: t('真实图片转换窗口，展示预览、输出格式与保存位置', 'Real image conversion window with preview, formats and destination'), class: 'image' },
  { label: t('打开 App', 'Open your apps'), title: t('接着在熟悉的 App 里工作。', 'Continue in your favorite app.'), detail: t('把常用编辑器和终端放进右键菜单。', 'Bring your editors and terminals into the context menu.'), image: asset('open-with'), alt: t('使用 App 打开设置示例，已配置应用与菜单位置', 'Example Open with App configuration with applications and menu placement'), class: 'apps' },
  { label: t('快捷搜索', 'Quick Search'), title: t('快捷搜索，一按就到。', 'Quick Search, a shortcut away.'), detail: t('⌃⌥K · 默认关闭，可在「通用 → 快捷搜索」启用。', '⌃⌥K · Optional. Enable in General → Quick Search.'), image: asset('quick-search'), alt: t('已安装 FileMint 的真实快捷搜索弹窗，展示分类、新建文件、从剪贴板新建和图片粘贴为文件', 'Quick Search in the installed FileMint app, showing categories, New File, New File from Clipboard and Paste Image as File'), class: 'search', width: 1360, height: 1000, href: quickSearchGuide.value }
])
function choose(index: number) { active.value = index }
function onTabKey(event: KeyboardEvent, index: number) {
  let next = index
  if (event.key === 'ArrowRight') next = (index + 1) % scenes.value.length
  else if (event.key === 'ArrowLeft') next = (index + scenes.value.length - 1) % scenes.value.length
  else if (event.key === 'Home') next = 0
  else if (event.key === 'End') next = scenes.value.length - 1
  else return
  event.preventDefault(); choose(next)
  document.getElementById(`scene-tab-${next}`)?.focus()
}
const searchScopes = computed(() => [
  { title: t('新建操作', 'Creation actions'), body: t('新建一份文件，或从剪贴板开始。', 'Create a file, or start with your clipboard.') },
  { title: t('你的模板', 'Your templates'), body: t('找到已启用的模板，复用熟悉的开头。', 'Find enabled templates for a familiar head start.') },
  { title: t('常用位置', 'Favorite locations'), body: t('定位已收藏的文件与文件夹。', 'Locate the files and folders you have saved.') },
  { title: t('应用设置', 'App settings'), body: t('直达需要的设置页面，少找一层。', 'Jump straight to the settings you need.') }
])
const everydayActions = computed(() => [
  {
    id: 'copy', title: t('拷贝内容，省去一次打开。', 'Copy the contents. Keep your flow.'),
    body: t('右键一个文本文件，把完整内容放入剪贴板。代码、Markdown 和配置文件保留原有空白与换行。', 'Right-click a text file to copy its complete contents. Keep whitespace and line endings in code, Markdown and configuration files.'),
    hint: t('完整读取 · 本机处理', 'COMPLETE CONTENTS · ON YOUR MAC'),
    note: t('在「文件（夹）工具」中按需开启。源文件与解码文本各限 8 MiB，受支持的文本与有限 RTF 格式适用。', 'Enable it in File & Folder Tools. Source and decoded text are each limited to 8 MiB; supported text and a limited RTF subset are accepted.'),
    link: t('了解拷贝文件内容', 'Explore Copy File Contents'), anchor: t('拷贝文件内容', 'copy-file-contents')
  },
  {
    id: 'creation', title: t('直接新建，顺畅切换。', 'Create directly. Move smoothly.'),
    body: t('新建操作直接打开创建面板，在「保存位置」里换目录。图片预览窗口更紧凑，设置侧栏连续上下键切换更顺畅。', 'Open creation drafts directly and change the destination in Save Location. Image previews fit their content, and rapid arrow keys keep settings selection in step.'),
    hint: t('Tab 切换 · ⌘↩ 创建 · Esc 取消', 'Tab to navigate · ⌘↩ to create · Esc to cancel'),
    note: t('只有「创建」才写入文件；实际缺少写入权限时，仍按 macOS 提示授权。', 'Only Create writes a file. macOS still requests authorization when write access is missing.'),
    link: t('查看创建流程', 'Explore the creation flow'), anchor: t('自己填写名称与内容', 'choose-the-name-and-starter-content')
  }
])
const fileTools = computed(() => [
  {
    id: 'rename', label: t('批量重命名', 'Batch Rename'),
    title: t('一组文件，一次理顺。', 'Bring a batch into order.'),
    body: t('替换文字、统一编号，或粘贴一份名称列表。每个新名字，都先看清再确认。', 'Replace text, add a numbering rule, or paste a list of names. Review every new name before you commit.'),
    facts: [t('规则组合，原名与新名并排预览', 'Combine rules. Compare original and new names.'), t('保留扩展名与隐藏状态，冲突时阻止执行', 'Keep extensions and hidden status. Conflicts block the batch.'), t('可预览并撤销最近一次成功操作', 'Preview and undo the most recent successful rename.')],
    image: asset('batch-rename'),
    alt: t('批量重命名真实界面：编号规则、原名与新名对照，以及重命名确认按钮', 'Real Batch Rename window with a numbering rule, original and new names, and an explicit Rename button'),
    caption: t('编号规则示例 · 执行前核对每个新名称', 'Example numbering rule · Review every name before renaming'),
    scope: t('同一文件夹内 2–1,000 个项目 · 本地可写 APFS', '2–1,000 items in one folder · Local, writable APFS'),
    link: t('了解批量重命名', 'Explore Batch Rename'), anchor: t('批量重命名', 'batch-rename')
  },
  {
    id: 'checksums', label: t('文件信息与校验值', 'File Info & checksums'),
    title: t('一个文件，核对清楚。', 'Give that file a closer look.'),
    body: t('查看大小、类型和日期，再按需计算校验值。拷贝结果，或粘贴预期校验值，查看是否匹配。', 'Check the size, kind and dates, then calculate a checksum when you need it. Copy the result or compare it with an expected value.'),
    facts: [t('打开只看信息，点击后才计算', 'Opening shows metadata. Calculation starts with your click.'), t('SHA-256、SHA-512、SHA-1、MD5，可一次计算全部', 'SHA-256, SHA-512, SHA-1 and MD5, individually or in one pass.'), t('支持取消、拷贝与单一算法比对', 'Cancel, copy, or compare using one algorithm.')],
    image: asset('file-info'),
    alt: t('文件信息真实界面：示例文件的大小、日期、SHA-256 计算结果和校验值比对入口', 'Real File Info window with example file metadata, a calculated SHA-256 result and the checksum comparison control'),
    caption: t('SHA-256 计算结果示例 · 文件内容在本机读取', 'Example SHA-256 result · File contents are read on your Mac'),
    scope: t('单个普通文件 · SHA-256 为默认推荐算法', 'One ordinary file · SHA-256 is the recommended default'),
    link: t('了解文件校验', 'Explore file checksums'), anchor: t('文件信息与校验值', 'file-info-and-checksums')
  }
])
const features = computed(() => [
  { n: '01', title: t('文件创建', 'File creation'), body: t('文本、代码、Word 与 Excel；也能把剪贴板文字或图片存成文件。', 'Text, code, Word and Excel. Turn copied text or images into a file.'), tags: 'TXT · MD · DOCX · XLSX', anchor: t('在当前位置创建文件', 'create-a-file-where-you-are') },
  { n: '02', title: t('你的模板', 'Your templates'), body: t('复用内容与命名，预览、备份和分享模板。创建后继续在 App 中工作。', 'Reuse content and names. Preview, back up and share templates, then open your app.'), tags: t('内容变量 / 导入导出', 'VARIABLES / IMPORT & EXPORT'), anchor: t('保存常用模板', 'save-reusable-templates') },
  { n: '03', title: t('图片工具', 'Image tools'), body: t('转换、压缩、缩放、图标、拼接、OCR 与隐私元数据清理。', 'Convert, compress, resize, create icons, stitch, extract text and remove private metadata.'), tags: t('7 个工具 / 本地处理', '7 TOOLS / ON YOUR MAC'), anchor: t('处理图片与提取文字', 'process-images-and-extract-text') },
  { n: '04', title: t('使用 App 打开', 'Open with App'), body: t('选中的文件，当前的目录，交给你喜欢的编辑器或终端。', 'Send selected files or the current folder to your editor or terminal.'), tags: t('编辑器 / 终端', 'EDITORS / TERMINALS'), anchor: t('用自己的-app-打开项目或当前文件夹', 'open-selected-items-or-the-current-folder-with-your-apps') },
  { n: '05', title: t('文件整理', 'File organization'), body: t('批量重命名、查看文件信息与校验值，也能拷贝名称和路径、移动或隔空投送。', 'Batch rename, inspect file info and checksums, copy names and paths, move items or AirDrop.'), tags: t('按需启用 / 独立配置', 'OPT IN / MAKE IT YOURS'), anchor: t('按需开启文件-夹-工具', 'enable-file-folder-tools-when-needed') },
  { n: '06', title: t('常用位置', 'Favorite locations'), body: t('收藏文件与文件夹，按名称或分组搜索，把常用位置留在手边。', 'Save files and folders. Search by name or group. Keep familiar places close.'), tags: t('收藏 / 固定 / 搜索', 'SAVE / PIN / SEARCH'), anchor: t('保存和查找常用文件-夹', 'save-and-find-favorite-locations') }
])
const faqs = computed(() => [
  [t('我的 Mac 可以使用吗？', 'Will it work on my Mac?'), t('当前正式版支持 macOS 13 或更新版本的 M 系列 Mac。Intel Mac 请查看安装指南中的历史版本兼容说明。', 'The current stable app supports M-series Macs running macOS 13 or later. For Intel Macs, see the historical compatibility notes in the installation guide.')],
  [t('FileMint 免费吗？', 'Is FileMint free?'), t('个人、教育、研究及其他非商业使用免费。商业使用须事先获得书面授权或单独购买商业许可；捐赠不等同于商业授权。', 'Personal, educational, research and other non-commercial use is free. Commercial use requires prior written authorization or a separate commercial license. Donations do not grant commercial rights.')],
  [t('为什么 Finder 里没有菜单？', 'Why is the menu missing in Finder?'), t('先确认系统中的 Finder 扩展已启用，再检查当前文件夹是否在菜单显示范围内。需要操作文件时，按提示授权对应文件夹。不同工具会根据所选项目显示。', 'Check that the Finder extension is enabled and the current folder is in your configured menu scope. Grant access to the relevant folder when prompted. Available tools depend on your selection.')],
  [t('一定要开启所有功能吗？', 'Do I need to enable everything?'), t('可以只用你需要的部分。文件工具与资源工具的 Finder 入口默认关闭，菜单位置可独立配置；主应用仍可新建文件和处理图片。', 'Use just what you need. Finder integration for file and image tools starts off, and menu placement is configurable. You can still create files and process images in the app.')],
  [t('文件会上传吗？', 'Are my files uploaded?'), t('文件创建、批量重命名、校验值计算、图片处理和 OCR 均在本机完成，不上传到远程处理服务。主动选择粘贴时才读取剪贴板。应用可每周检查更新；下载和安装由你决定。', 'File creation, batch renaming, checksums, image processing and OCR run on your Mac, without uploading files for processing. Clipboard content is read only when you choose a paste action. The app can check weekly for updates; downloads and installation are your choice.')]
])
</script>

<template>
  <main class="fm-landing">
    <dialog ref="preview" class="fm-preview" :aria-label="t('界面截图预览', 'Interface screenshot preview')" @click="($event.target === preview) && preview?.close()">
      <button type="button" class="fm-preview-close" @click="preview?.close()">{{ t('关闭', 'Close') }} ×</button>
      <img v-if="previewCapture" :src="previewCapture.image" :alt="previewCapture.alt" :class="{ 'fm-preview-creation': previewCapture.class === 'creation' }">
    </dialog>
    <section class="fm-hero fm-wrap" aria-labelledby="hero-title">
      <div class="fm-hero-copy">
        <div class="fm-eyebrow"><span class="fm-dot" /> {{ t('为 macOS 而生', 'MADE FOR macOS') }} <span class="fm-eyebrow-rule" /></div>
        <h1 id="hero-title">{{ t('顺手的工具，', 'Your tools.') }}<br><em>{{ t('一按即达。', 'Within reach.') }}</em></h1>
        <p class="fm-hero-lead">{{ t('一次右键，或一组快捷键。', 'A right-click. A shortcut. Keep your flow.') }}</p>
        <p class="fm-hero-description">{{ t('在 Finder 右键新建文件，用全局快捷键找到操作、模板与常用位置。批量重命名、校验文件、处理图片，常用工具都在手边。', 'Create files with a right-click in Finder. Find actions, templates and favorites with a global shortcut. Rename files, verify checksums and process images, all on your Mac.') }}</p>
        <a class="fm-hero-shortcut" href="#quick-search" :aria-label="t('了解全局快捷键 Control + Option + K', 'Discover the Control + Option + K global shortcut')"><span class="fm-hero-keys" aria-hidden="true"><kbd>⌃</kbd><kbd>⌥</kbd><kbd>K</kbd></span><span>{{ t('全局快捷键，随时呼出', 'Your tools, a shortcut away') }}</span><span aria-hidden="true">↗</span></a>
        <div class="fm-actions"><a class="fm-button fm-button-primary" :href="release"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true"><path d="M12 3v12m-5-5 5 5 5-5M4 16v4h16v-4"/></svg>{{ t('下载 macOS 版', 'Download for macOS') }}</a><a class="fm-text-link" href="#workflows">{{ t('看看怎么用', 'See it in action') }} <span aria-hidden="true">↗</span></a></div>
        <div class="fm-release-line"><LatestRelease :lang="lang" /><span>macOS 13+ · Apple M-series</span></div>
        <p class="fm-license">{{ t('个人及非商业使用免费', 'Free for personal & non-commercial use') }}</p>
      </div>
      <div class="fm-product-stage">
        <div class="fm-stage-top"><span class="fm-stage-mark">F<span>ileMint</span></span><span>{{ t('少一点往返，多一点专注。', 'A little less friction.') }}</span></div>
        <div v-for="(scene, index) in scenes" :key="scene.class" v-show="active === index" :id="`scene-panel-${index}`" role="tabpanel" :aria-labelledby="`scene-tab-${index}`" tabindex="0" class="fm-scene" :class="`fm-scene--${scene.class}`">
          <div class="fm-scene-image"><button class="fm-capture-button" type="button" :aria-label="t('放大界面截图', 'Enlarge interface screenshot')" @click="openPreview(scene)"><img :src="scene.image" :alt="scene.alt" :width="scene.width" :height="scene.height" :fetchpriority="index === 0 ? 'high' : 'auto'" :loading="index === 0 ? 'eager' : 'lazy'"></button></div>
          <div class="fm-scene-caption"><strong><a v-if="scene.href" class="fm-scene-guide" :href="scene.href">{{ scene.title }} <span aria-hidden="true">↗</span></a><template v-else>{{ scene.title }}</template></strong><span>{{ scene.detail }}</span></div>
        </div>
        <div class="fm-scene-tabs" role="tablist" :aria-label="t('探索使用场景', 'Explore workflows')"><button v-for="(scene, index) in scenes" :key="scene.class" :id="`scene-tab-${index}`" type="button" role="tab" :aria-selected="active === index" :aria-controls="`scene-panel-${index}`" :tabindex="active === index ? 0 : -1" @click="choose(index)" @keydown="onTabKey($event, index)"><span class="fm-tab-number">0{{ index + 1 }}</span>{{ scene.label }}</button></div>
        <p class="fm-capture-note">{{ t('真实应用界面 · 示例配置，可按需调整', 'Real app captures · Example configuration, yours to customize') }}</p>
      </div>
    </section>

    <div class="fm-principles fm-wrap"><span>{{ t('原生 macOS 体验', 'Native to macOS') }}</span><span>{{ t('文件在本机处理', 'Files stay on your Mac') }}</span><span>{{ t('无需账号', 'No account needed') }}</span><span>{{ t('菜单按你所需', 'Your menu, your way') }}</span></div>

    <section id="quick-actions" class="fm-section fm-wrap fm-everyday" aria-labelledby="quick-actions-title">
      <span id="quick-search" class="fm-anchor" />
      <div class="fm-shortcut-showcase">
        <div class="fm-shortcut-intro">
          <div class="fm-shortcut-copy">
            <p class="fm-eyebrow">{{ t('全局快捷键 / 快捷搜索', 'GLOBAL SHORTCUT / QUICK SEARCH') }}</p>
            <h2 id="quick-actions-title">{{ t('手不离键盘，', 'Keep your flow.') }}<br><em>{{ t('思路不必打断。', 'Call up your tools.') }}</em></h2>
            <p class="fm-shortcut-description">{{ t('写到一半，想到就做。FileMint 运行时，从其他应用按下快捷键，搜索操作、模板、常用位置与设置，接着完成手头的事。', 'An idea should not mean a detour. While FileMint is running, call up Quick Search from another app. Find an action, template, favorite or setting, and carry on.') }}</p>
            <a class="fm-text-link" :href="quickSearchGuide">{{ t('了解快捷搜索', 'Explore Quick Search') }} <span aria-hidden="true">↗</span></a>
          </div>
          <div class="fm-shortcut-visual">
            <p class="fm-shortcut-visual-label">{{ t('从你正在工作的应用，即刻呼出', 'RIGHT FROM THE APP YOU ARE IN') }}</p>
            <div class="fm-shortcut-combination" role="img" aria-label="Control + Option + K">
              <kbd><span>⌃</span><small>control</small></kbd>
              <kbd><span>⌥</span><small>option</small></kbd>
              <kbd class="fm-shortcut-key-main"><span>K</span></kbd>
            </div>
            <p class="fm-shortcut-default">{{ t('默认组合 · 也可以换成你习惯的快捷键', 'THE DEFAULT COMBINATION. MAKE IT YOURS.') }}</p>
            <div class="fm-shortcut-navigation">
              <span><kbd>↑</kbd><kbd>↓</kbd> {{ t('选择', 'Select') }}</span>
              <span><kbd>↵</kbd> {{ t('执行', 'Run') }}</span>
              <span><kbd>esc</kbd> {{ t('关闭', 'Close') }}</span>
            </div>
          </div>
        </div>
        <ul class="fm-search-scopes">
          <li v-for="(scope, index) in searchScopes" :key="index"><span class="fm-search-scope-number" aria-hidden="true">0{{ index + 1 }}</span><h3>{{ scope.title }}</h3><p>{{ scope.body }}</p></li>
        </ul>
      </div>
      <div class="fm-shortcut-setup">
        <p><strong>{{ t('由你选择，按需开启。', 'Your shortcut. Your choice.') }}</strong><span>{{ t('在「通用 → 快捷搜索」启用；组合可自行录制。', 'Enable it in General → Quick Search. Choose your own keys if you prefer.') }}</span></p>
        <p class="fm-shortcut-conditions">{{ t('默认关闭 · 需 FileMint 运行', 'Off by default · FileMint must be running') }}<span>{{ t('无需辅助功能或输入监控权限', 'No Accessibility or Input Monitoring permission needed') }}</span></p>
      </div>
      <div class="fm-everyday-grid">
        <article v-for="action in everydayActions" :key="action.id" class="fm-everyday-card" :aria-labelledby="`everyday-${action.id}`">
          <h3 :id="`everyday-${action.id}`">{{ action.title }}</h3>
          <div><p>{{ action.body }}</p><p class="fm-everyday-hint">{{ action.hint }}</p><p class="fm-everyday-note">{{ action.note }}</p></div>
          <footer><a class="fm-text-link" :href="`${page('guide')}#${action.anchor}`">{{ action.link }} <span aria-hidden="true">↗</span></a></footer>
        </article>
      </div>
    </section>

    <section id="file-tools" class="fm-section fm-wrap fm-file-tools" aria-labelledby="file-tools-title">
      <div class="fm-section-heading">
        <div><p class="fm-eyebrow">01 / {{ t('文件工具，进一步', 'TAKE YOUR FILES FURTHER') }}</p><h2 id="file-tools-title">{{ t('整理得有序。', 'Names in order.') }}<br><em>{{ t('核对得清楚。', 'Contents checked.') }}</em></h2></div>
        <p>{{ t('批量重命名与文件信息，默认关闭。在「文件（夹）工具」中按需开启，让整理和核对从一次右键开始。', 'Batch Rename and File Info start off. Enable them in File & Folder Tools, then start organizing and checking from Finder.') }}</p>
      </div>
      <div class="fm-tool-grid">
        <article v-for="tool in fileTools" :key="tool.id" class="fm-tool" :aria-labelledby="`tool-${tool.id}`">
          <div class="fm-tool-copy"><p class="fm-eyebrow">{{ tool.label }}</p><h3 :id="`tool-${tool.id}`">{{ tool.title }}</h3><p>{{ tool.body }}</p></div>
          <figure class="fm-tool-figure">
            <button class="fm-tool-capture" type="button" :aria-label="`${t('放大', 'Enlarge')} ${tool.label}`" @click="openPreview(tool)"><img :src="tool.image" :alt="tool.alt" :width="tool.id === 'rename' ? 1680 : 960" :height="tool.id === 'rename' ? 1110 : 1020" loading="lazy"></button>
            <figcaption>{{ tool.caption }}</figcaption>
          </figure>
          <ul class="fm-tool-facts"><li v-for="fact in tool.facts" :key="fact">{{ fact }}</li></ul>
          <div class="fm-tool-footer"><p>{{ tool.scope }}</p><a class="fm-text-link" :href="`${page('guide')}#${tool.anchor}`">{{ tool.link }} <span aria-hidden="true">↗</span></a></div>
        </article>
      </div>
    </section>

    <section id="workflows" class="fm-section fm-wrap">
      <div class="fm-section-heading"><div><p class="fm-eyebrow">02 / {{ t('顺着你的工作', 'KEEP YOUR FLOW') }}</p><h2>{{ t('从这里开始。', 'Start right here.') }}<br>{{ t('也在这里完成。', 'Finish right here.') }}</h2></div><p>{{ t('不用记住一整套工具。只要在你正在工作的地方，选一个恰好需要的动作。', 'No new workspace to learn. Just the right action, in the place you are already working.') }}</p></div>
      <div class="fm-steps"><article><span>01</span><h3>{{ t('找到手边的文件', 'Find your starting point') }}</h3><p>{{ t('当前文件夹里新建，选中文件后处理。每次操作都有明确的位置。', 'Create in the current folder, or select files to work on. Every action has a clear destination.') }}</p></article><article><span>02</span><h3>{{ t('右键，选一个动作', 'Right-click. Pick an action.') }}</h3><p>{{ t('常用项放一级菜单，其他工具收进子菜单。只留下你需要的入口。', 'Keep favorites in the main menu and tuck other tools into submenus. Make room for what matters.') }}</p></article><article><span>03</span><h3>{{ t('完成，接着工作', 'Done. Back to your work.') }}</h3><p>{{ t('创建文档、保存图片副本，或直接打开熟悉的 App。', 'Create your document, save a new image, or continue in an app you know.') }}</p></article></div>
    </section>

    <section id="features" class="fm-section fm-feature-section"><span id="finder" class="fm-anchor"/><div class="fm-wrap"><div class="fm-section-heading"><div><p class="fm-eyebrow">03 / {{ t('小工具，刚刚好', 'A CONSIDERED TOOLKIT') }}</p><h2>{{ t('日常小事，', 'Everyday tasks,') }}<br><em>{{ t('都有顺手的方式。', 'beautifully in reach.') }}</em></h2></div><a class="fm-text-link" :href="page('guide')">{{ t('阅读完整指南', 'Explore the user guide') }} ↗</a></div><div class="fm-feature-grid"><a v-for="feature in features" :key="feature.n" :href="`${page('guide')}#${feature.anchor}`" class="fm-feature"><div class="fm-feature-top"><span>{{ feature.n }}</span><span aria-hidden="true">↗</span></div><h3>{{ feature.title }}</h3><p>{{ feature.body }}</p><span class="fm-feature-tags">{{ feature.tags }}</span></a></div><div class="fm-personalize"><p>{{ t('菜单层级、图标配色、深浅主题，都按你的习惯。', 'Menu placement, icon colors, light or dark. Make it feel like yours.') }}</p><a class="fm-text-link" :href="`${page('guide')}#${t('调整外观与更新', 'appearance-and-updates')}`">{{ t('了解外观与设置', 'Explore appearance settings') }} ↗</a></div></div></section>

    <section id="resources" class="fm-section fm-wrap fm-showcase"><div class="fm-showcase-copy"><p class="fm-eyebrow">04 / {{ t('看得见的掌控感', 'WORK WITH CONFIDENCE') }}</p><h2>{{ t('让图片就位。', 'Make it picture-ready.') }}<br><em>{{ t('让原图留下。', 'Keep the original.') }}</em></h2><p>{{ t('把素材转成需要的格式，统一尺寸，提取图片里的文字。预览与输出位置清楚可见，结果另存副本。', 'Convert your assets, resize a batch, or extract the words inside an image. See the preview and destination. Save the result as a separate copy.') }}</p><ul><li>{{ t('格式转换、压缩与缩放', 'Conversion, compression and resizing') }}</li><li>{{ t('图标生成、拼接与文字识别', 'Icons, stitching and text recognition') }}</li><li>{{ t('移除图片隐私元数据', 'Private metadata removal') }}</li></ul><a class="fm-text-link" :href="`${page('guide')}#${t('处理图片与提取文字', 'process-images-and-extract-text')}`">{{ t('了解图片工具', 'Meet the image tools') }} ↗</a></div><figure class="fm-showcase-figure"><img :src="withBase(`/images/resource-panel-longmao-${lang}.png`)" :alt="t('FileMint 图片格式转换真实界面，可预览图片并选择输出格式', 'Real FileMint image conversion interface with preview and output options')" width="1600" height="1212" loading="lazy"><figcaption>{{ t('转换图片界面示例 · 图片与 OCR 均在本机处理', 'Image conversion example · Image processing and OCR run locally') }}</figcaption></figure></section>

    <section id="privacy" class="fm-trust"><div class="fm-wrap"><div class="fm-trust-heading"><p class="fm-eyebrow">{{ t('安静，是一种设计选择', 'QUIET BY DESIGN') }}</p><h2>{{ t('你的文件。', 'Your files.') }}<br><em>{{ t('你的 Mac。', 'Your Mac.') }}</em></h2><a :href="page('privacy')" class="fm-text-link">{{ t('阅读隐私说明', 'Read the privacy policy') }} ↗</a></div><div class="fm-trust-details"><article><span>01</span><div><h3>{{ t('在本机完成', 'Processed locally') }}</h3><p>{{ t('创建、重命名、校验值计算、图片处理与 OCR，均在本机完成，不上传到远程处理服务。', 'Creation, renaming, checksums, image processing and OCR run on your Mac without uploading files for processing.') }}</p></div></article><article><span>02</span><div><h3>{{ t('只在你需要时', 'Only when you ask') }}</h3><p>{{ t('不后台扫描文件夹，不监控剪贴板。明确选择粘贴时，才读取那一项内容。', 'No background folder crawling or clipboard monitoring. Paste actions read content only when you choose them.') }}</p></div></article><article><span>03</span><div><h3>{{ t('每个入口，由你选择', 'You choose the tools') }}</h3><p>{{ t('不要求账号，不收集使用分析。工具按需启用，应用可每周检查更新，下载和安装由你决定。', 'No account or usage analytics. Enable the tools you need. The app can check weekly for updates; downloads and installation are up to you.') }}</p></div></article></div></div></section>

    <section id="faq" class="fm-section fm-wrap fm-faq"><div><p class="fm-eyebrow">05 / {{ t('开始之前', 'BEFORE YOU START') }}</p><h2>{{ t('还有一点', 'A few useful') }}<br>{{ t('想知道的。', 'things to know.') }}</h2><a class="fm-text-link" :href="page('install')">{{ t('查看安装指引', 'Installation guide') }} ↗</a></div><div><details v-for="(faq, i) in faqs" :key="i"><summary>{{ faq[0] }}<span aria-hidden="true">+</span></summary><p>{{ faq[1] }}</p></details></div></section>

    <section id="roadmap" class="fm-wrap fm-roadmap"><details><summary><span>{{ t('接下来，继续把小事做好。', 'More good things to come.') }}<small>{{ t('查看未来规划 · 以下尚未实现', 'View the roadmap · Planned, not yet available') }}</small></span><span aria-hidden="true">↗</span></summary><div class="fm-roadmap-content"><slot /></div></details></section>

    <section id="download" class="fm-section fm-wrap"><div class="fm-download"><img :src="withBase('/filemint-icon.png')" alt="" width="80" height="80" loading="lazy"><p class="fm-eyebrow">{{ t('下一次右键，从这里开始', 'YOUR NEXT RIGHT-CLICK STARTS HERE') }}</p><h2>{{ t('给工作流，留一点从容。', 'Make room for a smoother day.') }}</h2><p>{{ t('把常用的文件工具，放在恰好需要它们的地方。', 'Keep your everyday file tools right where you need them.') }}</p><div class="fm-actions"><a class="fm-button fm-button-primary" :href="release">{{ t('下载 FileMint', 'Download FileMint') }} <span aria-hidden="true">↓</span></a><a class="fm-text-link" :href="page('install')">{{ t('安装帮助', 'Installation help') }} ↗</a></div><div class="fm-release-line"><LatestRelease :lang="lang" /><span>macOS 13+ · Apple M-series</span></div><p class="fm-license">{{ t('个人及非商业使用免费 · 商业使用须获得授权', 'Free for non-commercial use · Commercial use requires authorization') }}</p><a class="fm-source-link" href="https://github.com/FileMintApp/FileMint">{{ t('在 GitHub 查看源码与更新记录', 'Source code & release history on GitHub') }} ↗</a></div></section>
  </main>
</template>
