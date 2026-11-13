import SwiftUI

/// 顶部命令栏：第一层主命令（搜索 / 视图切换 / 增删导入导出）+ 第二层连接参数
struct CommandBar: View {
    @EnvironmentObject var model: AppModel
    @FocusState private var searchFocused: Bool
    @State private var columnSettingsPresented = false

    private var singleSelection: Asset? {
        guard model.selection.count == 1 else { return nil }
        return model.selectedAssets.first
    }

    var body: some View {
        VStack(spacing: 0) {
            primaryLayer
            Divider()
            parameterLayer
        }
        .background(Tokens.surfaceBackground)
        .onChange(of: model.focusSearchTick) { _, _ in searchFocused = true }
    }

    // MARK: 第一层

    private var primaryLayer: some View {
        HStack(spacing: Tokens.gapM) {
            searchField

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

            Button {
                model.editorRequest = EditorRequest(asset: Asset(), isNew: true)
            } label: {
                Label(L("新增资产"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            Spacer(minLength: Tokens.gapM)

            iconButton("square.and.pencil", help: L("打开所选资产的编辑对话框"), disabled: singleSelection == nil) {
                if let asset = singleSelection { model.editorRequest = EditorRequest(asset: asset, isNew: false) }
            }
            columnSettingsButton
            iconButton("square.and.arrow.down", help: L("导入资产")) { model.showImportSheet = true }
            iconButton("square.and.arrow.up", help: L("导出选中")) { model.showExportSheet = true }
            iconButton("arrow.left.arrow.right", help: L("反选"), disabled: model.filteredAssets.isEmpty) {
                model.invertSelection()
            }

            Button {
                model.requestDelete(model.selection)
            } label: {
                Label(deleteTitle, systemImage: "trash")
            }
            .controlSize(.regular)
            .disabled(model.selection.isEmpty)
            .help(L("删除选中资产"))

            iconButton("arrow.triangle.2.circlepath.icloud", help: L("云端同步"), disabled: model.settings.syncEndpoint.isEmpty) {
                model.showSyncSheet = true
            }
        }
        .padding(.horizontal, Tokens.gapL)
        .padding(.vertical, Tokens.gapM)
    }

    /// 列设置入口：打开列显隐 / 列排序 / 列表字号浮层
    private var columnSettingsButton: some View {
        Button {
            columnSettingsPresented.toggle()
        } label: {
            Image(systemName: "tablecells")
        }
        .controlSize(.regular)
        .help(L("列设置"))
        .accessibilityLabel(L("列设置"))
        .popover(isPresented: $columnSettingsPresented, arrowEdge: .bottom) {
            ColumnSettingsPopover()
                .environmentObject(model)
        }
    }

    private var searchField: some View {
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
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous)
                .fill(Tokens.fieldBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous)
                .stroke(searchFocused ? Tokens.accent : Tokens.softBorder, lineWidth: 1)
        )
        .frame(minWidth: 200, maxWidth: 360)
        .help(L("回车直接连接搜索命中的第一台机器"))
    }

    private var deleteTitle: String {
        model.selection.isEmpty
            ? L("删除")
            : L("删除 {n}").replacingOccurrences(of: "{n}", with: "\(model.selection.count)")
    }

    // MARK: 第二层（作用于下一次连接）

    private var parameterLayer: some View {
        HStack(spacing: Tokens.gapL) {
            Text(L("连接参数"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Tokens.mutedForeground)

            HStack(spacing: Tokens.gapS) {
                FormLabel(text: L("窗口模式"))
                Picker("", selection: windowModeBinding) {
                    ForEach(WindowMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 104)
                .help(ParamHelp.windowMode)
                .id(model.settings.language)
            }

            HStack(spacing: Tokens.gapS) {
                FormLabel(text: L("重定向"))
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

            HStack(spacing: Tokens.gapS) {
                FormLabel(text: L("色深"))
                Picker("", selection: colorDepthBinding) {
                    ForEach(ColorDepth.allCases) { depth in
                        Text(depth.title).tag(depth)
                    }
                }
                .labelsHidden()
                .frame(width: 68)
                .help(ParamHelp.colorDepth)
                .id(model.settings.language)
            }

            Spacer(minLength: Tokens.gapM)

            Text(L("以上参数作用于下一次连接"))
                .font(.system(size: 10))
                .foregroundStyle(Tokens.subtleForeground)

            Button {
                model.probeSelected()
            } label: {
                Label(L("探测"), systemImage: "dot.radiowaves.left.and.right")
            }
            .help(L("对选中资产或全部资产发起可达性检测"))
        }
        .padding(.horizontal, Tokens.gapL)
        .padding(.vertical, Tokens.gapS)
    }

    // MARK: 辅助

    private func iconButton(_ symbol: String, help: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .controlSize(.regular)
        .disabled(disabled)
        .help(help)
        // 图标按钮没有文字标签，必须显式提供读屏名称（§9 无障碍）
        .accessibilityLabel(help)
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

    private var viewModeBinding: Binding<ViewMode> {
        Binding(
            get: { model.settings.viewMode },
            set: { model.settings.viewMode = $0; model.saveSettings() }
        )
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
