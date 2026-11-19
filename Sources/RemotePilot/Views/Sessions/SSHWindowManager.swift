import SwiftUI
import AppKit
import SwiftTerm

/// SSH 独立窗口：不占用工作台标签与分屏，关闭窗口即断开会话
@MainActor
final class SSHWindowManager: NSObject, NSWindowDelegate {
    static let shared = SSHWindowManager()

    private final class Handle {
        let window: NSWindow
        let sessionID: UUID
        let assetID: UUID
        weak var model: AppModel?

        init(window: NSWindow, sessionID: UUID, assetID: UUID, model: AppModel) {
            self.window = window
            self.sessionID = sessionID
            self.assetID = assetID
            self.model = model
        }
    }

    private var handles: [UUID: Handle] = [:]

    func open(session: Session, asset: Asset, model: AppModel, width: Int, height: Int) {
        // 同一资产已有独立窗口则置前复用
        if let existing = handles[asset.id] {
            existing.window.makeKeyAndOrderFront(nil)
            return
        }

        let size = NSSize(
            width: max(320, min(width, 7680)),
            height: max(240, min(height, 4320))
        )
        let content = SSHTerminalWindowContent(session: session, asset: asset, model: model)
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(origin: .zero, size: size)
        // 最大化/缩放时随窗口一同伸缩，避免内容停留在旧尺寸留下空白
        hosting.autoresizingMask = [.width, .height]

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(asset.displayName) (\(asset.host))"
        window.contentView = hosting
        window.setContentSize(size)
        // 用终端底色作窗口背景：最大化/最小化切换的过渡帧不再闪出白底
        window.backgroundColor = Self.terminalBackground(for: model.settings)
        window.isOpaque = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        handles[asset.id] = Handle(window: window, sessionID: session.id, assetID: asset.id, model: model)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow(forAsset assetID: UUID) {
        guard let handle = handles.removeValue(forKey: assetID) else { return }
        handle.window.delegate = nil
        handle.window.close()
    }

    /// 关闭全部独立窗口（锁定主窗口时调用，避免锁定后仍能通过子窗口操作）
    func closeAll() {
        for (_, handle) in handles {
            handle.window.delegate = nil
            handle.window.close()
        }
        handles.removeAll()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let assetID = handles.first(where: { $0.value.window === window })?.key,
              let handle = handles.removeValue(forKey: assetID) else { return }
        TerminalRegistry.shared.terminate(sessionID: handle.sessionID)
        handle.model?.removeDetachedSession(assetID: assetID)
    }

    // MARK: - 窗口可见性变化后强制终端重绘
    //
    // 终端帧由 SwiftTerm 自己的渲染循环驱动，最小化/恢复时缓存会失效，
    // 仅靠 SwiftUI 不会触发重绘，导致窗口恢复后停留在空白底。

    func windowDidDeminiaturize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        // AppKit 恢复视图晚于本回调，延后一帧再重绘
        Task { @MainActor in self.refreshTerminals(in: window) }
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        refreshTerminals(in: window)
    }

    private func refreshTerminals(in window: NSWindow) {
        guard let root = window.contentView else { return }
        for case let terminal as LocalProcessTerminalView in Self.descendants(of: root) {
            terminal.requestRedraw()
            terminal.needsDisplay = true
        }
    }

    private static func descendants(of view: NSView) -> [NSView] {
        var result: [NSView] = []
        for sub in view.subviews {
            result.append(sub)
            result.append(contentsOf: descendants(of: sub))
        }
        return result
    }

    static func terminalBackground(for settings: AppSettings) -> NSColor {
        let bg = settings.sshColorScheme.background
        return NSColor(srgbRed: bg.r, green: bg.g, blue: bg.b, alpha: 1)
    }
}

/// 独立窗口内容：仅承载终端，会话状态与诊断仍由主窗口底部状态栏统一呈现
private struct SSHTerminalWindowContent: View {
    let session: Session
    let asset: Asset
    @ObservedObject var model: AppModel

    var body: some View {
        // 直接读取 model.settings，设置页保存后独立窗口的终端外观即时跟随
        SSHTerminalHost(session: session, asset: asset, model: model, settings: model.settings)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Color(
                    .sRGB,
                    red: model.settings.sshColorScheme.background.r,
                    green: model.settings.sshColorScheme.background.g,
                    blue: model.settings.sshColorScheme.background.b,
                    opacity: 1
                )
            )
    }
}
