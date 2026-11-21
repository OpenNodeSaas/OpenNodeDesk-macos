# OpenNodeDesk for macOS

**A local-first remote connection hub for macOS.** Keep every server, account and connection
parameter in one searchable, reusable, portable list — and get from "I need that machine" to a
live session in three steps.

**[English]** · [简体中文](docs/README.zh-CN.md) · [繁體中文](docs/README.zh-TW.md) · [日本語](docs/README.ja.md) · [한국어](docs/README.ko.md) · [Deutsch](docs/README.de.md) · [Français](docs/README.fr.md) · [Español](docs/README.es.md) · [Português](docs/README.pt.md) · [Русский](docs/README.ru.md) · [ไทย](docs/README.th.md) · [Bahasa Indonesia](docs/README.id.md) · [Tiếng Việt](docs/README.vi.md)

Current version: **v2.3.5**

---

## What it is

OpenNodeDesk is not another remote desktop client. Rendering the remote screen, peripheral
redirection and audio/video follow the most mature client on the platform — Microsoft Windows App
for RDP, the built-in Screen Sharing for VNC, and a built-in terminal for SSH. OpenNodeDesk owns
**the other 90%**: the inventory, the parameters, the credentials, the expiry reminders and the
connection history.

Design principles:

- **Three-second connect** — search, press Return, the session opens.
- **Local first, offline capable, no account** — open, search, edit and connect without a network.
- **Don't rebuild the wheel** — remote rendering belongs to the platform's best client.
- **Explainable parameters** — every effective value is labelled *custom / template / default*.
- **Explainable failures** — errors come with a cause and actionable suggestions, never a raw code.
- **Portable data** — one click to export and import; migrate machines with a single file.
- **Keyboard first** — every core action has a shortcut.

## Features

### Asset center
- Table and grid layouts; search across name, host, group, owner and notes.
- Favourites, recent connections, and collapsible groups in the sidebar.
- Per-column show/hide and reordering, plus a global list font size.
- Expiry reminders: assets expiring within 30 days (or already expired) are flagged in place.
- Duplicate detection by **host + port** on import.

### RDP / SSH / VNC
- Default ports per protocol (3389 / 22 / 5900) with free override.
- **RDP** — generates a temporary `.rdp` file for Microsoft Windows App; window mode, colour
  depth, drive/audio/clipboard redirection and resolution are all configurable. FreeRDP binaries
  are detected and launched with the stored password directly, skipping the credential prompt.
  Password auto-fill for the Windows App credential dialog uses the macOS Accessibility API.
- **VNC** — uses the built-in Screen Sharing by default; external viewers (RealVNC, TigerVNC…)
  can be configured with a launch-argument template supporting
  `{host} {port} {display} {user} {password}`.
- **SSH** — a real terminal embedded in the app (SwiftTerm), with jump host (`-J`), private key
  authentication, key passphrase support and configurable extra `ssh` arguments.

### Connection templates
Reusable parameter sets (protocol, port, username, redirection, window mode, colour depth, SSH
window size). Every resolved parameter shows its current value **and where it came from**.

### Session workspace
- Multiple sessions side by side with switchable split layouts, per-session maximise.
- An "open asset" box in the toolbar: type a name or host and press Return, or pick from the list.
- Separate SSH windows are supported when you prefer them off the workspace.

### SFTP file transfer
- Full remote file browser per asset: directories, sizes, permissions, modification times.
- Upload and download files or whole folders, with resume (`reput` / `reget`).
- Create folders, delete files or empty folders, drag and drop files into the current folder.
- Available from the session toolbar and from the SSH terminal context menu.

### SSH terminal context menu
Copy, paste, select all and "file transfer" right where you are typing. When a remote program
captures the mouse (vim, tmux), right-click is passed through to the remote program as expected.

### Credentials
- Passwords and key passphrases are stored **only** in the macOS Keychain, never in the data files.
- Deleting an asset or unchecking "remember password" removes the Keychain entry.

