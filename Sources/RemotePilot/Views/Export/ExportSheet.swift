import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 导出字段选择：两栏多选；密码/密钥默认不勾选且需二次确认
struct ExportSheet: View {
    @EnvironmentObject var model: AppModel

    @State private var selected: Set<AssetField> = Set(AssetField.allCases.filter { !$0.isSensitive })
    @State private var pendingSensitive: AssetField?

    private let columns = [GridItem(.flexible(), spacing: Tokens.gapL), GridItem(.flexible(), spacing: Tokens.gapL)]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.gapL) {
                    riskBanner
                    CardContainer(title: L("选择导出字段")) {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: Tokens.gapM) {
                            ForEach(AssetField.allCases) { field in
                                fieldRow(field)
                            }
                        }
                    }
                    Text(L("将导出 {n} 条资产").replacingOccurrences(of: "{n}", with: "\(exportCount)"))
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.mutedForeground)
                }
                .padding(Tokens.gapL)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(minWidth: 620, minHeight: 520)
        .alert(L("确认导出敏感字段"), isPresented: showSensitiveAlert, presenting: pendingSensitive) { field in
            Button(L("确认导出"), role: .destructive) {
                selected.insert(field)
                pendingSensitive = nil
            }
            Button(L("取消"), role: .cancel) { pendingSensitive = nil }
        } message: { _ in
            Text(L("密码与 SSH 密钥将以明文写入 CSV 文件，任何能访问该文件的人都能读取，请妥善保管。"))
        }
    }

    // MARK: - 头部 / 底部

    private var header: some View {
        HStack {
            Text(L("导出资产")).font(.system(size: 15, weight: .semibold))
            Spacer()
        }
        .padding(Tokens.gapL)
    }

    private var footer: some View {
        HStack {
            Button(L("关闭")) { model.showExportSheet = false }
            Spacer()
            Button(action: export) { Text(L("导出")) }
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty)
        }
        .padding(Tokens.gapL)
    }

    private var riskBanner: some View {
        HStack(alignment: .top, spacing: Tokens.gapM) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Tokens.danger)
            Text(L("密码与密钥导出后为明文，请妥善保管导出文件。"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tokens.primaryForeground)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(Tokens.gapM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous).fill(Tokens.danger.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous).stroke(Tokens.danger.opacity(0.45), lineWidth: 1))
    }

    // MARK: - 字段行

    private func fieldRow(_ field: AssetField) -> some View {
        Toggle(isOn: binding(for: field)) {
            HStack(spacing: Tokens.gapS) {
                Text(field.title)
                    .font(.system(size: 12))
                    .foregroundStyle(field.isSensitive ? Tokens.danger : Tokens.primaryForeground)
                if field.isSensitive {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Tokens.danger)
                    Text(L("敏感"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Tokens.danger)
                }
                Spacer()
            }
        }
        .toggleStyle(.checkbox)
    }

    private func binding(for field: AssetField) -> Binding<Bool> {
        Binding(
            get: { selected.contains(field) },
            set: { on in
                if on {
                    // 敏感字段：先弹确认，确认后才真正勾选
                    if field.isSensitive { pendingSensitive = field } else { selected.insert(field) }
                } else {
                    selected.remove(field)
                }
            }
        )
    }

    private var showSensitiveAlert: Binding<Bool> {
        Binding(
            get: { pendingSensitive != nil },
            set: { if !$0 { pendingSensitive = nil } }
        )
    }

    // MARK: - 动作

    private var exportCount: Int {
        (model.selectedAssets.isEmpty ? model.filteredAssets : model.selectedAssets).count
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "assets.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.exportCSV(fields: AssetField.allCases.filter { selected.contains($0) }, to: url)
            model.setStatus(L("已导出 {n} 条资产：{v}")
                .replacingOccurrences(of: "{n}", with: "\(exportCount)")
                .replacingOccurrences(of: "{v}", with: url.lastPathComponent), kind: .success)
        } catch {
            model.setStatus(L("导出失败：{v}").replacingOccurrences(of: "{v}", with: error.localizedDescription), kind: .failure)
        }
    }
}
