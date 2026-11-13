import SwiftUI
import AppKit

/// 会话工作台：标签页栏 + 工具栏 + 分屏单元格（规格见 PRODUCT_UX_DESIGN 4.6）
struct WorkspaceView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceTabBar()
            Divider()
            WorkspaceToolbar()
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        if model.workspaceSessions.isEmpty {
            EmptyStateView(
                symbol: "rectangle.3.group",
                title: L("暂无进行中的会话"),
                message: L("在资产中心双击任意机器即可发起连接，会话会出现在这里并支持并排分屏。"),
                actionTitle: L("去资产中心"),
                action: { model.nav = .assets }
            )
        } else if let maximized = model.maximizedSessionID, let session = model.session(id: maximized) {
            SessionCell(session: session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            grid
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 1), count: model.layout.columns)
    }

    private var grid: some View {
        GeometryReader { geo in
            let capacity = model.layout.capacity
            let rows = model.layout.rows
            let shown = Array(model.workspaceSessions.prefix(capacity))
            let spacing: CGFloat = 1
            let cellHeight = max(0, (geo.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows))
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(shown) { session in
                    SessionCell(session: session)
                        .frame(height: cellHeight)
                }
                ForEach(0..<max(0, capacity - shown.count), id: \.self) { _ in
                    Rectangle()
                        .fill(Tokens.appBackground)
                        .frame(height: cellHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Tokens.border)
    }
}

// MARK: - 标签页栏

private struct WorkspaceTabBar: View {
    @EnvironmentObject var model: AppModel
    @State private var confirmCloseAll = false

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(model.workspaceSessions) { session in
                        tab(session)
                    }
                }
            }
            Divider().frame(height: 34)
            Button(L("全部关闭")) { confirmCloseAll = true }
                .buttonStyle(.borderless)
                .disabled(model.workspaceSessions.isEmpty)
                .padding(.horizontal, Tokens.gapL)
                .help(L("关闭全部会话"))
        }
        .frame(height: 34)
        .background(Tokens.surfaceBackground)
        .confirmationDialog(L("关闭全部会话？"), isPresented: $confirmCloseAll, titleVisibility: .visible) {
            Button(L("全部关闭"), role: .destructive) { model.closeAllSessions() }
            Button(L("取消"), role: .cancel) {}
        } message: {
            Text(L("将结束当前所有会话，且不可撤销。"))
        }
    }

    private func tab(_ session: Session) -> some View {
        let isActive = model.focusedSessionID == session.id
        return HStack(spacing: Tokens.gapS) {
            SessionStateDot(state: session.state)
            Text(session.name)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.middle)
            Button { TerminateAndClose(session.id, model: model) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Tokens.mutedForeground)
            }
            .buttonStyle(.borderless)
            .help(L("关闭本会话"))
            .accessibilityLabel(L("关闭本会话"))
        }
        .padding(.horizontal, Tokens.gapL)
        .frame(maxHeight: .infinity)
        .background(isActive ? Tokens.selectedRow : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isActive ? Tokens.accent : Color.clear)
                .frame(height: 2)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.focusedSessionID = session.id }
    }
}

// MARK: - 工具栏

private struct WorkspaceToolbar: View {
    @EnvironmentObject var model: AppModel

    private var focusedSession: Session? {
        guard let id = model.focusedSessionID else { return nil }
        return model.session(id: id)
    }

    var body: some View {
        HStack(spacing: Tokens.gapL) {
            layoutSwitcher
            Divider().frame(height: 18)
            Button(L("适应窗口")) { fitToWindow() }
                .buttonStyle(.borderless)
                .disabled(model.workspaceSessions.isEmpty)
                .help(L("自动选择能容纳当前会话数的最小布局"))
            Button(L("全屏")) { NSApp.keyWindow?.toggleFullScreen(nil) }
                .buttonStyle(.borderless)
                .help(L("切换窗口全屏"))
            Button(L("连接配置")) { openPlan() }
                .buttonStyle(.borderless)
                .disabled(focusedSession == nil)
                .help(L("打开当前会话的连接方案"))
            Spacer(minLength: Tokens.gapM)
            Button(L("断开当前")) { disconnectCurrent() }
                .buttonStyle(.borderless)
                .foregroundStyle(Tokens.danger)
                .disabled(focusedSession == nil)
                .help(L("断开并关闭当前聚焦的会话"))
        }
        .padding(.horizontal, Tokens.gapL)
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .background(Tokens.surfaceBackground)
    }

