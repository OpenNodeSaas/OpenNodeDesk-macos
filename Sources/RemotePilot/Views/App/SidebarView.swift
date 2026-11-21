import SwiftUI

/// 左侧导航：自绘 VStack（弃用 List，避免收起态下 List 的内置行高/分隔线/箭头占位导致布局异常）
///
/// 结构：品牌区 | 导航区（ScrollView）| 底部工具条
/// 收起态：仅图标列，行高统一 32px，底部工具条收敛为「收起按钮 + 溢出菜单」
struct SidebarView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("rpp.sidebar.groupsExpanded") private var groupsExpanded = true

    /// 收起态：仅保留图标列，所有文字标签同步隐藏
    private var isCollapsed: Bool { model.settings.sidebarCollapsed }

    var body: some View {
        VStack(spacing: 0) {
            brandBar
            Divider()
            ScrollView {
                VStack(spacing: Tokens.gapXS) {
                    navItem(.assets, badge: model.assets.count)
                    navItem(.workspace, badge: model.workspaceSessions.isEmpty ? nil : model.workspaceSessions.count)
                    navItem(.favorites, badge: model.assets.filter { $0.isFavorite }.count)
                    navItem(.recent, badge: model.assets.filter { $0.lastConnectedAt != nil }.count)
                    groupsSection
                    navItem(.templates, badge: model.templates.count)
                    navItem(.settings, badge: nil)
                    navItem(.help, badge: nil)
                }
                .padding(Tokens.gapS)
            }
            Divider()
            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.sidebarBackground)
    }

    // MARK: - 品牌区

    private var brandBar: some View {
        Button {
            model.nav = .assets
            model.searchText = ""
        } label: {
            HStack(spacing: Tokens.gapS) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.accent)
                if !isCollapsed {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("OpenNodeDesk").font(.system(size: 13, weight: .semibold))
                        Text(L("macOS 版")).font(.system(size: 11)).foregroundStyle(Tokens.subtleForeground)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, isCollapsed ? Tokens.gapS : Tokens.gapL)
        .padding(.vertical, Tokens.gapM)
        .help(L("返回资产中心"))
    }

    // MARK: - 导航项

    @ViewBuilder
    private func navItem(_ section: NavSection, badge: Int?) -> some View {
        let isActive = model.nav == section
        Button {
            model.nav = section
        } label: {
            HStack(spacing: Tokens.gapS) {
                Image(systemName: section.symbol)
                    .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                    .frame(width: 18, height: 18)
                if !isCollapsed {
                    Text(section.title)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let badge, badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 11))
                            .foregroundStyle(Tokens.mutedForeground)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? 0 : Tokens.gapS)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous)
                    .fill(isActive ? Tokens.selectedRow : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(section.title)
    }

    // MARK: - 分组区（可展开/收起）

    private var groupsSection: some View {
        VStack(spacing: Tokens.gapXS) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { groupsExpanded.toggle() }
            } label: {
                HStack(spacing: Tokens.gapS) {
                    if !isCollapsed {
                        Image(systemName: groupsExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Tokens.mutedForeground)
                            .frame(width: 12)
                    }
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 14))
                        .frame(width: 18, height: 18)
                    if !isCollapsed {
                        Text(L("服务器分组")).font(.system(size: 13))
                        Spacer(minLength: 0)
                        Text("\(model.groups.count)")
                            .font(.system(size: 11))
                            .foregroundStyle(Tokens.mutedForeground)
                    }
                }
                .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
                .padding(.horizontal, isCollapsed ? 0 : Tokens.gapS)
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("服务器分组"))

            if groupsExpanded {
                if model.groups.isEmpty {
                    if !isCollapsed {
                        Text(L("暂无分组"))
                            .font(.system(size: 11))
                            .foregroundStyle(Tokens.mutedForeground)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, Tokens.gapL + 18)
                            .padding(.vertical, Tokens.gapXS)
                    }
                } else {
                    ForEach(model.groups, id: \.name) { group in
                        navItem(.group(group.name), badge: group.count)
                            .padding(.leading, isCollapsed ? 0 : Tokens.gapM)
                    }
                }
            }
        }
    }

    // MARK: - 底部工具条

    private var bottomBar: some View {
        HStack(spacing: Tokens.gapS) {
            collapseButton

            if isCollapsed {
                // 收起态：主题/语言/反馈收敛到一个溢出菜单，避免 4 个图标超出 72px 宽度
                Menu {
                    themePicker
                    languagePicker
                    Divider()
                    Button(L("意见反馈")) { model.showFeedbackSheet = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 28, height: 28)
                .help(L("更多"))
                Spacer()
            } else {
                Menu { themePicker } label: { Image(systemName: themeSymbol) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden)
                    .frame(width: 28, height: 28)
                    .help(L("主题切换"))

                Menu { languagePicker } label: {
                    Text(model.settings.language.shortLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden)
                .help(L("语言切换"))

                Spacer()

                Button { model.showFeedbackSheet = true } label: {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                }
                .buttonStyle(.borderless)
                .frame(width: 28, height: 28)
                .help(L("意见反馈"))
            }
        }
        .padding(.horizontal, Tokens.gapS)
        .padding(.vertical, Tokens.gapS)
    }

    private var collapseButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                model.settings.sidebarCollapsed.toggle()
            }
            model.saveSettings()
        } label: {
            Image(systemName: isCollapsed ? "sidebar.right" : "sidebar.left")
                .font(.system(size: 13))
        }
        .buttonStyle(.borderless)
        .frame(width: 28, height: 28)
        .help(isCollapsed ? L("展开导航") : L("收起导航"))
    }

    // MARK: - 主题 / 语言

    private var themePicker: some View {
        Picker(L("主题"), selection: themeBinding) {
            ForEach(ThemeMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .id(model.settings.language)
    }

    private var languagePicker: some View {
        Picker(L("语言"), selection: languageBinding) {
            ForEach(AppLanguage.allCases) { language in
                Text(language.title).tag(language)
            }
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
