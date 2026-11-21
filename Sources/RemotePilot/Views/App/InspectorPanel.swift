import SwiftUI
import AppKit

/// 右侧详情面板：窗口尺寸快速配置 + 只读状态 + 就地诊断 + 全局项
struct InspectorPanel: View {
    @EnvironmentObject var model: AppModel

    @State private var widthText = ""
    @State private var heightText = ""
    @State private var probeIntervalText = ""

    private var asset: Asset? { model.inspectorAsset }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.gapL) {
                    if let asset {
                        sizeCard(for: asset)
                        statusCard(for: asset)
                        if let diagnostic = connectionDiagnostic(for: asset) {
                            DiagnosticCard(
                                diagnostic: diagnostic,
                                onRetry: model.diagnosticContext?.retry,
                                onOpenHelp: { model.openHelp(HelpSection.forProtocol(model.diagnosticContext?.asset?.proto)) }
                            )
                        } else if let probe = model.probeDiagnostic(for: asset) {
                            // 探测失败只就地提示，不弹窗打断（规格 5.5）
                            DiagnosticCard(
                                diagnostic: probe,
                                onRetry: model.probeRetry(for: asset),
                                onOpenHelp: { model.openHelp(HelpSection.forProtocol(asset.proto)) }
                            )
                        }
                    } else {
                        CardContainer(title: L("详情")) {
                            Text(L("在左侧列表中选择一台机器，这里会显示它的状态与分辨率配置。"))
                                .font(.system(size: 11))
                                .foregroundStyle(Tokens.mutedForeground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    globalCard
                }
                .padding(Tokens.gapL)
            }
            Divider()
            footer
        }
        .background(Tokens.surfaceBackground)
        .onAppear(perform: syncFields)
        .onChange(of: model.inspectorPresented) { _, presented in
            if presented { syncFields() }
        }
    }

    // MARK: 头部 / 底部

    private var header: some View {
        HStack(spacing: Tokens.gapM) {
            if let asset {
                ProtocolBadge(proto: asset.proto)
                VStack(alignment: .leading, spacing: 0) {
                    Text(asset.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(asset.address)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Tokens.mutedForeground)
                }
            } else {
                Text(L("详情")).font(.system(size: 12, weight: .semibold))
            }
            Spacer(minLength: Tokens.gapS)
            Button {
                model.inspectorPresented = false
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help(L("收起详情面板"))
            .accessibilityLabel(L("收起详情面板"))
        }
        .padding(.horizontal, Tokens.gapL)
        .padding(.vertical, Tokens.gapM)
    }

    private var footer: some View {
        Button {
            save()
        } label: {
            Label(L("保存设置"), systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut("s", modifiers: .command)
        .padding(Tokens.gapL)
    }

    // MARK: 窗口尺寸快速配置（RDP 分辨率 / SSH 窗口大小同构）

    /// SSH 资产显示「窗口大小」，RDP / VNC 显示「分辨率快速配置」
    @ViewBuilder
    private func sizeCard(for asset: Asset) -> some View {
        let isSSH = asset.proto == .ssh
        CardContainer(title: isSSH ? L("窗口大小") : L("分辨率快速配置")) {
            VStack(alignment: .leading, spacing: Tokens.gapM) {
                HStack(spacing: Tokens.gapS) {
                    TextField(L("宽"), text: $widthText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 68)
                        .multilineTextAlignment(.trailing)
                    Text("×").foregroundStyle(Tokens.mutedForeground)
                    TextField(L("高"), text: $heightText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 68)
                        .multilineTextAlignment(.trailing)
                    Spacer(minLength: 0)
                }

                HStack(spacing: Tokens.gapS) {
                    preset(L("1/4 屏")) { applyScreenPreset(columns: 2, rows: 2) }
                    preset(L("1/6 屏")) { applyScreenPreset(columns: 3, rows: 2) }
                    preset(L("1/9 屏")) { applyScreenPreset(columns: 3, rows: 3) }
                }
                HStack(spacing: Tokens.gapS) {
                    preset(L("左右一分二")) { applyScreenPreset(columns: 2, rows: 1) }
                    preset(L("上下一分二")) { applyScreenPreset(columns: 1, rows: 2) }
                }
                HStack(spacing: Tokens.gapS) {
                    preset(L("恢复默认")) {
                        applyPreset(
                            width: isSSH ? AppSettings.defaultSSHWindowWidth : 1920,
                            height: isSSH ? AppSettings.defaultSSHWindowHeight : 1080
                        )
                    }
                }

                FieldHint(
                    text: isSSH
                        ? L("作为 SSH 独立窗口的初始尺寸；留空或为 0 时按「资产绑定的模板 → 默认 1000 × 640」解析。")
                        : L("仅作用于可自定义分辨率的 RDP 会话；其他协议忽略此设置。")
                )
            }
        }
    }

    /// 按屏幕尺寸换算预设：屏宽 / 横向切分数 × 屏高 / 纵向切分数
    private func applyScreenPreset(columns: Int, rows: Int) {
        let screen = NSScreen.main?.frame.size ?? NSSize(width: 1920, height: 1080)
        applyPreset(
            width: Int(screen.width) / max(columns, 1),
            height: Int(screen.height) / max(rows, 1)
        )
    }

    private func preset(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }

    // MARK: 只读状态

    /// 只展示属于当前选中资产的诊断，避免把上一台机器的失败原因显示在别的机器下。
    /// 无归属（如云端同步失败）的全局诊断仍然展示。
    private func connectionDiagnostic(for asset: Asset) -> Diagnostic? {
        guard let context = model.diagnosticContext else { return nil }
        if let target = context.asset, target.id != asset.id { return nil }
        return model.lastDiagnostic
    }

    private func statusCard(for asset: Asset) -> some View {
        CardContainer(title: L("状态")) {
            VStack(alignment: .leading, spacing: Tokens.gapS) {
                statusRow(L("到期预警"), value: asset.expiryState.text, tone: asset.expiryState.isWarning ? Tokens.warning : Tokens.primaryForeground)
                statusRow(
                    L("最后检测"),
                    value: model.probeResults[asset.id]?.summary ?? L("未检测"),
                    tone: Tokens.primaryForeground
                )
                statusRow(L("协议"), value: asset.proto.title, tone: Tokens.primaryForeground)
                statusRow(L("地址"), value: asset.address, tone: Tokens.primaryForeground, monospaced: true)
            }
        }
    }

    private func statusRow(_ label: String, value: String, tone: Color, monospaced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: Tokens.gapM) {
            FormLabel(text: label)
                .frame(width: 72, alignment: .leading)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 11, design: monospaced ? .monospaced : .default))
                .foregroundStyle(tone)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 全局项

    private var globalCard: some View {
        CardContainer(title: L("全局设置")) {
            VStack(alignment: .leading, spacing: Tokens.gapM) {
                HStack(spacing: Tokens.gapS) {
                    FormLabel(text: L("探测间隔（秒）"))
                    Spacer(minLength: 0)
                    TextField("", text: $probeIntervalText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                    Text(L("0 表示关闭")).font(.system(size: 11)).foregroundStyle(Tokens.subtleForeground)
                }
                FieldHint(text: ParamHelp.probeInterval)

                Toggle(L("记住密码"), isOn: rememberBinding)
                    .toggleStyle(.checkbox)
                FieldHint(text: ParamHelp.rememberPassword)
            }
        }
    }

    private var rememberBinding: Binding<Bool> {
        Binding(
            get: { model.settings.rememberPassword },
            set: { model.settings.rememberPassword = $0 }
        )
    }

    // MARK: 读写

    private func syncFields() {
        if let asset, asset.proto == .ssh {
            // SSH：展示当前生效的窗口尺寸（资产 → 模板 → 默认）
            let size = model.resolveSSHWindowSize(asset)
            widthText = "\(size.width)"
            heightText = "\(size.height)"
        } else {
            widthText = "\(model.settings.displayWidth)"
            heightText = "\(model.settings.displayHeight)"
        }
        probeIntervalText = "\(model.settings.probeInterval)"
    }

    private func applyPreset(width: Int, height: Int) {
        let clampedWidth = min(max(width, 320), 7680)
        let clampedHeight = min(max(height, 240), 4320)
        widthText = "\(clampedWidth)"
        heightText = "\(clampedHeight)"
    }

    private func intValue(_ text: String) -> Int {
        Int(text.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private func save() {
        let width = min(max(intValue(widthText), 320), 7680)
        let height = min(max(intValue(heightText), 240), 4320)
        if let asset, asset.proto == .ssh {
            // SSH 窗口尺寸写入资产自身配置（优先级最高的一层）
            var updated = asset
            updated.sshWindowWidth = width
            updated.sshWindowHeight = height
            model.upsert(updated)
        } else {
            model.settings.displayWidth = width
            model.settings.displayHeight = height
        }
        // 低于最小间隔会被抬到最小间隔：探测过密会导致本机 IP 被目标拉黑
        model.settings.probeInterval = AppSettings.normalizeProbeInterval(intValue(probeIntervalText))
        syncFields()
        model.saveSettings()
        model.setStatus(L("设置已保存"), kind: .success)
    }
}
