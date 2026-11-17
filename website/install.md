---
title: 安装 FileMint
description: 在 macOS 上安装 FileMint，启用 Finder 扩展并授权文件夹。了解 DMG、Homebrew 安装方式、自动更新及 Apple 芯片兼容要求。
---

# 安装 FileMint

<LatestRelease lang="zh" />

FileMint 支持 **macOS 13.0 及以上的 M 系列 Mac**。快捷指令与[启动器接入](https://github.com/FileMintApp/FileMint/blob/main/docs/SHORTCUTS_AND_LAUNCHERS.zh-CN.md)需要 macOS 13.3 或更新版本。当前正式版安装包使用 Developer ID 签名，已通过 Apple 公证并附加公证票据。

## 首次安装

1. 从 [GitHub Releases](https://github.com/FileMintApp/FileMint/releases/latest) 下载最新 DMG。
2. 打开 DMG，把 FileMint 拖入「应用程序」，然后推出安装磁盘。
3. 从「应用程序」启动 FileMint，按[首次设置](./guide#先完成首次设置)启用 Finder 扩展、选择右键菜单范围并授权文件夹。也可以跳过 Finder 设置，直接在 FileMint 中选择「新建文件…」。

全新安装也可用 [FileMint 官方 Homebrew tap](https://github.com/FileMintApp/homebrew-tap)：

```sh
brew install --cask filemintapp/tap/filemint
```

已有手动安装时，请先阅读 tap 的迁移说明。Homebrew 不会替你启用 Finder 扩展或授权文件夹。

导入的 Word 和 Excel 模板保存在本机。只有选择「图片粘贴为文件」时，FileMint 才会读取剪贴板图片。相关操作见[使用指南](./guide)。

## 后续更新

打开「关于 → 检查更新」，发现新版后可选择「更新并重启」。请先完成创建或编辑；macOS 可能要求管理员授权。

自动检查更新默认开启，可在「通用」关闭。FileMint 运行时每 7 天最多检查一次版本信息；关闭后仍可手动检查，并自行决定是否安装。

从 0.5.7 或 0.5.8 升级时，请先手动安装 0.5.9 或更新版本一次。其他旧版本升级、Intel 兼容性和下载校验见 [GitHub 安装说明](https://github.com/FileMintApp/FileMint/blob/main/docs/INSTALL.md)。
