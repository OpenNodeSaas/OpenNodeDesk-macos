import SwiftUI

/// 连接方案模板管理：左侧列表 + 右侧详情，支持新建/编辑/复制/删除与排序
struct TemplateManagerView: View {
    @EnvironmentObject var model: AppModel

    /// 排序方式
    enum SortMode: String, CaseIterable, Identifiable {
        case name
        case usage

        var id: String { rawValue }

        var title: String {
            switch self {
            case .name: return L("按名称")
            case .usage: return L("按使用次数")
            }
        }
    }

    @State private var sortMode: SortMode = .name
    @State private var selectedID: UUID?
    /// 待二次确认删除的模板
    @State private var pendingDeletion: ConnectionTemplate?

    private var sortedTemplates: [ConnectionTemplate] {
        switch sortMode {
        case .name:
            return model.templates.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .usage:
            return model.templates.sorted { $0.usageCount > $1.usageCount }
        }
    }

    private var selectedTemplate: ConnectionTemplate? {
        model.templates.first { $0.id == selectedID }
    }

    var body: some View {
        Group {
            if model.templates.isEmpty {
                EmptyStateView(
                    symbol: "square.on.square.dashed",
                    title: L("还没有连接方案模板"),
                    message: L("模板可复用一套端口、用户名、显示与重定向参数，资产选择模板后即可继承。"),
                    actionTitle: L("新建模板")
                ) {
                    newTemplate()
                }
            } else {
                content
            }
        }
        .confirmationDialog(
            L("删除模板？"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { template in
            Button(L("删除"), role: .destructive) {
                model.deleteTemplate(template)
                if selectedID == template.id { selectedID = nil }
                pendingDeletion = nil
                model.setStatus(
                    L("已删除模板「{v}」").replacingOccurrences(of: "{v}", with: template.name),
                    kind: .success
                )
            }
            Button(L("取消"), role: .cancel) { pendingDeletion = nil }
        } message: { template in
            let usage = model.templateUsageCount(template)
            Text(L("删除后，正在使用该模板的 {n} 台资产会回到「默认」参数。")
                .replacingOccurrences(of: "{n}", with: "\(usage)"))
        }
    }

    // MARK: - 主体

    private var content: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            HStack(spacing: 0) {
                listColumn
                Divider()
                detailColumn
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: Tokens.gapM) {
            Button {
                newTemplate()
            } label: {
                Label(L("新建"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)

            Button {
                editSelected()
            } label: {
                Label(L("编辑"), systemImage: "pencil")
            }
            .disabled(selectedTemplate == nil)

            Button {
                duplicateSelected()
            } label: {
                Label(L("复制"), systemImage: "doc.on.doc")
            }
            .disabled(selectedTemplate == nil)

            Button(role: .destructive) {
                pendingDeletion = selectedTemplate
            } label: {
                Label(L("删除"), systemImage: "trash")
            }
            .disabled(selectedTemplate == nil)

            Spacer()

            Picker(L("排序"), selection: $sortMode) {
                ForEach(SortMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help(L("排序方式"))
        }
        .controlSize(.regular)
        .padding(.horizontal, Tokens.gapL)
        .padding(.vertical, Tokens.gapM)
        .background(Tokens.surfaceBackground)
    }

    private var listColumn: some View {
        List(selection: $selectedID) {
            ForEach(sortedTemplates) { template in
                row(template).tag(template.id)
            }
        }
        .listStyle(.inset)
        .frame(minWidth: 240, idealWidth: 280, maxWidth: 320)
    }

    private var detailColumn: some View {
        Group {
            if let template = selectedTemplate {
                detail(template)
            } else {
                EmptyStateView(
                    symbol: "sidebar.right",
                    title: L("选择一个模板"),
                    message: L("在左侧选择一个模板即可查看它的参数详情。")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 列表行

    private func row(_ template: ConnectionTemplate) -> some View {
        HStack(spacing: Tokens.gapM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name.isEmpty ? L("未命名模板") : template.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text("\(template.proto.title) · \(L("端口")) \(template.port)")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.mutedForeground)
            }
            Spacer(minLength: Tokens.gapS)
            usageBadge(model.templateUsageCount(template))
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func usageBadge(_ count: Int) -> some View {
        let color = count > 0 ? Tokens.info : Tokens.mutedForeground
        return Text(L("{n} 台正在使用").replacingOccurrences(of: "{n}", with: "\(count)"))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
            .fixedSize()
    }

    // MARK: - 详情

    private func detail(_ template: ConnectionTemplate) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.gapL) {
                HStack(spacing: Tokens.gapM) {
                    Text(template.name.isEmpty ? L("未命名模板") : template.name)
                        .font(.system(size: 16, weight: .semibold))
                    ProtocolBadge(proto: template.proto)
                    Spacer()
                    usageBadge(model.templateUsageCount(template))
                }

                CardContainer(title: L("连接参数")) {
                    VStack(spacing: Tokens.gapM) {
                        detailRow(L("协议"), template.proto.title)
                        Divider()
                        detailRow(L("端口"), "\(template.port)")
                        Divider()
                        detailRow(L("用户名"), template.username.isEmpty ? "—" : template.username)
                    }
                }

                CardContainer(title: L("显示与重定向")) {
                    VStack(spacing: Tokens.gapM) {
                        detailRow(L("窗口模式"), template.windowMode.title)
                        Divider()
                        detailRow(L("色深"), L("{v} 位").replacingOccurrences(of: "{v}", with: "\(template.colorDepth.rawValue)"))
                        Divider()
                        detailRow(L("重定向"), template.redirects.summary)
                    }
                }

                HStack {
                    Text(L("更新时间")).font(.system(size: 12)).foregroundStyle(Tokens.mutedForeground)
                    Spacer()
                    Text(template.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.primaryForeground)
                }
                .padding(.horizontal, Tokens.gapL)
            }
            .padding(Tokens.gapXL)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(Tokens.mutedForeground)
            Spacer()
            Text(value).font(.system(size: 12)).foregroundStyle(Tokens.primaryForeground)
        }
    }

    // MARK: - 操作

    private func newTemplate() {
        model.templateEditRequest = TemplateEditRequest(template: ConnectionTemplate(), isNew: true)
    }

    private func editSelected() {
        guard let template = selectedTemplate else { return }
        model.templateEditRequest = TemplateEditRequest(template: template, isNew: false)
    }

    private func duplicateSelected() {
        guard let template = selectedTemplate else { return }
        model.duplicateTemplate(template)
        model.setStatus(
            L("已复制模板「{v}」").replacingOccurrences(of: "{v}", with: template.name),
            kind: .success
        )
    }
}
