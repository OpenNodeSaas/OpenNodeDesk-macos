import SwiftUI

/// 云端同步：先拉取预览，勾选后再落库，不直接覆盖本地
struct SyncSheet: View {
    @EnvironmentObject var model: AppModel

    @State private var selectedIDs: Set<UUID> = []
    @State private var outcome: ImportOutcome?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.gapL) {
                    configCard
                    previewCard
                    if let outcome {
                        resultCard(outcome)
                    }
                }
                .padding(Tokens.gapL)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(minWidth: 660, minHeight: 560)
        .onAppear { selectAll() }
        .onChange(of: model.pendingRemoteAssets) { _, _ in selectAll() }
    }

    // MARK: - 头部 / 底部

    private var header: some View {
        HStack {
            Text(L("云端同步")).font(.system(size: 15, weight: .semibold))
            Spacer()
        }
        .padding(Tokens.gapL)
    }

    private var footer: some View {
        HStack {
            Button(L("关闭")) { model.showSyncSheet = false }
            Spacer()
            Button(action: commit) { Text(L("导入选中")) }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || selectedIDs.isEmpty)
        }
        .padding(Tokens.gapL)
    }

    // MARK: - 服务配置

    private var configCard: some View {
        CardContainer(title: L("同步服务")) {
            VStack(alignment: .leading, spacing: Tokens.gapM) {
                FormLabel(text: L("服务地址"))
                TextField(L("服务地址"), text: endpointBinding, prompt: Text("https://sync.example.com/api/"))
                    .textFieldStyle(.roundedBorder)
                FieldHint(text: L("接口根地址以 / 结尾，将以 /assets 作为资产接口。"))

                FormLabel(text: L("访问令牌"))
                SecureField(L("访问令牌"), text: tokenBinding)
                    .textFieldStyle(.roundedBorder)
                FieldHint(text: L("令牌仅保存在本机设置中，不会随导出文件外泄。"))

                Button {
                    Task { await model.syncFetch() }
                } label: {
                    if model.isBusy {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(L("拉取预览"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy)
            }
        }
    }

    // MARK: - 预览

    private var previewCard: some View {
        CardContainer(title: L("预览")) {
            VStack(alignment: .leading, spacing: Tokens.gapM) {
                Text(L("预览先行，不直接落库：确认无误后再选择导入，导入按「主机 + 端口」合并。"))
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)

                if model.pendingRemoteAssets.isEmpty {
                    Text(L("尚未拉取远端资产。填写服务地址与令牌后点击「拉取预览」。"))
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.mutedForeground)
                        .padding(.vertical, Tokens.gapM)
                } else {
                    HStack(spacing: Tokens.gapM) {
                        Text(L("已选中 {a} / {b} 条")
                                .replacingOccurrences(of: "{a}", with: "\(selectedIDs.count)")
                                .replacingOccurrences(of: "{b}", with: "\(model.pendingRemoteAssets.count)"))
                            .font(.system(size: 11))
                            .foregroundStyle(Tokens.mutedForeground)
                        Spacer()
                        Button(L("全选")) { selectAll() }.controlSize(.small)
                        Button(L("反选")) { invert() }.controlSize(.small)
                    }

                    VStack(spacing: 0) {
                        ForEach(model.pendingRemoteAssets) { asset in
                            remoteRow(asset)
                            if asset.id != model.pendingRemoteAssets.last?.id { Divider() }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous).fill(Tokens.surfaceBackground))
                    .overlay(RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous).stroke(Tokens.softBorder, lineWidth: 1))
                }
            }
        }
    }

    private func remoteRow(_ asset: Asset) -> some View {
        HStack(spacing: Tokens.gapM) {
            Toggle("", isOn: binding(for: asset.id))
                .labelsHidden()
                .toggleStyle(.checkbox)
            ProtocolBadge(proto: asset.proto)
            Text(asset.displayName).font(.system(size: 12))
            Text(asset.address).font(.system(size: 11, design: .monospaced)).foregroundStyle(Tokens.mutedForeground)
            Spacer()
            Text(asset.group.isEmpty ? L("未分组") : asset.group)
                .font(.system(size: 11))
                .foregroundStyle(Tokens.mutedForeground)
        }
        .padding(.horizontal, Tokens.gapM)
        .padding(.vertical, Tokens.gapS)
    }

    private func resultCard(_ outcome: ImportOutcome) -> some View {
        CardContainer(title: L("导入结果")) {
            HStack(spacing: Tokens.gapXL) {
                VStack(spacing: Tokens.gapXS) {
                    Text("\(outcome.imported)").font(.system(size: 22, weight: .semibold)).foregroundStyle(Tokens.success)
                    Text(L("新增")).font(.system(size: 11)).foregroundStyle(Tokens.mutedForeground)
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: Tokens.gapXS) {
                    Text("\(outcome.updated)").font(.system(size: 22, weight: .semibold)).foregroundStyle(Tokens.info)
                    Text(L("更新")).font(.system(size: 11)).foregroundStyle(Tokens.mutedForeground)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 绑定

    private var endpointBinding: Binding<String> {
        Binding(
            get: { model.settings.syncEndpoint },
            set: { model.settings.syncEndpoint = $0; model.saveSettings() }
        )
    }

    private var tokenBinding: Binding<String> {
        Binding(
            get: { model.settings.syncToken },
            set: { model.settings.syncToken = $0; model.saveSettings() }
        )
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(id) },
            set: { on in
                if on { selectedIDs.insert(id) } else { selectedIDs.remove(id) }
            }
        )
    }

    // MARK: - 动作

    private func selectAll() {
        selectedIDs = Set(model.pendingRemoteAssets.map { $0.id })
    }

    private func invert() {
        let all = Set(model.pendingRemoteAssets.map { $0.id })
        selectedIDs = all.symmetricDifference(selectedIDs)
    }

    private func commit() {
        let chosen = model.pendingRemoteAssets.filter { selectedIDs.contains($0.id) }
        guard !chosen.isEmpty else { return }
        let result = model.commitSyncImport(chosen)
        outcome = result
        model.setStatus(L("已从云端导入 {n} 条资产").replacingOccurrences(of: "{n}", with: "\(result.imported + result.updated)"), kind: .success)
    }
}
