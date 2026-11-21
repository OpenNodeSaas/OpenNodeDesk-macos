# OpenNodeDesk（macOS 版）

**面向 macOS 的本地优先远程连接中枢。** 把散落各处的服务器、账号与连接参数收进一份可搜索、
可复用、可迁移的资产清单，并把「我要连那台机器」压缩到三步之内。

[English](../README.md) · **[简体中文]** · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português](README.pt.md) · [Русский](README.ru.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [Tiếng Việt](README.vi.md)

当前版本：**v2.3.5**

---

## 这是什么

OpenNodeDesk 不是又一个远程桌面客户端。远程画面的画质、外设重定向与音视频能力，跟随各平台最
成熟的客户端——RDP 用 Microsoft Windows App，VNC 用系统内置的「屏幕共享」，SSH 用内置终端。
OpenNodeDesk 负责的是**前面那 90%**：资产清单、连接参数、凭据、到期提醒与连接历史。

设计原则：

- **三秒发起连接**——搜索、回车、画面出现。
- **本地优先、离线可用、零账号**——无网络也能打开、搜索、编辑和发起连接。
- **不重造轮子**——远程渲染交给平台最合适的客户端。
- **参数可解释**——每个生效值都标注来源：自定义 / 模板 / 默认。
- **失败可解释**——错误就地给出原因与可执行建议，而不是抛一句原始错误码。
- **数据可携带**——一键导出与导入，换机迁移只需一个文件。
- **键盘优先**——核心操作全部有快捷键。

## 功能

### 资产中心
- 表格与宫格两种布局；支持按名称、主机、分组、负责人与备注搜索。
- 侧边栏提供收藏、最近连接与可展开/收起的分组。
- 列可显示/隐藏与重新排序，列表字号全局可调。
- 到期预警：剩余 30 天内或已过期的资产就地标注。
- 导入时按**主机 + 端口**判重。

### RDP / SSH / VNC
- 各协议默认端口（3389 / 22 / 5900），可自由覆盖。
- **RDP**——为 Microsoft Windows App 生成临时 `.rdp` 文件；窗口模式、色深、驱动器/音频/剪贴板
  重定向与分辨率均可配置。检测到 FreeRDP 命令行客户端时直接带入钥匙串中的密码，跳过凭据弹窗。
  Windows App 凭据对话框的自动填充使用 macOS「辅助功能」接口。
- **VNC**——默认使用系统内置「屏幕共享」；外装客户端（RealVNC、TigerVNC 等）可配置启动参数
  模板，支持 `{host} {port} {display} {user} {password}` 占位符。
- **SSH**——应用内嵌真实终端（SwiftTerm），支持跳板机（`-J`）、私钥认证、密钥口令，以及自定义
  额外的 `ssh` 参数。

### 连接方案模板
可复用的参数集合（协议、端口、用户名、重定向、窗口模式、色深、SSH 窗口尺寸）。每个生效参数都会
同时显示**当前值**与**来源**。

### 会话工作台
- 多会话并排，可切换分屏布局，单个会话可最大化。
- 工具栏内置「打开资产」输入框：输入名称或主机后回车，或直接从列表选择。
- 支持把 SSH 会话作为独立窗口打开，不占用工作台。

### SFTP 文件传输
- 每个资产一个完整的远端文件浏览器：目录、大小、权限、修改时间。
- 上传与下载文件或整个目录，支持断点续传（`reput` / `reget`）。
- 新建文件夹、删除文件或空目录，支持把文件拖拽到当前目录上传。
- 入口有两个：会话工具条按钮与 SSH 终端右键菜单。

### SSH 终端右键菜单
就在光标处提供复制、粘贴、全选与「文件传输」。远端程序接管鼠标时（如 vim、tmux），右键照常
交给远端程序处理。

### 凭据
- 密码与密钥口令**只**保存在 macOS 钥匙串中，绝不写入数据文件。
- 删除资产或取消勾选「记住密码」时，会同步清除钥匙串条目。

### 导入、导出与同步
- 支持从 CSV 或 Excel（`.xlsx`）导入，自动识别列映射并提供校验预览。
- 支持导出 CSV 或 JSON，逐字段勾选；敏感字段默认不勾选。
- 云端同步先拉取预览、勾选后再合并；只同步资产与模板，不包含任何密码。

### 可达性探测
对单个资产、选中项或全部资产做 TCP 探测，可手动触发，也可按间隔自动执行。

### 保护口令（应用锁）
- 可选的保护口令锁，支持空闲自动锁定（1～60 分钟）。
- 口令使用 **PBKDF2-SHA256** 哈希，10 万次迭代 + 128 位随机盐。
- 设置时一次性发放恢复口令（Crockford Base32，兼容 `O/0`、`I/L/1` 等混淆字符）。
- 可配置：连续输错 5 次后自动清空本地数据，或保持锁定并需要手动清空。

### 外观与帮助
- 跟随系统 / 浅色 / 深色主题；界面支持简体中文与英文。
- 应用内帮助手册：覆盖 VNC 使用说明、各协议常见疑点、数据存放位置与凭据隐私。

## 环境要求

| 项目 | 要求 |
| --- | --- |
| macOS | 14.0（Sonoma）或更高 |
| RDP 承载客户端 | Microsoft Windows App（App Store 安装） |
| VNC 承载客户端 | 系统「屏幕共享」，或 RealVNC / TigerVNC 等 |
| RDP 密码自动填充 | 为 OpenNodeDesk 开启「辅助功能」权限 |
| 从源码构建 | Xcode 16 或更高（Swift 6 工具链） |

## 安装

1. 到 [Releases](https://github.com/OpenNodeSaas/OpenNodeDesk-macos/releases) 页面下载
   `OpenNodeDesk-<版本>-macos.zip`。
2. 解压后把 `OpenNodeDesk.app` 拖入 `/Applications`。
3. 本构建未做 Apple 公证，首次启动可能被 Gatekeeper 拦截——右键点按应用并选择「打开」，或在
   「系统设置 → 隐私与安全性」中放行。

## 从源码构建

```bash
git clone https://github.com/OpenNodeSaas/OpenNodeDesk-macos.git
cd OpenNodeDesk-macos
make bundle   # release 构建 + dist/OpenNodeDesk.app
make run      # 构建、打包并启动
```

常用目标：`make check`（编译并输出诊断）、`make clean`（清理 `.build` 与 `dist`）、
`make reset`（删除 `~/Library/Application Support/RemotePilot` 中的本地数据）。

## 目录结构

```
Sources/RemotePilot/
├── App/            应用入口、全局模型、菜单与命令
├── Core/           SSH/SFTP、钥匙串、探测、导入导出、同步、客户端探测、RDP 自动填充
├── Design/         设计令牌与共享组件
├── Localization/   中文原文与英文语料表
├── Models/         资产、模板、设置与运行时模型
├── Views/          侧边栏、资产中心、工作台、会话、设置、帮助、对话框
└── main.swift      入口（同时充当 SSH_ASKPASS 辅助程序）
Resources/          Info.plist 与应用图标
docs/               设计文档与各语言 README
```

## 数据与隐私

- 资产、模板与设置保存在 `~/Library/Application Support/RemotePilot`
  （`assets.json`、`settings.json`）。
- 密码与密钥口令只写入 macOS 系统钥匙串，不会出现在导出文件或同步内容中；因此换机后需要重新输入。
- 应用完全离线可用；云端同步地址由用户自行填写，属于可选项。

## 说明与限制

- macOS 上的 Windows App 不支持在单个窗口内用标签页承载多个会话；选择「标签页」模式时会按普通
  窗口打开，多会话请使用「会话工作台」。
- 未检测到 RDP 承载客户端时，连接失败会就地说明需要安装什么、到哪里安装。
- 更名后仍刻意保留内部标识 `com.remotepilot.macos` 与数据目录 `RemotePilot`，以便升级后原有资产、
  设置与钥匙串条目继续可用。

## 文档

- [产品与交互设计](PRODUCT_UX_DESIGN.md)
- [设计增量说明](PRODUCT_UX_DESIGN_DELTA.md)
- [保护口令与空闲自动锁定](../.trae/documents/保护口令与空闲自动锁定-macOS.md)
