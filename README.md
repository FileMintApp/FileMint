<p align="center"><img src="Resources/IconSource/FileMint-AppIcon-1024.png" width="112" alt="FileMint"></p>
<h1 align="center">FileMint</h1>
<p align="center"><strong>新文件，就在此刻。</strong><br>一个干净、直接的原生 macOS 文件创建工具。</p>
<p align="center"><strong>简体中文</strong> ｜ <a href="README.en.md"><strong>English →</strong></a></p>
<p align="center"><a href="https://github.com/FileMintApp/FileMint/releases/latest">下载 macOS 版</a> · <a href="docs/INSTALL.md">安装帮助</a> · <a href="https://github.com/FileMintApp/FileMint/issues">反馈问题</a></p>

想建一个文件，却要先打开编辑器、另存为、再找回刚才的文件夹？

FileMint 把这件事放回 Finder：**右键，选一种类型，文件就在这里。**
需要自己起名字或粘贴内容时，打开一个小面板就够了。

## 只做文件创建，把它做好

- **你起什么名字，就是什么文件。** 输入 `demo.js`，得到的就是 `demo.js`。完整文件名与后缀选择器会同步，也可以单独切换后缀。
- **常用类型，一次点击。** 文本、Markdown、JSON、Swift、HTML、CSS、Shell 随手可用；CSV、YAML、XML、JavaScript、TypeScript、Python、SQL 可按需启用。
- **你的后缀，你来定义。** 添加自己的 `.toml`、`.vue`、`.log` 等类型，保存常用初始内容，调整顺序，让右键菜单只留下需要的选项。
- **粘贴，然后创建。** 直接在创建面板粘贴代码、笔记或配置。不必先创建空文件再打开编辑器。多行、中文、空格和模板符号都按原文保存。
- **打开电脑就能用。** 首次安装启动后，默认开启登录时启动与菜单栏入口；两个开关都可在“通用”设置中关闭。
- **跟随你的语言。** 默认跟随系统显示“新建文件 / New File”，也可手动选择中文或 English。右键主入口显示 FileMint Logo，类型列表保持纯文字。
- **干净，也足够快。** Swift + AppKit + SwiftUI；原生菜单、原生文本编辑、纯文字选项。文件创建离线完成，没有网页运行时、账号或后台扫描。
- **更新由你决定。** 在“关于”或菜单中检查新版本，下载并校验安装包，再按提示完成安装。不会自动检查或下载。
- **同名也放心。** 快速创建自动递增名称；自定义创建在替换前询问。并发创建也不会悄悄覆盖已有文件。

## 怎么用

**快速创建：** 在常用文件夹的 Finder 空白处右键 → 新建文件 → 选择类型。

**自定义创建：** 新建文件… → 输入 `demo.js` → 按需粘贴内容 → 创建。

`Tab` 切换输入位置，`⌘V` 粘贴，`⌘↩` 创建，`Esc` 取消。在内容区按回车会正常换行。
也可以通过 FileMint 应用或菜单栏选择“新建文件…”，无需先启用 Finder 扩展。

自定义后缀创建的是 **UTF-8 文本文件**。修改后缀不会把文本转换成 PDF、图片或 Word/Excel 文件。

## 下载与安装

支持 **macOS 13 及以上**，同一个安装包兼容 Apple 芯片与 Intel Mac。

1. [下载最新 DMG](https://github.com/FileMintApp/FileMint/releases/latest)，把 FileMint 拖入“应用程序”。
2. 启动 FileMint，按应用内提示启用 Finder 扩展并授权常用文件夹。“文件夹”页也提供完全磁盘访问权限指引；它与沙盒文件夹授权相互独立。
3. 回到 Finder，开始创建。

后续更新：**关于 → 检查更新 → 下载更新**。安装包校验并打开后，退出 FileMint，
将新版拖入“应用程序”替换旧版，再重新打开。也可通过应用菜单或菜单栏检查更新。

**分发与来源认证：** FileMint 默认统一通过 GitHub Releases 分发，在 GitHub Actions 构建，提供 GitHub 构建来源认证和 SHA-256 校验。它尚未使用付费 Apple Developer ID 签名，也没有 Apple 公证，因此首次启动可能被 macOS 拦截，Finder 扩展也可能需要额外启用。GitHub 来源认证不等于 Apple 安全认证。请先阅读[首次安装与限制](docs/INSTALL.md)。

## 本地运行，内容属于你

不上传文件名、路径、内容；不收集使用数据；只在你主动粘贴时读取剪贴板。仅主动检查更新或下载时连接 GitHub。无需注册，无需订阅。见[隐私说明](PRIVACY.md)。

## 请我喝杯咖啡

如果 FileMint 少打断了你几次，欢迎随缘打赏。非商业使用无需付费，功能不因打赏与否而区别对待。打赏不等于购买商业授权，谢谢支持。

<p align="center">
  <img src="ReceivePayment/wx.JPG" width="220" alt="微信收款码">&nbsp;&nbsp;
  <img src="ReceivePayment/ali.JPG" width="220" alt="支付宝收款码">
</p>

## 源码与许可

版权：**XiaoDaiGua-Ray**。开发者：**XiaoDaiGua-Ray、GPT-Astra**。

**个人及非商业使用免费；商业使用须获得授权或单独购买商业许可。**

| 使用方式 | 授权要求 |
| --- | --- |
| 个人、学习、教育、研究等非商业使用 | 免费使用 |
| 非商业 fork、修改与再分发 | 免费，须保留许可和版权声明 |
| 企业商业流程、客户项目、收费服务 | 事先取得书面商业授权或付费商业许可 |
| 商业二次开发、收费分发或集成销售 | 事先取得书面商业授权或付费商业许可 |

本项目使用自定义[非商业源码许可](LICENSE)，**不采用 MIT**。源码公开不代表允许无授权商用。详见[商业授权说明](docs/COMMERCIAL_LICENSE.md)。

想参与改进？从[开发说明](docs/DEVELOPMENT.md)、[产品规范](specs/SPEC.md)和[验收记录](docs/ACCEPTANCE.md)开始。
