import Foundation
import SwiftUI
import AppKit

/// 手写表格：列集合由「列设置」驱动（列显隐 / 列顺序 / 列宽 / 列表字号）。
/// 除「操作」外所有列表头可排序；拖动表头右边缘可调列宽，宽度随本地配置持久化。
/// 列宽合计超出视口时横向滚动，内容始终靠左上对齐。
struct AssetTableView: View {
    @EnvironmentObject var model: AppModel

    private enum Metrics {
        static let favorite: CGFloat = 32
        static let select: CGFloat = 32
        static let hPad: CGFloat = Tokens.gapS
    }

    @State private var sortColumn: AssetColumn = .name
    @State private var sortAscending = true
    /// 表格可用宽度：名称列保持弹性时，用于推算它的当前宽度
    @State private var tableWidth: CGFloat = 0
    @State private var dragStartWidth: CGFloat?

    private var columns: [AssetColumn] { model.settings.visibleColumns }
    private var fontSize: CGFloat { model.settings.listFontSize.points }
    private var rowHeight: CGFloat { model.settings.listFontSize.rowHeight }

    // MARK: - 数据

    private var rows: [Asset] {
        let base = model.filteredAssets
        switch sortColumn {
        case .expiry:
            return base.sorted { lhs, rhs in
                let l = lhs.expiry ?? .distantFuture
                let r = rhs.expiry ?? .distantFuture
                if l == r { return lhs.displayName < rhs.displayName }
                return sortAscending ? l < r : l > r
            }
        default:
            return base.sorted { lhs, rhs in
                let l = sortKey(lhs, sortColumn)
                let r = sortKey(rhs, sortColumn)
                if l == r { return lhs.displayName < rhs.displayName }
                return sortAscending ? l < r : l > r
            }
        }
    }

    private func sortKey(_ asset: Asset, _ column: AssetColumn) -> String {
        switch column {
        case .group: return asset.group
        case .owner: return asset.owner
        case .name: return asset.displayName
        case .address: return asset.address
        case .username: return asset.username
        case .status: return (model.probeResults[asset.id] ?? ProbeResult.unknown).status.rawValue
        case .expiry: return ""
        case .note1: return asset.note1
        case .note2: return asset.note2
        case .note3: return asset.note3
        case .note4: return asset.note4
        case .template: return model.template(id: asset.templateID)?.name ?? ""
        case .proto: return asset.proto.rawValue
        case .actions: return ""
        }
    }

    // MARK: - 选择态

    private var visibleIDs: Set<UUID> { Set(model.filteredAssets.map { $0.id }) }

    private var selectionSymbol: String {
        let ids = visibleIDs
        guard !ids.isEmpty else { return "square" }
        let selected = ids.intersection(model.selection)
        if selected.isEmpty { return "square" }
        if selected.count == ids.count { return "checkmark.square.fill" }
        return "minus.square.fill"
    }

    // MARK: - Body

    var body: some View {
        let items = rows
        return GeometryReader { proxy in
            // 列宽合计超出视口时横向滚动，不再把右侧列裁掉
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section(header: headerRow) {
                        ForEach(items.indices, id: \.self) { index in
                            rowView(asset: items[index], index: index)
                        }
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                // 双轴 ScrollView 会把不满一屏的内容居中，这里撑满视口并靠左上对齐
                .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .topLeading)
            }
            .onAppear { tableWidth = proxy.size.width }
            .onChange(of: proxy.size.width) { _, newValue in tableWidth = newValue }
        }
        .focusable()
        // 表格自己管理键盘交互，但不要系统默认的聚焦蓝框
        .focusEffectDisabled()
        .onKeyPress(.return) {
            if model.selection.count == 1,
               let id = model.selection.first,
               let asset = items.first(where: { $0.id == id }) {
                model.connect(asset)
                return .handled
            }
            return .ignored
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - 表头

    private var headerRow: some View {
        HStack(spacing: 0) {
            Image(systemName: "star")
                .font(.system(size: 11))
                .foregroundStyle(Tokens.subtleForeground)
                .frame(width: Metrics.favorite)
                .help(L("收藏"))

            Button {
                toggleSelectAll()
            } label: {
                Image(systemName: selectionSymbol)
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.mutedForeground)
                    .frame(width: Metrics.select)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("选择"))

            ForEach(columns) { column in
                headerCell(column)
                    .overlay(alignment: .trailing) { resizeHandle(column) }
            }
        }
        .padding(.horizontal, Metrics.hPad)
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surfaceBackground)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func headerCell(_ column: AssetColumn) -> some View {
        columnFrame(column) {
            Group {
                if column.isSortable {
                    Button {
                        toggleSort(column)
                    } label: {
                        headerLabel(column, active: sortColumn == column)
                    }
                    .buttonStyle(.plain)
                } else {
                    headerLabel(column, active: false)
                }
            }
        }
    }

