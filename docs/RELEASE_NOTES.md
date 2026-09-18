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
