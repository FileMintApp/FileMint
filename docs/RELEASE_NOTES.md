# FileMint 0.6.1

## 新功能

- **常用文件（夹）**：主动保存本地文件或文件夹，按名称、路径或分组搜索、固定并快速定位。Finder 和菜单栏只展示有限的已保存项目；FileMint 不扫描目录或读取文件内容。
- **Finder 显示切换**：在“Finder 与文件夹”或菜单栏中明确点按后切换隐藏项目显示。首次使用需要在 macOS 辅助功能设置中授权；FileMint 不猜测或保存 Finder 当前的显示状态。
- **移除图片隐私元数据**：为支持的 JPEG、PNG、TIFF 和普通单图 HEIC 生成经读取校验的 `-clean` 副本，不修改原图。重新编码可能改变文件大小或颜色；画面中可见的信息不会被移除。

## 设置改进

- 可编辑或移除内置和自定义文件类型，按需恢复内置类型；拖动排序显示清晰的插入位置。模板身份、顺序和用户设置会保留。
- 收藏管理页支持按名称、路径、分组、文件夹或可用状态查找已保存项目，并提供批量整理操作。

## 系统要求与升级

0.6.1 正式安装包面向运行 macOS 13 或更新版本的 M 系列 Mac，不含 Intel 代码。Intel Mac 不能安装或通过应用内更新升级到 0.6.1；0.5.10 及更早已发布安装包保留各自原有兼容范围。运行 0.6.0 的 M 系列用户可通过“关于 → 检查更新 → 更新并重启”升级。

0.5.7/0.5.8 用户仍需先手动安装 0.5.9 或更新版本一次，修复旧版自身无法修复的更新器签名权限问题。

## New features

- **Favorite Locations**: Save local files or folders you choose, then search, group, pin and locate them. Finder and the menu bar show a bounded list of saved items; FileMint does not crawl folders or read file contents.
- **Finder display toggle**: Click the action in Finder & Folders or the menu bar to toggle hidden items. First use requires Accessibility permission in macOS. FileMint does not guess or save Finder's current display state.
- **Remove Private Metadata**: Create a verified `-clean` copy of supported JPEG, PNG, TIFF and ordinary single-image HEIC files without changing the original. Re-encoding may affect size or color; information visible in the pixels is outside this feature's scope.

## Settings improvements

- Edit or remove built-in and custom file types, restore built-ins when needed, and reorder types with a clear insertion marker. Template identity, order and user settings are retained.
- The Favorite Locations manager can search saved items by name, path, group, kind or availability and supports batch organization.

## System requirements and upgrading

The 0.6.1 stable installer targets M-series Macs running macOS 13 or later and contains no Intel code. Intel Macs cannot install or update to 0.6.1; published installers through 0.5.10 retain their original compatibility. M-series users on 0.6.0 can upgrade through **About → Check for Updates → Update and Restart**.

Versions 0.5.7/0.5.8 still require one manual installation of 0.5.9 or later to fix updater signing permissions that those versions cannot repair themselves.

# FileMint 0.6.0

## 改进

- Finder 菜单可调整“使用 App 打开”的项目顺序，也可选择“新建文件”显示在主菜单或子菜单。
- 文件移动和删除会在执行时重新校验授权范围、所选项目和目标；源项目变化、路径越界或目标重名时会拒绝操作。无效设置文件不会被保存覆盖。
- “完全磁盘访问”设置入口会打开适用于 macOS 13 及更新版本的系统设置页面；权限仍需由用户在 macOS 中确认。

## 系统要求与升级

0.6.0 正式安装包面向运行 macOS 13 或更新版本的 M 系列 Mac。此版本不含 Intel 代码，Intel Mac 不能安装或通过应用内更新升级到 0.6.0；已发布的 0.5.10 及更早版本保留各自原有兼容范围。0.5.10 的 M 系列用户可通过“关于 → 检查更新 → 更新并重启”升级。

0.5.7/0.5.8 用户仍需先手动安装 0.5.9 或更新版本一次，修复旧版自身无法修复的更新器签名权限问题。

## Improvements

- Reorder **Open with App** entries in Finder and choose whether **New File** appears in the main menu or a submenu.
- File moves and deletions recheck authorized scope, item identity and destination at execution time. Changed sources, paths outside scope and name conflicts are rejected. Invalid settings files are not overwritten by saves.
- The Full Disk Access settings shortcut opens the System Settings page used by macOS 13 and later. macOS still requires the user to confirm the permission.