### Import, export and sync
- Import from CSV or Excel (`.xlsx`) with automatic column mapping and a validation preview.
- Export to CSV or JSON, with per-field selection; sensitive fields are unchecked by default.
- Cloud sync pulls a preview first and merges only what you select — assets and templates only,
  never passwords.

### Reachability probing
TCP probing of single assets, the selection or the whole inventory, on demand or on a timer.

### App lock (protection passphrase)
- Optional passphrase lock with idle auto-lock (1–60 minutes).
- Passphrase hashing with **PBKDF2-SHA256**, 100 000 iterations and a random 128-bit salt.
- A recovery code is issued once at setup (Crockford Base32, tolerant of `O/0`, `I/L/1`).
- Configurable: after 5 consecutive failures, wipe local data automatically, or stay locked and
  require a manual wipe.

### Appearance and help
- Follow System / Light / Dark theme; Simplified Chinese and English interface.
- An in-app help manual covering VNC usage, per-protocol troubleshooting, data locations and
  credential privacy.

## Requirements

| Item | Requirement |
| --- | --- |
| macOS | 14.0 (Sonoma) or later |
| RDP carrier | Microsoft Windows App (from the App Store) |
| VNC carrier | Built-in Screen Sharing, or RealVNC / TigerVNC and similar |
| RDP password auto-fill | Accessibility permission for OpenNodeDesk |
| Building from source | Xcode 16 or later (Swift 6 toolchain) |

## Install

1. Download `OpenNodeDesk-<version>-macos.zip` from the
   [Releases](https://github.com/OpenNodeSaas/OpenNodeDesk-macos/releases) page.
2. Unzip and drag `OpenNodeDesk.app` into `/Applications`.
3. The build is not notarised by Apple, so Gatekeeper may warn on first launch — right-click the
   app and choose **Open**, or allow it in *System Settings → Privacy & Security*.

## Build from source

```bash
git clone https://github.com/OpenNodeSaas/OpenNodeDesk-macos.git
cd OpenNodeDesk-macos
make bundle   # release build + dist/OpenNodeDesk.app
make run      # build, bundle and launch
```

Useful targets: `make check` (compile and show diagnostics), `make clean` (drop `.build` and
`dist`), `make reset` (remove local data from `~/Library/Application Support/RemotePilot`).

## Project layout

```
Sources/RemotePilot/
├── App/            App entry point, global model, commands and menus
├── Core/           SSH/SFTP, Keychain, probing, import/export, sync, carrier detection, RDP auto-fill
├── Design/         Design tokens and shared components
├── Localization/   Chinese source strings + English string table
├── Models/         Asset, template, settings and runtime models
├── Views/          Sidebar, asset center, workspace, sessions, settings, help, dialogs
└── main.swift      Entry point (also serves as the SSH_ASKPASS helper)
Resources/          Info.plist and app icon
docs/              Design documents and translated READMEs
```

## Data and privacy

- Assets, templates and settings live in `~/Library/Application Support/RemotePilot`
  (`assets.json`, `settings.json`).
- Passwords and key passphrases are written only to the macOS Keychain; they are never part of an
  export or a sync payload. Moving to another machine therefore requires re-entering them.
- The app works fully offline; the cloud sync endpoint is optional and user-supplied.

## Notes and limitations

- macOS's Windows App cannot host multiple sessions as tabs in one window; choosing the tabbed
  window mode opens a normal window instead. Use the session workspace for multiple sessions.
- If no RDP carrier is installed, connection attempts explain what to install and where.
- The internal bundle identifier `com.remotepilot.macos` and the data directory
  `RemotePilot` are intentionally unchanged since the rename, so existing assets, settings and
  Keychain entries keep working after upgrade.

## Documentation

- [Product & UX design](docs/PRODUCT_UX_DESIGN.md)
- [Design delta](docs/PRODUCT_UX_DESIGN_DELTA.md)
- [Passphrase lock and idle auto-lock](.trae/documents/保护口令与空闲自动锁定-macOS.md)