    private func headerLabel(_ column: AssetColumn, active: Bool) -> some View {
        HStack(spacing: 2) {
            Text(column.title)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(Tokens.mutedForeground)
                .lineLimit(1)
            if active {
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Tokens.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: column == .name ? .leading : .center)
        .contentShape(Rectangle())
    }

    // MARK: - 行

    private func rowView(asset: Asset, index: Int) -> some View {
        HStack(spacing: 0) {
            Button {
                model.toggleFavorite(asset)
            } label: {
                Image(systemName: asset.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundStyle(asset.isFavorite ? Tokens.accent : Tokens.subtleForeground)
                    .frame(width: Metrics.favorite)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("收藏"))

            Button {
                toggleSelection(asset)
            } label: {
                Image(systemName: model.selection.contains(asset.id) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12))
                    .foregroundStyle(model.selection.contains(asset.id) ? Tokens.accent : Tokens.mutedForeground)
                    .frame(width: Metrics.select)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("选择"))

            ForEach(columns) { column in
                cell(column, asset: asset)
            }
        }
        .padding(.horizontal, Metrics.hPad)
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground(asset: asset, index: index))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            model.connect(asset)
        }
        .onTapGesture {
            // 选中不自动展开详情面板：唯一入口是顶栏 / 工具区的「资产详情」按钮
            model.selection = [asset.id]
        }
    }

    // MARK: - 列宽（拖拽调整 + 记忆）

    /// 列宽：用户拖拽过的列用记忆值，其余用列默认宽；名称列未拖拽时保持弹性填满
    /// 对齐：名称列左对齐，其余列居中
    @ViewBuilder
    private func columnFrame<Content: View>(_ column: AssetColumn, @ViewBuilder content: () -> Content) -> some View {
        let width = model.settings.columnWidth(column)
        let alignment: Alignment = column == .name ? .leading : .center
        if width > 0 {
            content().frame(width: width, alignment: alignment)
        } else {
            content().frame(minWidth: column.minWidth, maxWidth: .infinity, alignment: alignment)
        }
    }

    /// 内容总宽：两侧图标列 + 左右内边距 + 各列宽。
    /// 名称列未拖拽时用视口剩余宽度补齐，因此列宽合计不超视口时内容宽正好等于视口（无横向滚动）；
    /// 一旦合计超出视口，内容宽大于视口，由 ScrollView 横向滚动承载，右侧列不再被裁掉。
    private var contentWidth: CGFloat {
        let chrome = Metrics.favorite + Metrics.select + Metrics.hPad * 2
        let stored = columns.reduce(CGFloat.zero) { $0 + model.settings.columnWidth($1) }
        if columns.contains(.name), model.settings.columnWidth(.name) == 0 {
            let nameWidth = max(AssetColumn.name.minWidth, tableWidth - chrome - stored)
            return max(chrome + stored + nameWidth, tableWidth)
        }
        return max(chrome + stored, tableWidth)
    }

    /// 表头右边缘的拖拽把手：拖动即时生效，松手后写入本地配置
    private func resizeHandle(_ column: AssetColumn) -> some View {
        ZStack(alignment: .trailing) {
            Color.clear
            Rectangle()
                .fill(Tokens.softBorder)
                .frame(width: 1)
        }
        .frame(width: 9)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let start = dragStartWidth ?? currentWidth(column)
                    if dragStartWidth == nil { dragStartWidth = start }
                    model.settings.setColumnWidth(start + value.translation.width, for: column)
                }
                .onEnded { _ in
                    dragStartWidth = nil
                    model.saveSettings()
                }
        )
    }

    /// 拖拽起点宽：优先用列自身宽；弹性列按「表宽 − 其余列宽」推算，避免拖拽瞬间跳变
    private func currentWidth(_ column: AssetColumn) -> CGFloat {
        let own = model.settings.columnWidth(column)
        if own > 0 { return own }
        let others = columns.filter { $0 != column }
            .reduce(CGFloat.zero) { $0 + max(model.settings.columnWidth($1), $1.minWidth) }
        let available = tableWidth - Metrics.favorite - Metrics.select - Metrics.hPad * 2 - others
        return max(column.minWidth, available)
    }

    // MARK: - 单元格

    /// 按列渲染：宽度由列宽记忆 / 列默认值决定，字号跟随列表字号设置
    private func cell(_ column: AssetColumn, asset: Asset) -> some View {
        columnFrame(column) { cellContent(column, asset: asset) }
    }

    @ViewBuilder
    private func cellContent(_ column: AssetColumn, asset: Asset) -> some View {
        switch column {
        case .group:
            cellText(asset.group.isEmpty ? L("未分组") : asset.group)
        case .owner:
            cellText(asset.owner.isEmpty ? "—" : asset.owner)
        case .name:
            Text(asset.displayName)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(Tokens.primaryForeground)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(asset.displayName)
        case .address:
            Text(asset.address)
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundStyle(Tokens.mutedForeground)
                .lineLimit(1)
                .help(asset.address)
        case .username:
            cellText(asset.username.isEmpty ? "—" : asset.username)
        case .status:
            StatusBadge(result: model.probeResults[asset.id] ?? ProbeResult.unknown)
        case .expiry:
            expiryText(asset)
        case .note1:
            noteText(asset.note1)
        case .note2:
            noteText(asset.note2)
        case .note3:
            noteText(asset.note3)
        case .note4:
            noteText(asset.note4)
        case .template:
            templateCell(asset)
        case .proto:
            ProtocolBadge(proto: asset.proto)
        case .actions:
            actionCell(asset)
        }
    }

    private func cellText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: fontSize))
            .foregroundStyle(Tokens.primaryForeground)
            .lineLimit(1)
            .truncationMode(.tail)
            .help(text)
    }

    private func noteText(_ text: String) -> some View {
        Text(text.isEmpty ? "—" : text)
            .font(.system(size: fontSize))
            .foregroundStyle(Tokens.mutedForeground)
            .lineLimit(1)
            .truncationMode(.tail)
            .help(text)
    }

    @ViewBuilder
    private func expiryText(_ asset: Asset) -> some View {
        if let expiry = asset.expiry {
            Text(DateFormatter.localizedString(from: expiry, dateStyle: .short, timeStyle: .none))
                .font(.system(size: fontSize))
                .foregroundStyle(asset.expiryState.isWarning ? Tokens.warning : Tokens.primaryForeground)
                .lineLimit(1)
                .help(asset.expiryState.text)
        } else {
            Text("—")
                .font(.system(size: fontSize))
                .foregroundStyle(Tokens.mutedForeground)
                .help(asset.expiryState.text)
        }
    }

    @ViewBuilder
    private func templateCell(_ asset: Asset) -> some View {
        if let template = model.template(id: asset.templateID) {
            Button {
                model.planRequest = PlanRequest(asset: asset, highlightTemplate: true)
            } label: {
                Text(template.name)
                    .font(.system(size: fontSize))
                    .foregroundStyle(Tokens.accent)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .buttonStyle(.link)
            .help(template.name)
        } else {
            Text("—")
                .font(.system(size: fontSize))
                .foregroundStyle(Tokens.mutedForeground)
        }
    }

    private func actionCell(_ asset: Asset) -> some View {
        HStack(spacing: Tokens.gapM) {
            Button {
                model.editorRequest = EditorRequest(asset: asset, isNew: false)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("编辑"))

            Button {
                model.requestDelete([asset.id])
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.danger)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("删除"))
        }
    }

    // MARK: - 背景 / 交互

    private func rowBackground(asset: Asset, index: Int) -> Color {
        if model.selection.contains(asset.id) { return Tokens.selectedRow }
        if asset.expiryState.isWarning { return Tokens.expiryRow }
        return index % 2 == 1 ? Tokens.alternateRow : Color.clear
    }

    private func toggleSelection(_ asset: Asset) {
        if model.selection.contains(asset.id) {
            model.selection.remove(asset.id)
        } else {
            model.selection.insert(asset.id)
        }
    }

    private func toggleSelectAll() {
        let ids = visibleIDs
        guard !ids.isEmpty else { return }
        if ids.isSubset(of: model.selection) {
            model.selection = model.selection.subtracting(ids)
        } else {
            model.selection = model.selection.union(ids)
        }
    }

    private func toggleSort(_ column: AssetColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
    }
}
