import SwiftUI
import AppKit
import SwiftTerm

/// SSH 终端：补上右键「复制 / 粘贴 / 全选」菜单。
/// 远端程序开启鼠标上报时（如 vim / tmux），右键照常交给远端程序，不弹本地菜单。
final class SSHLocalTerminalView: LocalProcessTerminalView {
    /// 打开该会话的 SFTP 文件浏览器（由 SSHTerminalController 注入）
    var onOpenFileTransfer: (() -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        // 关闭自动校验：AppKit 会按 action 校验菜单项，自定义 action（如「文件传输」）恒被判为不可用
        menu.autoenablesItems = false

        let copyItem = NSMenuItem(title: L("复制"), action: #selector(TerminalView.copy(_:)), keyEquivalent: "")
        copyItem.target = self
        copyItem.isEnabled = !(getSelection() ?? "").isEmpty
        menu.addItem(copyItem)

        let pasteItem = NSMenuItem(title: L("粘贴"), action: #selector(TerminalView.paste(_:)), keyEquivalent: "")
        pasteItem.target = self
        pasteItem.isEnabled = !(NSPasteboard.general.string(forType: .string) ?? "").isEmpty
        menu.addItem(pasteItem)

        menu.addItem(.separator())

        let selectAllItem = NSMenuItem(title: L("全选"), action: #selector(TerminalView.selectAll(_:)), keyEquivalent: "")
        selectAllItem.target = self
        menu.addItem(selectAllItem)

        menu.addItem(.separator())

        let transferItem = NSMenuItem(title: L("文件传输…"), action: #selector(openFileTransfer), keyEquivalent: "")
        transferItem.target = self
        transferItem.isEnabled = onOpenFileTransfer != nil
        menu.addItem(transferItem)

        return menu
    }

    @objc private func openFileTransfer() {
        onOpenFileTransfer?()
    }
}

/// SSH 会话由应用内终端承担：真实 PTY + 完整终端语义
@MainActor
final class SSHTerminalController: NSObject, LocalProcessTerminalViewDelegate {
    let sessionID: UUID
    let assetID: UUID
    let host: String
    let port: Int
    let terminal: LocalProcessTerminalView

    private weak var model: AppModel?
    private var reportedConnected = false
    private var reportedFailure = false
    private var usedPassword = false

    init(session: Session, asset: Asset, model: AppModel, settings: AppSettings) {
        self.sessionID = session.id
        self.assetID = asset.id
        self.host = asset.host
        self.port = asset.port
        self.model = model

        let view = SSHLocalTerminalView(frame: NSRect(x: 0, y: 0, width: 900, height: 480))
        self.terminal = view
        super.init()

        view.processDelegate = self
        view.onOpenFileTransfer = {
            SFTPWindowManager.shared.open(asset: asset, settings: settings)
        }
        applyAppearance(settings: settings)
        start(asset: asset, settings: settings)
    }

    /// 终端外观由设置页驱动（字号 + 配色方案）
    private func applyAppearance(settings: AppSettings) {
        terminal.applyAppearance(settings)
    }

    private func start(asset: Asset, settings: AppSettings) {
        var arguments: [String] = [
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ServerAliveInterval=30",
            "-p", "\(asset.port)"
        ]
        if !asset.sshKeyPath.isEmpty {
            arguments.append(contentsOf: ["-i", asset.sshKeyPath, "-o", "IdentitiesOnly=yes"])
        }
        if !asset.jumpHost.isEmpty {
            arguments.append(contentsOf: ["-J", asset.jumpHost])
        }
        let extra = settings.sshExtraArgs.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        arguments.append(contentsOf: extra)
        arguments.append(asset.username.isEmpty ? asset.host : "\(asset.username)@\(asset.host)")

        var environment = Terminal.getEnvironmentVariables(termName: "xterm-256color", trueColor: true)
        if let askPassPath = Bundle.main.executablePath ?? CommandLine.arguments.first {
            // 认证由系统钥匙串供电：ssh 通过 SSH_ASKPASS 回调本应用二进制
            environment.append("SSH_ASKPASS=\(askPassPath)")
            environment.append("SSH_ASKPASS_REQUIRE=force")
            environment.append("REMOTEPILOT_ASKPASS=\(assetID.uuidString)")
        }
        usedPassword = model?.password(for: asset) != nil

        terminal.setProcessOutputHandler { [weak self] in
            Task { @MainActor in self?.handleFirstOutput() }
        }
        terminal.startProcess(executable: "/usr/bin/ssh", args: arguments, environment: environment, execName: nil, currentDirectory: nil)
    }

    private func handleFirstOutput() {
        guard !reportedConnected, !reportedFailure else { return }
        reportedConnected = true
        model?.markSessionConnected(sessionID)
    }

    func terminate() {
        terminal.terminate()
    }

    // MARK: LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        guard !reportedFailure else { return }
        let code = exitCode ?? -1
        Task { @MainActor in
            if code == 0 {
                model?.updateSession(sessionID) { session in
                    session.state = .disconnected
                    session.message = L("会话已结束")
                }
                return
            }
            reportedFailure = true
            let probeHost = self.host
            let probePort = self.port
            let outcome = await Task.detached { ProbeService.probe(host: probeHost, port: probePort, timeout: 3) }.value
            let diagnostic = buildDiagnostic(outcome: outcome)
            model?.markSessionFailed(sessionID, diagnostic: diagnostic, showCredentialPrompt: true)
        }
    }

    /// 失败可解释：先区分「网络不可达」与「认证失败」，再给可执行建议
    private func buildDiagnostic(outcome: ProbeService.Outcome) -> Diagnostic {
        if !outcome.reachable {
            return Diagnostic(
                cause: L("SSH 连接失败：{host}:{port} 端口不可达。")
                    .replacingOccurrences(of: "{host}", with: host)
                    .replacingOccurrences(of: "{port}", with: "\(port)"),
                suggestions: [
                    L("确认目标主机在线、SSH 服务端口（默认 22）正确"),
                    L("确认当前网络可达该主机（是否需要 VPN 或跳板机）"),
                    L("若走跳板机，请在资产中填写「跳板机」字段"),
                    L("本机防火墙或目标安全组可能屏蔽了该端口")
                ]
            )
        }
        if usedPassword {
            return Diagnostic(
                cause: L("SSH 认证失败：用户名或密码不正确（也可能是密钥口令有误）。"),
                suggestions: [
                    L("在凭据对话框中重新输入用户名与密码"),
                    L("确认该账号允许密码登录（部分服务器只允许密钥登录）"),
                    L("若使用密钥，请确认密钥路径与口令正确"),
                    L("确认跳板机链路中的账号权限可用")
                ]
            )
        }
        return Diagnostic(
            cause: L("SSH 连接失败：目标端口可达，但会话未被接受。"),
            suggestions: [
                L("补全用户名与密码/密钥后重试"),
                L("确认目标服务器的 SSH 认证方式与本机登录方式一致"),
                L("确认跳板机配置正确"),
                L("查看终端中的具体报错行以进一步定位")
            ]
        )
    }
}

/// 终端实例保活：切换布局/视图重建时复用同一会话
@MainActor
final class TerminalRegistry {
    static let shared = TerminalRegistry()

    private var controllers: [UUID: SSHTerminalController] = [:]

    func controller(for session: Session, asset: Asset, model: AppModel, settings: AppSettings) -> SSHTerminalController {
        if let existing = controllers[session.id] { return existing }
        let controller = SSHTerminalController(session: session, asset: asset, model: model, settings: settings)
        controllers[session.id] = controller
        return controller
    }

    func terminate(sessionID: UUID) {
        controllers[sessionID]?.terminate()
        controllers.removeValue(forKey: sessionID)
    }

    func terminate(assetID: UUID) {
        for (id, controller) in controllers where controller.assetID == assetID {
            controller.terminate()
            controllers.removeValue(forKey: id)
        }
    }

    func terminateAll() {
        controllers.values.forEach { $0.terminate() }
        controllers.removeAll()
    }
}

struct SSHTerminalHost: NSViewRepresentable {
    let session: Session
    let asset: Asset
    let model: AppModel
    let settings: AppSettings

    /// 记录已应用的外观，避免每次父视图刷新都重设字体触发重排
    final class Coordinator {
        var fontSize: Int?
        var scheme: SSHColorScheme?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = TerminalRegistry.shared
            .controller(for: session, asset: asset, model: model, settings: settings)
            .terminal
        context.coordinator.fontSize = settings.sshTerminalFontSize
        context.coordinator.scheme = settings.sshColorScheme
        return view
    }

    /// 设置页保存后，已打开的 SSH 终端即时跟随字号与配色变化
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        let coordinator = context.coordinator
        guard coordinator.fontSize != settings.sshTerminalFontSize
                || coordinator.scheme != settings.sshColorScheme else { return }
        coordinator.fontSize = settings.sshTerminalFontSize
        coordinator.scheme = settings.sshColorScheme
        nsView.applyAppearance(settings)
    }
}

extension LocalProcessTerminalView {
    /// 应用设置页的 SSH 终端外观：字号 + 配色方案
    func applyAppearance(_ settings: AppSettings) {
        let scheme = settings.sshColorScheme
        font = NSFont.monospacedSystemFont(ofSize: CGFloat(settings.sshTerminalFontSize), weight: .regular)
        nativeBackgroundColor = NSColor(
            srgbRed: scheme.background.r, green: scheme.background.g, blue: scheme.background.b, alpha: 1
        )
        nativeForegroundColor = NSColor(
            srgbRed: scheme.foreground.r, green: scheme.foreground.g, blue: scheme.foreground.b, alpha: 1
        )
    }
}
