import SwiftUI

/// 资产中心内容区：第三层命令栏（分组徽章 + 批量探测）+ 到期汇总 + 表格 / 宫格
struct AssetBrowserView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Tokens.gapM) {
                GroupBadgeBar(groups: model.groups, activeGroup: model.activeGroupFilter) { group in
                    model.selectGroup(group)
                }
                Spacer(minLength: Tokens.gapM)
                Button(L("批量探测")) {
                    model.probeSelected()
                }
                .help(L("对选中资产或全部资产发起可达性检测"))

                Button {
                    model.inspectorPresented.toggle()
                } label: {
                    Label(L("资产详情"), systemImage: "sidebar.right")
                }
                .help(model.inspectorPresented ? L("收起右侧详情面板") : L("展开右侧详情面板"))
            }
            .padding(.horizontal, Tokens.gapL)
            .padding(.vertical, Tokens.gapM)

            if !model.warningAssets.isEmpty {
                ExpirySummaryBar(warningAssets: model.warningAssets, expanded: $model.expiryBarExpanded) { asset in
                    model.revealAsset(asset)
                }
                .padding(.horizontal, Tokens.gapL)
            }

            Divider()

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        if model.filteredAssets.isEmpty {
            EmptyStateView(
                symbol: "square.grid.2x2",
                title: L("还没有资产"),
                message: L("点击「新增资产」录入第一台机器，或从 CSV / Excel 批量导入清单。"),
                actionTitle: L("新增资产"),
                action: { model.editorRequest = EditorRequest(asset: Asset(), isNew: true) }
            )
        } else {
            switch model.settings.viewMode {
            case .table:
                AssetTableView()
            case .grid:
                AssetGridView()
            }
        }
    }
}