## System requirements and upgrading

The 0.6.0 stable installer targets M-series Macs running macOS 13 or later. It contains no Intel code, so Intel Macs cannot install or update to 0.6.0. Published installers through 0.5.10 retain their original compatibility. M-series users on 0.5.10 can upgrade through **About → Check for Updates → Update and Restart**.

Versions 0.5.7/0.5.8 still require one manual installation of 0.5.9 or later to fix updater signing permissions that those versions cannot repair themselves.

# FileMint 0.5.10

## 改进

- Finder 扩展未启用时，“通用”页会显示启用引导，并提供打开系统扩展设置的按钮；“Finder 与文件夹”页也会显示对应 macOS 版本的设置路径。返回应用后会刷新扩展状态。
- 官网新增中英文使用指南，按实际操作介绍文件创建、模板、图片与文件工具，以及 Finder 菜单或文件夹访问未生效时的处理方法。
- 发布流程加强版本、签名权限、Sparkle 安装器、Apple 公证及远端资产的一致性校验。

## 升级说明

已安装 0.5.9 的用户可以通过“关于 → 检查更新 → 更新并重启”升级。0.5.7/0.5.8 的安装器权限问题仍需先手动安装一次新版；旧版自身无法修复其签名权限。

## Improvements

- When the Finder extension is disabled, General shows setup guidance and a button to open macOS extension settings. Finder & Folders also shows the settings path for the current macOS version. The app refreshes extension status when you return.
- The website now has bilingual task-based guides for creating files, using templates, image and file tools, and resolving missing Finder menus or folder access.
- Release checks now validate version progression, signed permissions, the Sparkle installer, Apple notarization, and consistency of the uploaded assets.

## Upgrading

Users on 0.5.9 can upgrade through About → Check for Updates → Update and Restart. Versions 0.5.7/0.5.8 still require one manual installation because their existing signed installer permissions cannot be repaired remotely.

# FileMint 0.5.9

## 修复

- 修复正式包签名时未展开 Sparkle 安装器权限的问题，避免应用内更新在安装阶段被 macOS 沙盒拒绝。
- 发布流程新增签名内权限校验，阻止错误权限的安装包通过构建和发布验证。
- 增加真实沙盒应用的下载、替换与自动重启验证。

## 升级说明

已确认 0.5.7 和 0.5.8 受此问题影响。请退出旧版，手动将本版拖入“应用程序”替换，推出安装磁盘后重新打开。旧版自身的签名权限无法通过远端更新修正，因此需要手动安装这一次。

## Fixes

- Resolve Sparkle installer entitlement variables during release signing so the macOS sandbox permits in-app installation.
- Validate the entitlements embedded in signed bundles and reject incorrectly configured release artifacts.
- Add a real sandboxed update check covering download, replacement and automatic relaunch.

## Upgrading

Versions 0.5.7 and 0.5.8 are confirmed affected. Quit the old app, manually replace it in Applications, eject the installer and reopen FileMint. A remote update cannot repair the running old app's signed permissions, so this upgrade requires one manual installation.

# FileMint 0.5.8

> 后续确认：0.5.7/0.5.8 的更新安装权限有误，需要手动安装 0.5.9 一次。下文保留本版原始功能记录。
>
> Follow-up: 0.5.7/0.5.8 have incorrect updater entitlements. Manually install 0.5.9 once. The original feature notes are retained below.

## 新功能

- **使用 App 打开**：在「扩展功能 → 使用 App 打开」添加常用应用，然后在 Finder 中用它打开所选文件或文件夹。每个应用可独立放在一级菜单或子菜单，不改变系统默认打开方式。
- **图片粘贴为文件**：将拷贝的截图或图片带入创建面板，预览、命名后保存为 PNG。同名时自动编号，取消不会生成文件。
- **同格式多模板**：为同一种格式保存不同的模板、默认文件名和初始内容，并指定默认模板。在 Finder 或创建面板中按模板名称选择。
- **Word / Excel 文档模板**：导入 `.docx`、`.xlsx`，从模板创建保留原有格式和内容的独立副本；导入后不再依赖原文件的位置。
- **主题设置**：在「通用 → 外观 → 主题」选择跟随系统、浅色或深色。默认跟随系统，切换即时生效并保存。

## 体验改进

- 修正设置页下拉框的右对齐，统一控件尺寸、分组标题、说明文字、按钮反馈和禁用状态。
- 创建面板支持 Tab / Shift-Tab 切换输入项；切换模板时保留已编辑的文件名和内容。
- 调整中英文、浅深色和最小窗口尺寸下的布局，保持设置页与创建、图片处理窗口的视觉一致。

