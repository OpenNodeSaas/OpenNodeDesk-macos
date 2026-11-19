import SwiftUI
import AppKit
import Darwin

// MARK: - 单实例运行

/// 通过文件锁保证同一时间只有一个实例在运行：第二个实例立即退出并激活已有窗口
enum InstanceLock {
    /// 锁随进程存活而保持，进程退出时由系统自动释放
    private static var descriptor: Int32 = -1

    static func acquire() -> Bool {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RemotePilot", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("instance.lock").path
        let fd = open(path, O_CREAT | O_RDWR, 0o644)
        // 锁文件不可用时不做拦截，避免因权限问题无法启动
        guard fd >= 0 else { return true }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            return false
        }
        descriptor = fd
        return true
    }

    /// 已有实例在运行则将其置前
    static func activateExistingInstance() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }?
            .activate()
    }
}

// MARK: - SSH 询问口令回执

/// ssh 以本二进制作为 SSH_ASKPASS 程序时的应答实现。
/// 凭据来自系统钥匙串；找不到凭据时以非零退出码让 ssh 自行报错。
enum AskPass {
    static func run(assetID: String) -> Never {
        guard let uuid = UUID(uuidString: assetID) else { exit(1) }
        let prompt = (CommandLine.arguments.dropFirst().first ?? "").lowercased()
        let wantsPassphrase = prompt.contains("passphrase") || prompt.contains("口令")
        let secret = (wantsPassphrase ? Keychain.secret(account: Keychain.keyPassphraseAccount(uuid)) : nil)
            ?? Keychain.secret(account: Keychain.passwordAccount(uuid))
            ?? ""
        FileHandle.standardOutput.write(Data((secret + "\n").utf8))
        exit(secret.isEmpty ? 1 : 0)
    }
}

// MARK: - 应用生命周期

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // 单实例：已有实例在运行时，本实例立即退出并把已有主窗口置前
        guard InstanceLock.acquire() else {
            InstanceLock.activateExistingInstance()
            exit(0)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        // 退出前回收内嵌终端进程，避免残留孤立的 ssh 会话
        TerminalRegistry.shared.terminateAll()
    }
}

struct RemotePilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(model.settings.theme.colorScheme)
                // 最小尺寸以「表格 15 列不横向滚动」为基准：导航 200 + 表格自然宽 1340 + 余量
                .frame(minWidth: 1560, minHeight: 740)
        }
        .defaultSize(width: 1720, height: 1000)
        // 紧凑统一工具栏：红绿灯与命令栏同一行，省掉独立标题栏高度；
        // 命令栏控件由 NSToolbarItem 托管，点击不会被窗口拖拽区拦截
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands { commands }
    }

    @CommandsBuilder
    private var commands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(L("新增资产"), action: guarded { model.editorRequest = EditorRequest(asset: Asset(), isNew: true) })
                .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button(L("保存设置"), action: guarded {
                model.saveSettings()
                model.setStatus(L("设置已保存"), kind: .success)
            })
            .keyboardShortcut("s", modifiers: .command)

            Divider()

            Button(L("导入资产"), action: guarded { model.showImportSheet = true })
                .keyboardShortcut("i", modifiers: [.command, .shift])
            Button(L("导出选中"), action: guarded { model.showExportSheet = true })
                .keyboardShortcut("e", modifiers: [.command, .shift])
            Button(L("云端同步"), action: guarded { model.showSyncSheet = true })
                .keyboardShortcut("y", modifiers: [.command, .shift])
        }

        CommandMenu(L("连接")) {
            Button(L("连接选中"), action: guarded {
                if let asset = model.selectedAssets.first { model.connect(asset) }
            })
            .keyboardShortcut("l", modifiers: [.command, .shift])

            Button(L("打开连接方案"), action: guarded {
                if let asset = model.selectedAssets.first {
                    model.planRequest = PlanRequest(asset: asset, highlightTemplate: true)
                }
            })
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Divider()

            Button(L("探测全部"), action: guarded { model.probe(model.assets) })
                .keyboardShortcut("r", modifiers: .command)
            Button(L("探测选中"), action: guarded { model.probeSelected() })
                .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            // 不占用 ⌘W（macOS 约定为关闭窗口），会话标签用 ⌥⌘W
            Button(L("关闭当前会话"), action: guarded {
                guard let id = model.focusedSessionID else { return }
                TerminalRegistry.shared.terminate(sessionID: id)
                model.closeSession(id)
            })
            .keyboardShortcut("w", modifiers: [.command, .option])
            .disabled(model.focusedSessionID == nil)

            Button(L("关闭全部会话"), action: guarded { model.closeAllSessions() })
                .disabled(model.sessions.isEmpty)
        }

        CommandMenu(L("视图")) {
            Button(L("聚焦搜索"), action: guarded { model.focusSearchTick += 1 })
                .keyboardShortcut("k", modifiers: .command)

            Divider()

            Button(L("表格视图"), action: guarded {
                model.settings.viewMode = .table
                model.nav = .assets
                model.saveSettings()
            })
            Button(L("宫格视图"), action: guarded {
                model.settings.viewMode = .grid
                model.nav = .assets
                model.saveSettings()
            })

            Divider()

            Button(L("切换详情面板"), action: guarded {
                model.inspectorPresented.toggle()
            })
            .keyboardShortcut("i", modifiers: [.command, .option])

            Button(L("帮助手册"), action: guarded { model.openHelp(.general) })
            Button(L("意见反馈"), action: guarded { model.showFeedbackSheet = true })
        }
    }

    /// 锁定态下屏蔽全部菜单动作，避免用快捷键绕过锁定覆盖层
    private func guarded(_ action: @escaping () -> Void) -> () -> Void {
        { if !model.isLocked { action() } }
    }
}
