import SwiftUI

/// 资产中心内容区：分组筛选条 + 到期汇总 + 表格 / 宫格
/// 批量探测与详情面板入口已上收到顶部命令栏，此处只保留内容相关控件
struct AssetBrowserView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            GroupBadgeBar(groups: model.groups, activeGroup: model.activeGroupFilter) { group in
                model.selectGroup(group)
            }
            .padding(.horizontal, Tokens.gapL)
            .padding(.vertical, Tokens.gapS)

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
