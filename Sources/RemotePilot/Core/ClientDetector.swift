import Foundation
import AppKit

/// 承载客户端：实际渲染远程画面的外部程序
struct CarrierClient: Identifiable, Hashable {
    enum Kind: Hashable {
        /// .app 包，通过 NSWorkspace 打开
        case application
        /// 命令行可执行文件，通过 Process 启动
        case binary
        /// 系统 URL Scheme（如 macOS 屏幕共享的 vnc://）
        case urlScheme(String)
    }

    var id: String
    var name: String
    var path: String
    var kind: Kind
    var isSystem: Bool = false

    var locationDescription: String {
        switch kind {
        case .urlScheme: return L("系统内置")
        case .application, .binary: return path
        }
    }
}

/// 能力探测而非硬编码：先探测本机可用的承载客户端
@MainActor
enum ClientDetector {
    private static let fileManager = FileManager.default

    static func isValid(path: String) -> Bool {
        guard !path.isEmpty else { return false }
        return fileManager.fileExists(atPath: path)
    }

    /// RDP：默认 Microsoft Windows App；FreeRDP 仅作为可选手动指定项
    static func rdpCandidates() -> [CarrierClient] {
        var result: [CarrierClient] = []
        for bundleID in ["com.microsoft.rdc.macos"] {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                result.append(CarrierClient(id: bundleID, name: url.deletingPathExtension().lastPathComponent, path: url.path, kind: .application))
            }
        }
        for path in ["/Applications/Windows App.app", "/Applications/Microsoft Remote Desktop.app"] {
            guard isValid(path: path), !result.contains(where: { $0.path == path }) else { continue }
            result.append(CarrierClient(id: path, name: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent, path: path, kind: .application))
        }
        // 命令行 FreeRDP：需要免密时可手动指定，默认不抢占 Windows App
        for path in ["/opt/homebrew/bin/sdl-freerdp", "/usr/local/bin/sdl-freerdp"] {
            guard isValid(path: path) else { continue }
            result.append(CarrierClient(id: path, name: "FreeRDP", path: path, kind: .binary))
            break
        }
        return result
    }

    /// VNC：优先系统屏幕共享，其次外装客户端
    static func vncCandidates() -> [CarrierClient] {
        var result: [CarrierClient] = []
        let screenSharing = "/System/Library/CoreServices/Applications/Screen Sharing.app"
        if isValid(path: screenSharing) {
            result.append(CarrierClient(id: "system.screensharing", name: L("系统屏幕共享"), path: screenSharing, kind: .urlScheme("vnc"), isSystem: true))
        }
        for bundleID in ["com.realvnc.vncviewer", "com.tigervnc.vncviewer", "org.remmina.Remmina", "com.glyptodon.Cozmo"] {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
               !result.contains(where: { $0.path == url.path }) {
                result.append(CarrierClient(id: bundleID, name: url.deletingPathExtension().lastPathComponent, path: url.path, kind: .application))
            }
        }
        for path in ["/Applications/VNC Viewer.app", "/Applications/TigerVNC.app", "/Applications/Remmina.app",
                     "/opt/homebrew/bin/vncviewer", "/usr/local/bin/vncviewer"] {
            guard isValid(path: path), !result.contains(where: { $0.path == path }) else { continue }
            let isApp = path.hasSuffix(".app")
            result.append(CarrierClient(id: path, name: URL(fileURLWithPath: path).lastPathComponent, path: path, kind: isApp ? .application : .binary))
        }
        return result
    }

    static func candidates(for proto: RemoteProtocol) -> [CarrierClient] {
        switch proto {
        case .rdp: return rdpCandidates()
        case .vnc: return vncCandidates()
        case .ssh: return []
        }
    }

    /// 解析当前生效的承载客户端：用户指定优先，其次自动探测
    static func resolve(_ proto: RemoteProtocol, preferredPath: String) -> CarrierClient? {
        let candidates = candidates(for: proto)
        if !preferredPath.isEmpty {
            if let match = candidates.first(where: { $0.path == preferredPath }) { return match }
            if isValid(path: preferredPath) {
                let isApp = preferredPath.hasSuffix(".app")
                return CarrierClient(id: preferredPath, name: URL(fileURLWithPath: preferredPath).deletingPathExtension().lastPathComponent, path: preferredPath, kind: isApp ? .application : .binary)
            }
            return nil
        }
        return candidates.first
    }

    static func defaultPath(for proto: RemoteProtocol) -> String {
        candidates(for: proto).first?.path ?? ""
    }
}