## New features

- **Open with App**: Add your go-to apps under Extensions, then open selected Finder files or folders with them. Each app can appear in the main menu or a submenu without changing default file associations.
- **Paste Image as File**: Preview and name a copied screenshot or image, then save it as PNG. Existing names are numbered; cancelling creates no file.
- **Multiple templates per format**: Keep separate templates, default filenames and starter content for one format. Set a default and select templates by name in Finder or the creation panel.
- **Word / Excel document templates**: Import `.docx` or `.xlsx` and create independent copies with the original formatting and content. Imported templates no longer depend on the source file's location.
- **Theme settings**: Choose Follow System, Light or Dark in General → Appearance → Theme. Follow System is the default; changes apply immediately and persist.

## Improvements

- Right-align settings pickers and standardize control sizes, section headings, supporting text, button feedback and disabled states.
- Use Tab / Shift-Tab to move through the creation form. Edited filenames and content are preserved when switching templates.
- Refine Chinese and English layouts in light/dark mode and at minimum window size, with consistent settings, creation and image-processing windows.

## 安装与更新 / Installation and updates

支持 macOS 13 及以上，Apple 芯片与 Intel 共用一个 DMG。0.5.5 及之后的版本可通过「关于 → 检查更新 → 更新并重启」升级；0.5.4 及更早版本请手动安装本版一次。

Requires macOS 13 or later, with one universal DMG for Apple silicon and Intel. Version 0.5.5 and later can use About → Check for Updates → Update and Restart; upgrade manually once from 0.5.4 or earlier.

正式安装包在 Developer ID 签名、Apple 公证接受、票据附加与校验通过后发布，随附 SHA-256 校验文件和签名的 `appcast.xml`。

The stable installer is published after Developer ID signing, accepted Apple notarization, stapling and verification, with a SHA-256 checksum and signed `appcast.xml`.

# FileMint 0.5.7

## 产品展示与文档 / Product presentation and documentation

- 官网首页和 README 重新整理，突出小体积原生 macOS app、Finder 工作流、本地处理和清晰的隐私边界。
- 官网与 README 增加当前安装版的 Finder、创建面板、资源工具和文件（夹）工具截图。
- 安装与隐私说明同步资源工具、文件工具和当前 0.5.7 安装包信息。

- The website and README now lead with FileMint's small native macOS footprint, Finder workflow, local processing and clear privacy boundaries.
- Current installed-build screenshots cover Finder menus, the creation panel, Resource Tools and File & Folder Tools.
- Installation and privacy documentation now match Resource Tools, File & Folder Tools and the 0.5.7 installer.

# FileMint 0.5.6

