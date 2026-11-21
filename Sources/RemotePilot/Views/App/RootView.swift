import SwiftUI
import AppKit

/// 应用外壳：左侧导航 + 顶部命令栏 + 内容区 + 右侧详情面板 + 状态栏
/// 布局规格见 PRODUCT_UX_DESIGN 4.1
struct RootView: View {
    @EnvironmentObject var model: AppModel

    /// 侧边栏显隐：沉浸全屏时强制收起，退出后复原
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView()
                    .navigationSplitViewColumnWidth(
                        min: model.settings.sidebarCollapsed ? 76 : 200,
                        ideal: model.settings.sidebarCollapsed ? 76 : 232,
                        max: model.settings.sidebarCollapsed ? 76 : 300
                    )
            } detail: {
                VStack(spacing: 0) {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    StatusBar()
                }
                .background(Tokens.appBackground)
                // 沉浸全屏时内容顶到窗口最上沿：安全区由窗口注入到分栏容器内部，
                // 只在外层 ZStack 上 ignoresSafeArea 传不进来，必须挂在分栏内容自身上
                .ignoresSafeArea(.container, edges: model.immersiveFullScreen ? .top : [])
                // 命令栏挂在原生工具栏上：与红绿灯同一行，且点击事件由 AppKit 托管，不会被窗口拖拽区拦截
                .toolbar { commandToolbar }
                .inspector(isPresented: $model.inspectorPresented) {
                    InspectorPanel()
                        .inspectorColumnWidth(min: 280, ideal: 320, max: 440)
                }
            }
            // 锁定态：底层完全不可交互，避免通过覆盖层缝隙或键盘操作绕过
            .allowsHitTesting(!model.isLocked)
            .toolbar(model.immersiveFullScreen ? .hidden : .visible, for: .windowToolbar)

            if model.isLocked {
                LockOverlayView().environmentObject(model)
            }
        }
        .ignoresSafeArea(.container, edges: model.immersiveFullScreen ? .top : [])
        .onChange(of: model.immersiveFullScreen) { _, immersive in
            columnVisibility = immersive ? .detailOnly : .all
        }
        // 用户用 Esc 或绿灯退出全屏时，复原侧边栏、命令栏与窗口样式
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            model.endImmersiveFullScreen()
        }
        // 全屏动画结束后再收侧边栏、改窗口样式：切换过程中动这些会让 AppKit 中止全屏
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            // 绿灯 / ⌃⌘F 进来的全屏同样要压平顶部：AppKit 在全屏下不绘制工具栏，
            // 却仍按「工具栏可见」保留 40pt，顶部会留下一条空白带把工作台工具条挤下去。
            guard model.immersiveRequested || model.nav == .workspace else { return }
            columnVisibility = .detailOnly
            model.applyImmersiveChrome()
        }
        .sheet(item: $model.recoverySheet) { request in
            RecoveryCodeSheet(request: request).environmentObject(model)
        }
        .sheet(item: $model.editorRequest) { request in
            AssetEditorView(request: request).environmentObject(model)
        }
        .sheet(item: $model.planRequest) { request in
            PlanDrawer(request: request).environmentObject(model)
        }
        .sheet(item: $model.credentialRequest) { request in
            CredentialSheet(request: request).environmentObject(model)
        }
        .sheet(item: $model.templateEditRequest) { request in
            TemplateEditorView(template: request.template, isNew: request.isNew).environmentObject(model)
        }
        .sheet(isPresented: $model.showImportSheet) {
            ImportWizardView().environmentObject(model)
        }
        .sheet(isPresented: $model.showExportSheet) {
            ExportSheet().environmentObject(model)
        }
        .sheet(isPresented: $model.showSyncSheet) {
            SyncSheet().environmentObject(model)
        }
        .sheet(isPresented: $model.showFeedbackSheet) {
            FeedbackSheet().environmentObject(model)
        }
        .confirmationDialog(
            L("删除资产"),
            isPresented: deletionBinding,
            titleVisibility: .visible
        ) {
            Button(L("删除"), role: .destructive) { model.confirmDelete() }
            Button(L("取消"), role: .cancel) { model.pendingDeletion = nil }
        } message: {
            Text(deletionMessage)
        }
    }

    /// 命令栏只服务于「检索资产 / 发起连接」；模板、设置、帮助页各有页头，不再重复占位
    private var showsCommandBar: Bool {
        switch model.nav {
        case .assets, .favorites, .recent, .group, .workspace: return true
        case .templates, .settings, .help: return false
        }
    }

    // MARK: - 原生工具栏（命令栏）

    @ToolbarContentBuilder
    private var commandToolbar: some ToolbarContent {
        // 沉浸全屏时不再撤掉工具栏内容：内容增删会让 SwiftUI 在全屏动画途中重建 NSToolbar
        // （setToolbar: → 窗口重排 → 布局重入 → NSRangeException）。整条工具栏的收放改由
        // AppModel.applyImmersiveChrome 从 AppKit 侧统一处理。
        if showsCommandBar && !model.isLocked {
            ToolbarItemGroup(placement: .navigation) {
                CommandSearchField()
                CommandViewModeControl()
                Button {
                    model.editorRequest = EditorRequest(asset: Asset(), isNew: true)
                } label: {
                    Label(L("新增资产"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                CommandParametersButton()
                    .controlSize(.small)
                Button {
                    model.probeSelected()
                } label: {
                    Image(systemName: "dot.radiowaves.left.and.right")
                }
                .controlSize(.small)
                .help(L("批量探测"))
                .accessibilityLabel(L("批量探测"))

                Button {
                    model.inspectorPresented.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .controlSize(.small)
                .help(model.inspectorPresented ? L("收起右侧详情面板") : L("展开右侧详情面板"))
                .accessibilityLabel(L("资产详情"))

                CommandColumnSettingsButton()
                    .controlSize(.small)
                CommandOverflowMenu()
                    .controlSize(.small)

                Button {
                    model.requestDelete(model.selection)
                } label: {
                    Label(deleteTitle, systemImage: "trash")
                }
                .controlSize(.small)
                .disabled(model.selection.isEmpty)
                .help(L("删除选中资产"))
            }
        }
    }

    private var deleteTitle: String {
        model.selection.isEmpty
            ? L("删除")
            : L("删除 {n}").replacingOccurrences(of: "{n}", with: "\(model.selection.count)")
    }

    /// 内容区路由：四大列表视图共用资产中心，模板与帮助各自成页
    @ViewBuilder
    private var content: some View {
        switch model.nav {
        case .workspace:
            WorkspaceView()
        case .templates:
            TemplateManagerView()
        case .help:
            HelpManualView()
        case .settings:
            SettingsView()
        case .assets, .favorites, .recent, .group:
            AssetBrowserView()
        }
    }

    // MARK: - 危险操作二次确认

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { model.pendingDeletion != nil },
            set: { if !$0 { model.pendingDeletion = nil } }
        )
    }

    private var deletionMessage: String {
        let count = model.pendingDeletion?.count ?? 0
        // 删除会同时清理该资产在系统钥匙串中的凭据（见 AppModel.confirmDelete），文案必须如实描述
        let cleared = L("该资产已存档的密码与密钥口令会一并从系统钥匙串中清除。")
        return L("确认删除选中的 {n} 台资产？该操作不可撤销。")
            .replacingOccurrences(of: "{n}", with: "\(count)")
            + "\n" + cleared
    }
}
