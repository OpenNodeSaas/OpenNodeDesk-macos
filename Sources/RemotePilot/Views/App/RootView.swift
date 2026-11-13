import SwiftUI

/// 应用外壳：左侧导航 + 顶部三层命令栏 + 内容区 + 右侧详情面板 + 状态栏
/// 布局规格见 PRODUCT_UX_DESIGN 4.1
struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(
                    min: model.settings.sidebarCollapsed ? 72 : 200,
                    ideal: model.settings.sidebarCollapsed ? 72 : 232,
                    max: model.settings.sidebarCollapsed ? 72 : 300
                )
        } detail: {
            VStack(spacing: 0) {
                CommandBar()
                Divider()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                StatusBar()
            }
            .background(Tokens.appBackground)
            .inspector(isPresented: $model.inspectorPresented) {
                InspectorPanel()
                    .inspectorColumnWidth(min: 280, ideal: 320, max: 440)
            }
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
