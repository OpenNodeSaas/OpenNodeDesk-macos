import SwiftUI
import AppKit

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

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(asset.displayName) (\(asset.host))"
        window.contentView = hosting
        window.setContentSize(size)
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

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let assetID = handles.first(where: { $0.value.window === window })?.key,
              let handle = handles.removeValue(forKey: assetID) else { return }
        TerminalRegistry.shared.terminate(sessionID: handle.sessionID)
        handle.model?.removeDetachedSession(assetID: assetID)
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
    }
}