    private var layoutSwitcher: some View {
        HStack(spacing: Tokens.gapXS) {
            ForEach(WorkspaceLayout.allCases) { layout in
                Button { model.layout = layout } label: {
                    Image(systemName: layout.symbol)
                        .font(.system(size: 12))
                        .frame(width: 28, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous)
                                .fill(model.layout == layout ? Tokens.selectedRow : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous)
                                .stroke(model.layout == layout ? Tokens.accent : Tokens.softBorder, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(layout.title)
            }
        }
    }

    private func fitToWindow() {
        let count = model.workspaceSessions.count
        let target: WorkspaceLayout
        switch count {
        case ...1: target = .single
        case 2: target = .row1x2
        case 3...4: target = .grid2x2
        case 5...6: target = .grid2x3
        default: target = .grid3x3
        }
        model.layout = target
        model.maximizedSessionID = nil
    }

    private func openPlan() {
        guard let session = focusedSession, let asset = model.asset(id: session.assetID) else { return }
        model.planRequest = PlanRequest(asset: asset, highlightTemplate: false)
    }

    private func disconnectCurrent() {
        guard let session = focusedSession else { return }
        TerminalRegistry.shared.terminate(sessionID: session.id)
        model.closeSession(session.id)
    }
}

// MARK: - 单元格

private struct SessionCell: View {
    let session: Session
    @EnvironmentObject var model: AppModel

    private var isFocused: Bool { model.focusedSessionID == session.id }
    private var isMaximized: Bool { model.maximizedSessionID == session.id }
    private var carrierName: String {
        if case .externalClient(let name) = session.carrier { return name }
        return L("应用内终端")
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            cellBody
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.surfaceBackground)
        .overlay(
            Rectangle()
                .strokeBorder(isFocused ? Tokens.accent : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture { model.focusedSessionID = session.id }
    }

    private var header: some View {
        HStack(spacing: Tokens.gapM) {
            ProtocolBadge(proto: session.proto)
            SessionStateDot(state: session.state)
            Text(session.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Text("(\(session.address))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Tokens.mutedForeground)
                .lineLimit(1)
            Spacer(minLength: Tokens.gapS)
            Button { toggleMaximize() } label: {
                Image(systemName: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help(isMaximized ? L("还原") : L("最大化"))
            .accessibilityLabel(isMaximized ? L("还原") : L("最大化"))
            Button { TerminateAndClose(session.id, model: model) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help(L("关闭本会话"))
            .accessibilityLabel(L("关闭本会话"))
        }
        .padding(.horizontal, Tokens.gapM)
        .frame(height: 30)
        .background(Tokens.surfaceBackground)
    }

    private func toggleMaximize() {
        model.maximizedSessionID = isMaximized ? nil : session.id
        model.focusedSessionID = session.id
    }

    @ViewBuilder
    private var cellBody: some View {
        switch session.proto {
        case .ssh:
            sshContent
        case .rdp, .vnc:
            externalContent
        }
    }

    // SSH：内嵌真实终端；失败时就地诊断卡置于终端下方
    private var sshContent: some View {
        VStack(spacing: 0) {
            if let asset = model.asset(id: session.assetID) {
                SSHTerminalHost(session: session, asset: asset, model: model, settings: model.settings)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let diagnostic = session.diagnostic {
                DiagnosticCard(
                    diagnostic: diagnostic,
                    onRetry: { if let asset = model.asset(id: session.assetID) { model.retry(asset: asset) } },
                    onOpenHelp: { model.openHelp(HelpSection.forProtocol(session.proto)) }
                )
                .frame(maxWidth: 420)
                .padding(Tokens.gapM)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // RDP / VNC：连接信息占位页 + 打开承载客户端
    private var externalContent: some View {
        VStack(spacing: Tokens.gapL) {
            Spacer(minLength: Tokens.gapL)
            infoRow(title: L("目标地址"), value: session.address)
            infoRow(title: L("承载客户端"), value: carrierName)
            if let asset = model.asset(id: session.assetID) {
                Button(L("打开窗口")) { model.launchExternal(asset: asset, sessionID: session.id) }
                    .buttonStyle(.borderedProminent)
            }
            if session.state == .failed, let diagnostic = session.diagnostic {
                DiagnosticCard(
                    diagnostic: diagnostic,
                    onRetry: { if let asset = model.asset(id: session.assetID) { model.retry(asset: asset) } },
                    onOpenHelp: { model.openHelp(HelpSection.forProtocol(session.proto)) }
                )
                .frame(maxWidth: 420)
            }
            if let message = session.message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.mutedForeground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            Spacer(minLength: Tokens.gapL)
        }
        .padding(Tokens.gapL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(spacing: Tokens.gapS) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Tokens.mutedForeground)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .textSelection(.enabled)
        }
    }
}

// MARK: - 关闭会话（终止终端 + 移除会话）

@MainActor
private func TerminateAndClose(_ id: UUID, model: AppModel) {
    TerminalRegistry.shared.terminate(sessionID: id)
    model.closeSession(id)
}
