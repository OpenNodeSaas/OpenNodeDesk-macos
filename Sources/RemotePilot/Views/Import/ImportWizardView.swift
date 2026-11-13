import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 批量导入向导：选文件 → 字段映射/预览 → 确认 → 结果摘要
struct ImportWizardView: View {
    @EnvironmentObject var model: AppModel

    // 0 选择文件 / 1 字段映射 / 2 确认导入 / 3 结果摘要
    @State private var step = 0
    @State private var fileURL: URL?
    @State private var preview: ImportPreview?
    @State private var errorMessage: String?
    @State private var outcome: ImportOutcome?

    private let stepTitles = [L("选择文件"), L("字段映射"), L("确认导入"), L("结果摘要")]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                content.padding(Tokens.gapL)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(minWidth: 720, minHeight: 560)
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.gapM) {
            Text(L("批量导入向导")).font(.system(size: 15, weight: .semibold))
            HStack(spacing: Tokens.gapM) {
                ForEach(Array(stepTitles.enumerated()), id: \.offset) { index, title in
                    HStack(spacing: Tokens.gapS) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(index <= step ? Color.white : Tokens.mutedForeground)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(index <= step ? Tokens.accent : Tokens.softBorder))
                        Text(title)
                            .font(.system(size: 11, weight: index == step ? .semibold : .regular))
                            .foregroundStyle(index == step ? Tokens.primaryForeground : Tokens.mutedForeground)
                    }
                    if index < stepTitles.count - 1 {
                        Rectangle().fill(Tokens.softBorder).frame(width: 14, height: 1)
                    }
                }
                Spacer()
            }
        }
        .padding(Tokens.gapL)
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: fileStep
        case 1: mappingStep
        case 2: confirmStep
        default: resultStep
        }
    }

    private var fileStep: some View {
        VStack(alignment: .leading, spacing: Tokens.gapL) {
            CardContainer(title: L("选择导入文件")) {
                VStack(alignment: .leading, spacing: Tokens.gapM) {
                    bullet(L("支持 CSV 与 Excel（.xlsx）文件。"))
                    bullet(L("Excel 请勿保存为 .xls；解析失败时请另存为 CSV 后重试。"))
                    bullet(L("首行需为表头，可识别中英文列名，例如 主机 / ip、用户名 / username。"))
                    HStack(spacing: Tokens.gapM) {
                        Button(L("选择文件…")) { chooseFile() }
                            .buttonStyle(.borderedProminent)
                        if let fileURL {
                            Text(fileURL.lastPathComponent)
                                .font(.system(size: 12))
                                .foregroundStyle(Tokens.mutedForeground)
                        }
                    }
                }
            }

            if let errorMessage {
                CardContainer(title: L("无法读取")) {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var mappingStep: some View {
        VStack(alignment: .leading, spacing: Tokens.gapL) {
            if let preview {
                CardContainer(title: L("识别到的字段映射")) {
                    VStack(alignment: .leading, spacing: Tokens.gapS) {
                        ForEach(preview.mappedFields) { field in
                            HStack(spacing: Tokens.gapM) {
                                Text(field.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 72, alignment: .leading)
                                Image(systemName: "arrow.left").font(.system(size: 10)).foregroundStyle(Tokens.mutedForeground)
                                Text(columnName(for: field, in: preview))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(Tokens.primaryForeground)
                                if field.isSensitive {
                                    Text(L("敏感"))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Tokens.danger)
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(Capsule().fill(Tokens.danger.opacity(0.12)))
                                }
                                Spacer()
                            }
                        }
                    }
                }

                if !unrecognizedHeaders(in: preview).isEmpty {
                    CardContainer(title: L("未识别的列")) {
                        VStack(alignment: .leading, spacing: Tokens.gapS) {
                            Text(L("以下列名未匹配到任何资产字段，导入时将被忽略："))
                                .font(.system(size: 11))
                                .foregroundStyle(Tokens.mutedForeground)
                            Text(unrecognizedHeaders(in: preview).joined(separator: "、"))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Tokens.warning)
                        }
                    }
                }

                CardContainer(title: L("样本数据（前 8 行）")) {
                    sampleTable(preview)
                }
            }
        }
    }

    private var confirmStep: some View {
        CardContainer(title: L("确认导入")) {
            VStack(alignment: .leading, spacing: Tokens.gapM) {
                if let preview {
                    Text(L("将导入 {n} 行数据").replacingOccurrences(of: "{n}", with: "\(preview.rows.count)"))
                        .font(.system(size: 13, weight: .medium))
                    Text(L("识别字段 {a} / 共 {b} 列")
                            .replacingOccurrences(of: "{a}", with: "\(preview.mappedFields.count)")
                            .replacingOccurrences(of: "{b}", with: "\(preview.headers.count)"))
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.mutedForeground)
                    Text(L("导入将按「主机 + 端口 + 协议」合并：已存在的资产会被更新，其余新增。"))
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var resultStep: some View {
        VStack(alignment: .leading, spacing: Tokens.gapL) {
            CardContainer(title: L("导入结果")) {
                HStack(spacing: Tokens.gapXL) {
                    resultStat(L("新增"), outcome?.imported ?? 0, Tokens.success)
                    resultStat(L("更新"), outcome?.updated ?? 0, Tokens.info)
                    resultStat(L("失败"), outcome?.failures.count ?? 0, (outcome?.failures.isEmpty ?? true) ? Tokens.mutedForeground : Tokens.danger)
                }
            }

            if let failures = outcome?.failures, !failures.isEmpty {
                CardContainer(title: L("失败明细")) {
                    VStack(alignment: .leading, spacing: Tokens.gapS) {
                        ForEach(failures) { failure in
                            HStack(alignment: .top, spacing: Tokens.gapM) {
                                Text(L("第 {n} 行").replacingOccurrences(of: "{n}", with: "\(failure.line)"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Tokens.mutedForeground)
                                    .frame(width: 72, alignment: .leading)
                                Text(failure.reason)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Tokens.primaryForeground)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            if failure.id != failures.last?.id { Divider() }
                        }
                        Button(L("导出失败行…")) { exportFailures() }
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: - 底部按钮

    private var footer: some View {
        HStack {
            Button(L("关闭")) { model.showImportSheet = false }
            Spacer()
            switch step {
            case 1:
                Button(L("上一步")) { step = 0 }
                Button(L("下一步")) { step = 2 }.buttonStyle(.borderedProminent)
            case 2:
                Button(L("上一步")) { step = 1 }
                Button(action: performImport) {
                    if model.isBusy {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(L("开始导入"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy)
            case 3:
                Button(L("再次导入")) { reset() }
            default:
                EmptyView()
            }
        }
        .padding(Tokens.gapL)
    }

    // MARK: - 辅助

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.gapS) {
            Text("•").foregroundStyle(Tokens.mutedForeground)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Tokens.primaryForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func resultStat(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: Tokens.gapXS) {
            Text("\(value)").font(.system(size: 22, weight: .semibold)).foregroundStyle(color)
            Text(title).font(.system(size: 11)).foregroundStyle(Tokens.mutedForeground)
        }
        .frame(maxWidth: .infinity)
    }

    private func columnName(for field: AssetField, in preview: ImportPreview) -> String {
        guard let index = preview.mapping[field], preview.headers.indices.contains(index) else { return "—" }
        return preview.headers[index]
    }

    private func unrecognizedHeaders(in preview: ImportPreview) -> [String] {
        let mapped = Set(preview.mapping.values)
        return preview.headers.enumerated()
            .filter { !mapped.contains($0.offset) && !$0.element.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.element }
    }

    private func sampleTable(_ preview: ImportPreview) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(preview.headers.enumerated()), id: \.offset) { _, header in
                        sampleCell(header, isHeader: true)
                    }
                }
                ForEach(Array(preview.sample.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(0..<preview.headers.count, id: \.self) { index in
                            sampleCell(row.indices.contains(index) ? row[index] : "", isHeader: false)
                        }
                    }
                }
                if preview.sample.isEmpty {
                    Text(L("没有可预览的数据行"))
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.mutedForeground)
                        .padding(Tokens.gapM)
                }
            }
        }
        .frame(maxHeight: 220)
    }

    private func sampleCell(_ text: String, isHeader: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: isHeader ? .semibold : .regular, design: .monospaced))
            .foregroundStyle(isHeader ? Tokens.mutedForeground : Tokens.primaryForeground)
            .lineLimit(1)
            .frame(width: 132, alignment: .leading)
            .padding(.horizontal, Tokens.gapS)
            .padding(.vertical, 5)
            .background(isHeader ? Tokens.surfaceBackground : Color.clear)
            .overlay(Rectangle().stroke(Tokens.softBorder, lineWidth: 0.5))
    }

    // MARK: - 动作

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        var types: [UTType] = [.commaSeparatedText, .plainText]
        if let xlsx = UTType(filenameExtension: "xlsx") { types.append(xlsx) }
        panel.allowedContentTypes = types
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url: url)
    }

    private func load(url: URL) {
        fileURL = url
        errorMessage = nil
        outcome = nil
        do {
            preview = try AssetImporter.preview(url: url)
            step = 1
        } catch {
            preview = nil
            errorMessage = error.localizedDescription
            step = 0
        }
    }

    private func performImport() {
        guard let preview else { return }
        let built = AssetImporter.buildAssets(rows: preview.rows, mapping: preview.mapping)
        let result = model.applyImport(built)
        outcome = result
        step = 3
        let failed = result.failures.count
        let message = L("导入完成：新增 {a} / 更新 {u} / 失败 {f}")
            .replacingOccurrences(of: "{a}", with: "\(result.imported)")
            .replacingOccurrences(of: "{u}", with: "\(result.updated)")
            .replacingOccurrences(of: "{f}", with: "\(failed)")
        model.setStatus(message, kind: failed == 0 ? .success : .warning)
    }

    private func exportFailures() {
        guard let preview, let outcome, !outcome.failures.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "import-failures.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let text = AssetImporter.failureCSV(headers: preview.headers, failures: outcome.failures)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            model.setStatus(L("已导出失败行：{v}").replacingOccurrences(of: "{v}", with: url.lastPathComponent), kind: .success)
        } catch {
            model.setStatus(L("导出失败：{v}").replacingOccurrences(of: "{v}", with: error.localizedDescription), kind: .failure)
        }
    }

    private func reset() {
        step = 0
        fileURL = nil
        preview = nil
        errorMessage = nil
        outcome = nil
    }
}
