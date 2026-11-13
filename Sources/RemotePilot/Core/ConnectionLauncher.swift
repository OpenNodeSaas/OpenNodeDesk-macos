import Foundation
import AppKit

/// 一次连接实际使用的参数（由资产 + 模板 + 覆盖 + 全局设置解析得到）
struct LaunchPlan {
    var windowMode: WindowMode
    var colorDepth: ColorDepth
    var redirects: RedirectionOptions
    var width: Int
    var height: Int
    var username: String
    var password: String?
}

enum LaunchError: LocalizedError {
    case carrierMissing(RemoteProtocol)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .carrierMissing(let proto):
            return proto == .rdp
                ? L("未检测到 RDP 承载客户端")
                : L("未检测到 VNC 承载客户端")
        case .launchFailed(let reason):
            return L("启动客户端失败：{v}").replacingOccurrences(of: "{v}", with: reason)
        }
    }

    /// 就地诊断内容：原因 + 检查建议
    var diagnostic: Diagnostic {
        switch self {
        case .carrierMissing(let proto):
            if proto == .rdp {
                return Diagnostic(
                    cause: L("本机未检测到 Microsoft Windows App，无法承载 RDP 画面。"),
                    suggestions: [
                        L("在 App Store 安装 Microsoft Windows App（原 Microsoft Remote Desktop）"),
                        L("安装后回到「帮助手册」重新探测客户端路径"),
                        L("由该平台最合适的客户端承担远程画面，本产品不替代它")
                    ]
                )
            }
            return Diagnostic(
                cause: L("本机未检测到可用的 VNC 承载客户端。"),
                suggestions: [
                    L("使用系统「屏幕共享」即可连接标准 VNC 服务，无需额外安装"),
                    L("或安装 RealVNC Viewer / TigerVNC 等外装客户端"),
                    L("在「帮助手册 → 客户端配置」中指定客户端路径后重试")
                ]
            )
        case .launchFailed(let reason):
            return Diagnostic(
                cause: L("承载客户端启动失败：{v}").replacingOccurrences(of: "{v}", with: reason),
                suggestions: [
                    L("确认客户端仍可正常手动打开"),
                    L("在「帮助手册 → 客户端配置」中重新指定可执行文件路径"),
                    L("检查配置的启动参数模板是否仍适用于当前客户端版本")
                ]
            )
        }
    }
}

/// 建连编排：RDP 写临时 .rdp 交给 Windows App；VNC 走系统屏幕共享或外装客户端；SSH 由应用内终端承担
@MainActor
enum ConnectionLauncher {

    // MARK: RDP

    static func rdpFileURL(for asset: Asset) -> URL {
        let safeName = asset.displayName.replacingOccurrences(of: "/", with: "_")
        return Storage.cacheDirectory.appendingPathComponent("\(safeName)-\(asset.id.uuidString.prefix(8)).rdp")
    }

    static func rdpContent(asset: Asset, plan: LaunchPlan, extraArgs: String) -> String {
        var lines: [String] = []
        lines.append("full address:s:\(asset.host):\(asset.port)")
        if !plan.username.isEmpty { lines.append("username:s:\(plan.username)") }
        lines.append("prompt for credentials:i:0")
        lines.append("authentication level:i:0")

        let (mode, width, height) = screenSettings(plan)
        lines.append("screen mode id:i:\(mode)")
        lines.append("desktopwidth:i:\(width)")
        lines.append("desktopheight:i:\(height)")
        lines.append("smart sizing:i:1")
        lines.append("use multimon:i:0")
        lines.append("session bpp:i:\(plan.colorDepth.rawValue)")
        lines.append("redirectclipboard:i:\(plan.redirects.clipboard ? 1 : 0)")
        lines.append("audiomode:i:\(plan.redirects.audio ? 1 : 2)")
        if plan.redirects.drives { lines.append("drivestoredirect:s:*") }

        let extra = extraArgs.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        lines.append(contentsOf: extra)

        return lines.joined(separator: "\r\n") + "\r\n"
    }

    private static func screenSettings(_ plan: LaunchPlan) -> (Int, Int, Int) {
        let width = plan.width > 0 ? plan.width : 1920
        let height = plan.height > 0 ? plan.height : 1080
        switch plan.windowMode {
        case .fullscreen:
            return (2, width, height)
        case .smallWindow:
            return (1, min(width, 1280), min(height, 720))
        case .windowed, .tabbed:
            // 本平台差异：macOS 的 Windows App 不支持在单个窗口内开标签页，按普通窗口打开
            return (1, width, height)
        }
    }

    static func launchRDP(asset: Asset, plan: LaunchPlan, settings: AppSettings) async throws {
        guard let carrier = ClientDetector.resolve(.rdp, preferredPath: settings.rdpClientPath) else {
            throw LaunchError.carrierMissing(.rdp)
        }
        let file = rdpFileURL(for: asset)
        let content = rdpContent(asset: asset, plan: plan, extraArgs: settings.rdpClientArgs)
        do {
            try content.write(to: file, atomically: true, encoding: .utf8)
        } catch {
            throw LaunchError.launchFailed(error.localizedDescription)
        }

        switch carrier.kind {
        case .application:
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            do {
                _ = try await NSWorkspace.shared.open([file], withApplicationAt: URL(fileURLWithPath: carrier.path), configuration: configuration)
            } catch {
                throw LaunchError.launchFailed(error.localizedDescription)
            }
        case .binary, .urlScheme:
            // 非 .app 客户端：直接把 .rdp 文件交给系统默认处理程序
            if !NSWorkspace.shared.open(file) {
                throw LaunchError.launchFailed(L("系统未注册 .rdp 文件的处理程序"))
            }
        }
    }

    // MARK: VNC

    static func vncURL(for asset: Asset) -> URL {
        let user = asset.username.isEmpty ? "" : "\(asset.username)@"
        return URL(string: "vnc://\(user)\(asset.host):\(asset.port)") ?? URL(string: "vnc://\(asset.host)")!
    }

    static func launchVNC(asset: Asset, plan: LaunchPlan, settings: AppSettings) async throws {
        guard let carrier = ClientDetector.resolve(.vnc, preferredPath: settings.vncClientPath) else {
            throw LaunchError.carrierMissing(.vnc)
        }
        let display = asset.port >= 5900 ? asset.port - 5900 : asset.port
        let template = settings.vncClientArgs.isEmpty ? AppSettings.defaultVNCArgs : settings.vncClientArgs
        let args = template
            .replacingOccurrences(of: "{host}", with: asset.host)
            .replacingOccurrences(of: "{port}", with: "\(asset.port)")
            .replacingOccurrences(of: "{display}", with: "\(display)")
            .replacingOccurrences(of: "{user}", with: plan.username)
            .replacingOccurrences(of: "{password}", with: plan.password ?? "")
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        switch carrier.kind {
        case .urlScheme:
            if !NSWorkspace.shared.open(vncURL(for: asset)) {
                throw LaunchError.launchFailed(L("系统屏幕共享不可用"))
            }
        case .application:
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.arguments = args
            do {
                _ = try await NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: carrier.path), configuration: configuration)
            } catch {
                throw LaunchError.launchFailed(error.localizedDescription)
            }
        case .binary:
            let process = Process()
            process.executableURL = URL(fileURLWithPath: carrier.path)
            process.arguments = args
            do {
                try process.run()
            } catch {
                throw LaunchError.launchFailed(error.localizedDescription)
            }
        }
    }
}
