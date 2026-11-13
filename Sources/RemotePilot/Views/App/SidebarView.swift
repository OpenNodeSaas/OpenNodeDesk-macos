import SwiftUI

/// 左侧导航：四大常用视图 + 分组 + 模板 + 设置 + 帮助，底部常驻主题/语言/反馈
struct SidebarView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("rpp.sidebar.groupsExpanded") private var groupsExpanded = true

    /// 收起态：仅保留图标列，所有文字标签同步隐藏
    private var isCollapsed: Bool { model.settings.sidebarCollapsed }

    private var navBinding: Binding<NavSection?> {
        Binding(
            get: { model.nav },
            set: { if let new = $0 { model.nav = new } }
        )
    }

    var body: some View {
        List(selection: navBinding) {
            Section {
                row(.assets, badge: model.assets.count)
                row(.workspace, badge: model.workspaceSessions.isEmpty ? nil : model.workspaceSessions.count)
                row(.favorites, badge: model.assets.filter { $0.isFavorite }.count)
                row(.recent, badge: model.assets.filter { $0.lastConnectedAt != nil }.count)
            }

            Section {
                DisclosureGroup(isExpanded: $groupsExpanded) {
                    ForEach(model.groups, id: \.name) { group in
                        groupRow(group)
                    }
                    if model.groups.isEmpty && !isCollapsed {
                        Text(L("暂无分组")).font(.system(size: 11)).foregroundStyle(Tokens.mutedForeground)
                    }
                } label: {
                    if isCollapsed {
                        Image(systemName: "square.stack.3d.up").frame(maxWidth: .infinity)
                    } else {
                        Label(L("服务器分组"), systemImage: "square.stack.3d.up")
                    }
                }
            }

            Section {
                row(.templates, badge: model.templates.count)
                row(.settings, badge: nil)
                row(.help, badge: nil)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) { brandBar }
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    /// 品牌区：点击回首页；右侧为收起/展开入口
    private var brandBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: Tokens.gapS) {
                Button {
                    model.nav = .assets
                    model.searchText = ""
                } label: {
                    HStack(spacing: Tokens.gapM) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tokens.accent)
                        if !isCollapsed {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("RemotePilot").font(.system(size: 13, weight: .semibold))
                                Text("RemoteOps v2.0").font(.system(size: 10)).foregroundStyle(Tokens.subtleForeground)
                            }
                        }
                        if !isCollapsed { Spacer(minLength: 0) }
                    }
                    .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L("返回资产中心"))

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        model.settings.sidebarCollapsed.toggle()
                    }
                    model.saveSettings()
                } label: {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .help(isCollapsed ? L("展开导航") : L("收起导航"))
            }
            .padding(.horizontal, isCollapsed ? Tokens.gapS : Tokens.gapL)
            .padding(.vertical, Tokens.gapM)
            Divider()
        }
        .background(Tokens.sidebarBackground)
    }

    @ViewBuilder
    private func groupRow(_ group: (name: String, count: Int)) -> some View {
        if isCollapsed {
            Image(systemName: "folder")
                .frame(maxWidth: .infinity)
                .tag(NavSection.group(group.name))
                .help(group.name.isEmpty ? L("未分组") : group.name)
        } else {
            Label {
                HStack {
                    Text(group.name.isEmpty ? L("未分组") : group.name)
                    Spacer()
                    Text("\(group.count)").foregroundStyle(Tokens.mutedForeground).font(.system(size: 11))
                }
            } icon: {
                Image(systemName: "folder")
            }
            .tag(NavSection.group(group.name))
        }
    }

    @ViewBuilder
    private func row(_ section: NavSection, badge: Int?) -> some View {
        if isCollapsed {
            Image(systemName: section.symbol)
                .frame(maxWidth: .infinity)
                .tag(section)
                .help(section.title)
        } else {
            Label {
                HStack {
                    Text(section.title)
                    Spacer()
                    if let badge, badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 11))
                            .foregroundStyle(Tokens.mutedForeground)
                    }
                }
            } icon: {
                Image(systemName: section.symbol)
            }
            .tag(section)
            .help(section.title)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: Tokens.gapM) {
                Menu {
                    Picker(L("主题"), selection: themeBinding) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .id(model.settings.language)
                } label: {
                    Image(systemName: themeSymbol)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 28)
                .help(L("主题切换"))

                Menu {
                    Picker(L("语言"), selection: languageBinding) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                } label: {
                    if isCollapsed {
                        Image(systemName: "globe")
                    } else {
                        Text(model.settings.language == .zh ? "中" : "EN").font(.system(size: 12, weight: .semibold))
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: isCollapsed ? 28 : 32)
                .help(L("语言切换"))

                if !isCollapsed { Spacer() }

                Button {
                    model.showFeedbackSheet = true
                } label: {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                }
                .buttonStyle(.borderless)
                .help(L("意见反馈"))
            }
            .padding(.horizontal, isCollapsed ? Tokens.gapS : Tokens.gapL)
            .padding(.vertical, Tokens.gapM)
            .background(Tokens.sidebarBackground)
        }
    }

    private var themeBinding: Binding<ThemeMode> {
        Binding(
            get: { model.settings.theme },
            set: { model.settings.theme = $0; model.saveSettings() }
        )
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { model.settings.language },
            set: { model.settings.language = $0; model.saveSettings() }
        )
    }

    private var themeSymbol: String {
        switch model.settings.theme {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}
