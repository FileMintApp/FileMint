# FileMint Homebrew tap

[English](README.en.md)

FileMint 官方维护的 Homebrew tap，提供使用 GitHub Release 原始签名、公证 DMG 的 FileMint Cask。支持 M 系列 Mac、macOS 13 Ventura 或更新版本；Cask 的 `arm64` 检查不能区分 M 系列与其他 Apple 芯片。此 tap 尚未收录进 Homebrew 官方 Cask 仓库。

本 tap 提供已公开的 FileMint Cask。首次安装请使用下面的命令；现有手动安装的迁移，以及升级、卸载后的 Finder 行为仍待隔离环境验收。其他安装方式见 [FileMint 安装指引](https://filemintapp.github.io/FileMint/install)。

## 安装与首次使用

在没有现存 FileMint 安装的 Mac 上运行：

```sh
brew install --cask filemintapp/tap/filemint
```

启动 FileMint，按现有引导在 macOS 设置中启用 Finder 扩展，并在应用中授权需要使用的文件夹。Homebrew 不会代为授权、启用扩展或启动应用；保留正常的隔离属性和 Gatekeeper 检查。

## 更新

FileMint 的“更新并重启”和 Sparkle 更新继续可用。在应用内更新后，Homebrew 的安装记录可能暂时落后于实际应用版本。

`brew update` 只刷新 Homebrew 和 tap 元数据，不安装 FileMint：

```sh
brew update
```

**任何可能替换或移除 FileMint 的 brew 操作前，先保存或明确取消草稿，等待创建、导入、文件操作和 Sparkle 更新结束，再手动退出 FileMint 并确认退出。若无法安全退出，停止并等待，不要强制结束进程。** Cask 不发送退出或终止信号；Homebrew 也不强制检查这些前提。

确认上述条件后，才运行可能包含 FileMint 的批量升级：

```sh
brew upgrade
```

Cask 声明 `auto_updates true`。当前 Homebrew 会对适用的单应用包比较实际版本：较旧时可以升级，相同、较新或无法可靠比较时会跳过；旧版 Homebrew 或相应环境设置可能直接跳过此类 Cask。不要假定批量升级绝不会替换 FileMint。明确指定 Cask 的升级、`--greedy` / `--greedy-auto-updates` 以及 `reinstall` 可能绕过默认跳过判断，不是修复版本差异的通用步骤。若应用比 tap 更新，保留应用并等待 tap 同步；不要同时运行 Sparkle 和 brew 安装。规则以所用版本的 [Homebrew 手册](https://docs.brew.sh/Manpage#upgrade-options-installed_formulainstalled_cask-)和 [更新 FAQ](https://docs.brew.sh/FAQ#how-does-brew-upgrade-handle-apps-that-update-themselves)为准。

## 已有手动安装

继续使用现有安装和应用内更新。首次交付的手动安装迁移尚待隔离原生验收，因此不提供 `--adopt` 操作步骤。遇到已有应用冲突时，不使用 `--force`，不自动删除现有应用，也不安装第二份来规避冲突。版本号相同不能单独证明包内容、签名或授权状态相同。

## 卸载与数据保留

**先保存或取消草稿，完成文件操作和 Sparkle 更新，手动退出 FileMint 并确认退出；不能安全退出时推迟卸载。** tap 发布并安装后，普通卸载命令为：

```sh
brew uninstall --cask filemintapp/tap/filemint
```

普通卸载移除由 Homebrew 管理的应用；Cask 不包含 `zap`，保留用户创建的文件、偏好、导入模板和保存的文件夹书签。它不是彻底重置操作。重新安装也必须先完成工作并退出；保存的授权是否仍可用由 macOS 状态决定，可能需要重新授权。卸载后的 Finder 扩展与菜单生命周期仍需隔离环境验收。

## 验证与维护

仓库的只读工作流执行 Cask 格式、解析、在线元数据审计及版本发现，不安装应用，不持有 Apple 密钥，也不发布新版本。这些结果不证明安装、升级、迁移、卸载或 Finder 的原生行为。

Cask 从 [FileMint 已验证的正式版本](https://github.com/FileMintApp/FileMint/releases/latest)生成；不手工修改版本、校验和或发布过的 DMG。软件许可见 [FileMint LICENSE](https://github.com/FileMintApp/FileMint/blob/main/LICENSE)，不因 Homebrew 安装而改变。

问题请通过 [FileMint Issues](https://github.com/FileMintApp/FileMint/issues)反馈，并注明 macOS、Homebrew 和 FileMint 版本。
