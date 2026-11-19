import SwiftUI

/// 顶部命令栏：单行紧凑布局，全部挂载到原生 NSToolbar 上。
/// 由 AppKit 的 NSToolbarItem 托管命中测试，避免隐藏标题栏时被系统拖拽区吞掉点击。
/// 搜索 / 视图切换 / 主命令常驻；作用于「下一次连接」的参数收进浮层，避免第二层横条占用高度。

// MARK: - 搜索框

struct CommandSearchField: View {
    @EnvironmentObject var model: AppModel
    @FocusState private var searchFocused: Bool

    private var singleSelection: Asset? {
        guard model.selection.count == 1 else { return nil }
        return model.selectedAssets.first
    }

    var body: some View {
        HStack(spacing: Tokens.gapS) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Tokens.mutedForeground)

            TextField(L("搜索名称 / IP / 分组 / 负责人 / 备注"), text: $model.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($searchFocused)
                .onSubmit(connectFirstMatch)

            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.mutedForeground)
                }
                .buttonStyle(.plain)
                .help(L("清空搜索"))
                .accessibilityLabel(L("清空搜索"))
            }
        }
        .padding(.horizontal, Tokens.gapM)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous)
                .fill(Tokens.fieldBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous)
                .stroke(searchFocused ? Tokens.accent : Tokens.softBorder, lineWidth: 1)
        )
        .frame(width: 260)
        .help(L("回车直接连接搜索命中的第一台机器"))
        .onChange(of: model.focusSearchTick) { _, _ in searchFocused = true }
    }

    /// 回车：优先连接唯一选中项，否则连接搜索命中的第一台
    private func connectFirstMatch() {
        if let asset = singleSelection {
            model.connect(asset)
            return
        }
        guard let first = model.filteredAssets.first else { return }
        model.connect(first)
    }
}

// MARK: - 视图切换

struct CommandViewModeControl: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Picker(L("视图"), selection: viewModeBinding) {
            ForEach(ViewMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 116)
        .help(L("切换表格 / 宫格视图"))
        // 分段控件的段标题由 Picker 项缓存，切换语言后需强制重建才能刷新文案
        .id(model.settings.language)
    }

    private var viewModeBinding: Binding<ViewMode> {
        Binding(
            get: { model.settings.viewMode },
            set: { model.settings.viewMode = $0; model.saveSettings() }
        )
    }
}

// MARK: - 连接参数浮层

struct CommandParametersButton: View {
    @EnvironmentObject var model: AppModel
    @State private var presented = false

    var body: some View {
        Button {
            presented.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .help(L("连接参数"))
        .accessibilityLabel(L("连接参数"))
        .popover(isPresented: $presented, arrowEdge: .bottom) {
            popoverContent
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: Tokens.gapM) {
            Text(L("连接参数"))
                .font(.system(size: 12, weight: .semibold))

            row(L("窗口模式")) {
                Picker("", selection: windowModeBinding) {
                    ForEach(WindowMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .help(ParamHelp.windowMode)
                .id(model.settings.language)
            }

            row(L("色深")) {
                Picker("", selection: colorDepthBinding) {
                    ForEach(ColorDepth.allCases) { depth in
                        Text(depth.title).tag(depth)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .help(ParamHelp.colorDepth)
                .id(model.settings.language)
            }

            row(L("重定向")) {
                VStack(alignment: .leading, spacing: Tokens.gapXS) {
                    Toggle(L("驱动器"), isOn: redirectBinding(\.drives))
                        .toggleStyle(.checkbox)
                        .help(ParamHelp.drives)
                    Toggle(L("音频"), isOn: redirectBinding(\.audio))
                        .toggleStyle(.checkbox)
                        .help(ParamHelp.audio)
                    Toggle(L("使用粘贴板"), isOn: redirectBinding(\.clipboard))
                        .toggleStyle(.checkbox)
                        .help(ParamHelp.clipboard)
                }
            }

            Text(L("以上参数作用于下一次连接"))
                .font(.system(size: 11))
                .foregroundStyle(Tokens.subtleForeground)
        }
        .padding(Tokens.gapL)
        .frame(width: 300)
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.gapM) {
            FormLabel(text: label)
            content()
            Spacer(minLength: 0)
        }
    }

    private var windowModeBinding: Binding<WindowMode> {
        Binding(
            get: { model.settings.windowMode },
            set: { model.settings.windowMode = $0; model.saveSettings() }
        )
    }

    private var colorDepthBinding: Binding<ColorDepth> {
        Binding(
            get: { model.settings.colorDepth },
            set: { model.settings.colorDepth = $0; model.saveSettings() }
        )
    }

    private func redirectBinding(_ keyPath: WritableKeyPath<RedirectionOptions, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.settings.redirects[keyPath: keyPath] },
            set: { model.settings.redirects[keyPath: keyPath] = $0; model.saveSettings() }
        )
    }
}

// MARK: - 列设置浮层

struct CommandColumnSettingsButton: View {
    @EnvironmentObject var model: AppModel
    @State private var presented = false

    var body: some View {
        Button {
            presented.toggle()
        } label: {
            Image(systemName: "tablecells")
        }
        .help(L("列设置"))
        .accessibilityLabel(L("列设置"))
        .popover(isPresented: $presented, arrowEdge: .bottom) {
            ColumnSettingsPopover()
                .environmentObject(model)
        }
    }
}

// MARK: - 溢出菜单

/// 低频操作收进「更多」，保持命令栏只有一行
struct CommandOverflowMenu: View {
    @EnvironmentObject var model: AppModel

    private var singleSelection: Asset? {
        guard model.selection.count == 1 else { return nil }
        return model.selectedAssets.first
    }

    var body: some View {
        Menu {
            Button(L("编辑")) {
                if let asset = singleSelection { model.editorRequest = EditorRequest(asset: asset, isNew: false) }
            }
            .disabled(singleSelection == nil)

            Button(L("导入资产")) { model.showImportSheet = true }
            Button(L("导出选中")) { model.showExportSheet = true }

            Divider()

            Button(L("反选")) { model.invertSelection() }
                .disabled(model.filteredAssets.isEmpty)
            Button(L("云端同步")) { model.showSyncSheet = true }
                .disabled(model.settings.syncEndpoint.isEmpty)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(L("更多"))
        .accessibilityLabel(L("更多"))
    }
}