已于 2026-09-18 发布：[GitHub Release v0.5.6](https://github.com/FileMintApp/FileMint/releases/tag/v0.5.6)。DMG、SHA-256 校验和和 `appcast.xml` 均已发布；签名、公证与远端下载核验见 [0.5.6 发布验证记录](RELEASE_VERIFICATION_0.5.6.md)。

## 新功能 / New features

- 文件（夹）工具支持逐项选择 Finder 一级菜单或二级菜单，包括「将所选项目移到此处」。同一项只显示一次，空子菜单自动隐藏；新建文件菜单和创建流程保持不变。
- 新增「彻底删除」。它只处理点按时捕获的所选项目，默认需要二次确认并绕过废纸篓；可明确改为“直接静默删除”。静默模式不会跳过文件夹授权，删除符号链接时只删除链接本身。
- 新增「隔空投送」。它在点击后拉起 macOS 原生隔空投送界面，由用户选择接收设备；不会自动发送或回退为其他分享方式。
- 彻底删除和隔空投送默认关闭，可在文件（夹）工具中分别启用；设置开关改为系统小尺寸。

- File & Folder Tools now lets every action choose Finder's main menu or the submenu, including Move Selected Items Here. An action appears once only, empty submenus disappear, and New File remains unchanged.
- Delete Permanently handles only the captured selected items. It confirms by default and bypasses Trash, with an explicit Delete silently option. Silent deletion never bypasses folder authorization, and deleting a symbolic link removes the link rather than its target.
- AirDrop opens macOS's native recipient UI after an explicit click. The user chooses the recipient; it never sends automatically or falls back to another sharing service.
- Delete Permanently and AirDrop start disabled and can be enabled separately. Settings switches now use the native small control size.

# FileMint 0.5.5

## 新功能 / New features

### 设置页改为侧栏结构 / Redesigned settings sidebar

- 设置不再把所有选项挤在同一页。新的固定侧栏将通用、创建行为、模板与类型、Finder 与文件夹、扩展功能和关于分开，进入后能直接看到每一页负责的内容。
- 通用页集中管理界面语言、登录时启动、菜单栏和自动检查更新；创建行为页集中管理同名处理与创建后在 Finder 中选中结果。
- 模板与类型仍可启用、停用、排序和编辑自定义文本类型；Finder 与文件夹页保留扩展状态、菜单范围、文件夹授权和完全磁盘访问指引。
- 侧栏底部始终提供“新建文件…”，无需先切回某个设置页。About、检查更新和可用更新提示都在同一个设置窗口中处理。
- 页面可用键盘方向键切换，中文、英文以及明暗外观下保持原生控件、可读的焦点和选中状态。

- Settings no longer place every option on one page. A persistent sidebar separates General, Creation, Templates & Types, Finder & Folders, Extensions and About, so each page has a clear purpose.
- General now groups interface language, launch at login, menu bar visibility and automatic update checks. Creation groups collision handling and revealing the completed file in Finder.
- Templates & Types keeps enable, disable, reorder and custom text-type editing. Finder & Folders retains extension status, menu scope, folder authorization and Full Disk Access guidance.
- New File… is always available at the bottom of the sidebar. About, update checks and available-update notices all stay in the same settings window.
- Arrow-key sidebar navigation, readable focus/selection states, and native controls work across Chinese, English, light and dark appearances.

### 文件（夹）工具 / File & Folder Tools

- 新增独立的“文件（夹）工具”模块，默认关闭。开启后，它以与“新建文件”并列的 Finder 根菜单出现，不会改变已有的新建文件菜单。
- 总开关下可分别开启“拷贝文件（夹）名称”“拷贝文件（夹）路径”和“移动文件（夹）”。关闭总开关会隐藏菜单，但保留各子项选择，之后可继续恢复使用。
- 拷贝名称会保留完整后缀，拷贝路径会写入完整本地路径；多选项目按 Finder 中的选择顺序逐行写入剪贴板。
- 工具只在已授权范围内、已选中的本地文件或文件夹上显示。混入范围外项目时不会悄悄只处理其中一部分；背景、工具栏和侧栏菜单也不会出现这些选择工具。
- 移动采用两步操作：先在源项目上选择“移动文件（夹）”，此时不会立即移动；再到目标文件夹空白处右键，选择最外层“将所选项目移到此处”。
- 待移动批次会保存并在重启后保留，直到成功完成或被新的源选择替换。移动前会再次检查当前开关、文件夹范围和批次标识，避免在切换 Finder 窗口或改变选择后移动错误项目。
- 同名目标绝不覆盖或合并；无效目标、已变更的源项目、将文件夹移入自身或子目录等情况会被拒绝。部分成功后，尚未完成的项目会保留以便处理问题后重试。
- 名称、路径和移动操作均不读取文件内容、不扫描目录、不监控剪贴板，也不会把路径写入日志。只有明确点按拷贝菜单项才会写入剪贴板。

- File & Folder Tools is a new standalone module, disabled by default. When enabled, it appears as a Finder root menu beside New File and leaves the existing creation menu unchanged.
- Its master switch has independent Copy Names, Copy Paths and Move File / Folder switches. Turning the master switch off hides the menu but preserves each child choice for later use.
- Copy Names retains complete suffixes, while Copy Paths writes full local paths. Multi-selection is copied to the clipboard one Finder-order item per line.
- Tools appear only for selected local files or folders inside an authorized scope. A mixed out-of-scope selection is never processed partially, and selection tools never appear in background, toolbar or sidebar menus.
- Moving is deliberate and two-step: choose Move File / Folder on source items without moving them yet, then right-click the target folder background and choose the root-level Move Selected Items Here action.
- A pending batch survives relaunch until it completes or a new source selection replaces it. Before moving, FileMint rechecks the enabled switches, folder scope and batch identity so changing Finder windows or selections cannot move the wrong items.
- Existing names are never overwritten or merged. Invalid targets, changed sources, and moving a folder into itself or a descendant are rejected. After a partial failure, unfinished items remain available to retry.
- Names, paths and moves do not read file contents, crawl folders, monitor the clipboard or write paths to logs. The clipboard is written only after you explicitly choose a Copy menu item.

### 应用内更新安装 / In-app update installation

- “关于 → 检查更新”发现新版本后，选择“更新并重启”即可下载、校验、替换应用并重新打开，不再需要先把安装包保存到 Finder。
- 安装只接受当前选择版本的不可变 appcast；会核对版本、下载地址、文件大小和 EdDSA 签名，拒绝降级、错误仓库、重定向到不可信主机、信息项或增量包。
- 检查和下载阶段显示进度并可以取消；进入解压和安装后才会锁定取消，避免显示已取消却已开始替换的错误状态。
- 正在创建文件、移动项目或编辑模态内容时，更新会保留工作并要求稍后重试；不会强制关闭 Finder、丢弃草稿或修改文件夹授权。
- 从 0.5.4 及更早版本升级时，请手动安装 0.5.5 一次；之后支持该更新器的版本可使用应用内更新。

- Once About → Check for Updates finds a newer version, choose Update and Restart to download, verify, replace and reopen the app without first saving an installer in Finder.
- Installation accepts only the selected version's immutable appcast. It checks version, download URL, size and EdDSA signature, rejecting downgrades, wrong repositories, untrusted redirects, informational items and delta packages.
- Checking and downloading show progress and can be cancelled. Cancellation locks only after extraction and installation begin, so the UI never claims a replacement was cancelled after it has committed.
- Updates preserve work and ask you to retry later while a file is being created or moved, or while modal editing is open. They never force Finder to quit, discard a draft or change folder authorization.
- Upgrade manually from 0.5.4 or earlier once. Later compatible releases can use in-app updates.

## 文档与安装 / Documentation and installation

- README、官网首页、安装页和隐私页已同步设置侧栏与文件（夹）工具的开启路径、可见范围、两步移动方式和剪贴板边界。
- 已实现的“拷贝文件（夹）名称 / 路径”不再列在未来 TODO 中；未来规划只保留尚未实现的方向。
- 0.5.5 支持 macOS 13 及以上，并提供 Apple 芯片与 Intel 通用 DMG。退出旧版，将 FileMint 拖入“应用程序”替换，推出安装磁盘，再从“应用程序”打开；Finder 扩展启用和文件夹访问仍由 macOS 与用户分别管理。

- The README, website home, installation page and privacy page now document the sidebar, File & Folder Tools enablement, visibility rules, two-step moves and clipboard boundary.
- Implemented Copy Names / Copy Paths are no longer listed as future TODOs; the roadmap retains only unfinished directions.
- FileMint 0.5.5 supports macOS 13 and later in one universal DMG. Quit the old app, replace it in Applications, eject the installer volume and reopen it. Finder extension enablement and folder access remain separate macOS and user actions.

## 发布包校验 / Release package verification

正式安装包由开发者本机为主应用、Finder 扩展和 DMG 完成 Developer ID 签名。GitHub Release 只会在 Apple 公证接受、票据已附加、挂载镜像校验和完整 SHA-256 校验通过后发布，并随包提供 appcast.xml。该本机构建不宣称 GitHub Actions 构建来源认证。

The stable installer is Developer ID signed locally for the main app, Finder extension and DMG. The GitHub Release is published only after Apple notarization is accepted, its ticket is stapled, mounted-image validation and the final SHA-256 check pass. It includes appcast.xml and does not claim GitHub Actions build provenance.

~~~sh
shasum -a 256 -c FileMint-0.5.5.dmg.sha256
~~~

详细安装与权限说明见 [安装指引 / Installation](https://github.com/FileMintApp/FileMint/blob/main/docs/INSTALL.md)，签名、公证、校验值和远端下载验证见 [0.5.5 发布验证记录](https://github.com/FileMintApp/FileMint/blob/main/docs/RELEASE_VERIFICATION_0.5.5.md)。

For installation and permissions, read the [installation guide](https://github.com/FileMintApp/FileMint/blob/main/docs/INSTALL.md). Signing, notarization, checksums and remote-download evidence are recorded in the [0.5.5 release verification](https://github.com/FileMintApp/FileMint/blob/main/docs/RELEASE_VERIFICATION_0.5.5.md).

## 许可 / License

个人及非商业使用免费；商业使用须获事先书面授权或单独签发的付费商业许可。打赏不授予商业权利。

Personal and non-commercial use is free; commercial use requires separate written authorization or a paid commercial license. Donations do not grant commercial rights. [License](https://github.com/FileMintApp/FileMint/blob/main/LICENSE).
