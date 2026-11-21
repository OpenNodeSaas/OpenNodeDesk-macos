import SwiftUI
import AppKit

/// 连接方案抽屉：套用模板 → 本次覆盖 → 当前生效参数预览（参数可解释）
struct PlanDrawer: View {
    var request: PlanRequest

    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var overrides = LaunchOverrides.none

    /// 始终读取资产的最新副本：在抽屉里改模板会立即持久化，头部与预览需随之刷新
    private var asset: Asset { model.asset(id: request.asset.id) ?? request.asset }

    // SSH 显示设置（写入资产自身的 SSH 独立窗口尺寸与 SSH 字段）
    @State private var sshWidthText = ""
    @State private var sshHeightText = ""
    @State private var sshPortText = ""
    @State private var sshKeyPath = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView { form }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(width: 580, height: 640)
        .onAppear {
            model.launchOverrides = overrides
            syncSSHFields()
        }
        .onChange(of: overrides) { _, newValue in
            model.launchOverrides = newValue
        }
    }

    // MARK: - 头部 / 底部

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.gapS) {
            HStack(spacing: Tokens.gapS) {
                ProtocolBadge(proto: request.asset.proto)
                Text(request.asset.displayName)
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(request.asset.address)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Tokens.mutedForeground)
            HStack(spacing: Tokens.gapS) {
                if let template = model.template(id: asset.templateID) {
                    SourceBadge(source: .template(template.name))
                    Text(L("参数来源：模板"))
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.mutedForeground)
                } else {
                    SourceBadge(source: .custom)
                    Text(L("参数来源：自定义"))
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.mutedForeground)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Tokens.gapXL)
        .padding(.vertical, Tokens.gapL)
    }

    private var footer: some View {
        HStack(spacing: Tokens.gapM) {
            Spacer()
            Button(L("取消")) {
                model.launchOverrides = .none
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            Button(L("连接")) {
                model.launchOverrides = overrides
                applySSHEditsThenConnect()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, Tokens.gapXL)
        .padding(.vertical, Tokens.gapL)
    }

    // MARK: - 内容

    private var form: some View {
        VStack(alignment: .leading, spacing: Tokens.gapL) {
            templateSection
            if request.asset.proto == .ssh {
                sshDisplaySection
            } else {
                overrideSection
            }
            previewSection
        }
        .padding(Tokens.gapXL)
    }

    // MARK: - SSH 显示设置（§5）

    private var sshDisplaySection: some View {
        CardContainer(title: L("显示设置")) {
            VStack(alignment: .leading, spacing: Tokens.gapM) {
                row(L("窗口大小")) {
                    HStack(spacing: Tokens.gapS) {
                        TextField("", text: $sshWidthText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 76)
                            .multilineTextAlignment(.trailing)
                        Text("×").foregroundStyle(Tokens.mutedForeground)
                        TextField("", text: $sshHeightText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 76)
                            .multilineTextAlignment(.trailing)
                    }
                }

                HStack(spacing: Tokens.gapS) {
                    presetButton(L("1/4 屏")) { applySSHPreset(columns: 2, rows: 2) }
                    presetButton(L("1/6 屏")) { applySSHPreset(columns: 3, rows: 2) }
                    presetButton(L("1/9 屏")) { applySSHPreset(columns: 3, rows: 3) }
                }
                HStack(spacing: Tokens.gapS) {
                    presetButton(L("左右一分二")) { applySSHPreset(columns: 2, rows: 1) }
                    presetButton(L("上下一分二")) { applySSHPreset(columns: 1, rows: 2) }
                    presetButton(L("恢复默认")) {
                        applySSHPreset(width: AppSettings.defaultSSHWindowWidth, height: AppSettings.defaultSSHWindowHeight)
                    }
                }

                FieldHint(text: L("窗口大小写入该资产的 SSH 独立窗口尺寸；未设置时按「模板 → 默认 1000 × 640」解析。"))

                Divider()

                row(L("SSH 端口")) {
                    TextField("", text: $sshPortText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                }

                row(L("用户名")) {
                    TextField(L("用户名"), text: usernameBinding)
                        .textFieldStyle(.roundedBorder)
                }

                row(L("密钥路径")) {
                    HStack(spacing: Tokens.gapS) {
                        TextField("", text: $sshKeyPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                        Button(L("浏览…")) { browseKey() }
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private func presetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }

    private func applySSHPreset(columns: Int, rows: Int) {
        let screen = NSScreen.main?.frame.size ?? NSSize(width: 1920, height: 1080)
        applySSHPreset(
            width: Int(screen.width) / max(columns, 1),
            height: Int(screen.height) / max(rows, 1)
        )
    }

    private func applySSHPreset(width: Int, height: Int) {
        sshWidthText = "\(min(max(width, 320), 7680))"
        sshHeightText = "\(min(max(height, 240), 4320))"
    }

    private func syncSSHFields() {
        let size = model.resolveSSHWindowSize(asset)
        sshWidthText = "\(size.width)"
        sshHeightText = "\(size.height)"
        sshPortText = "\(asset.port)"
        sshKeyPath = asset.sshKeyPath
    }

    private func browseKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.message = L("选择 SSH 私钥文件")
        if panel.runModal() == .OK, let url = panel.url {
            sshKeyPath = url.path
        }
    }

    /// SSH：把显示设置与 SSH 字段写回资产后再建连；其他协议直接建连
    private func applySSHEditsThenConnect() {
        guard request.asset.proto == .ssh else {
            model.connect(request.asset)
            return
        }
        var updated = asset
        updated.sshWindowWidth = min(max(Int(sshWidthText.trimmingCharacters(in: .whitespaces)) ?? 0, 320), 7680)
        updated.sshWindowHeight = min(max(Int(sshHeightText.trimmingCharacters(in: .whitespaces)) ?? 0, 240), 4320)
        if let port = Int(sshPortText.trimmingCharacters(in: .whitespaces)), port > 0 { updated.port = port }
        updated.sshKeyPath = sshKeyPath
        if let username = overrides.username { updated.username = username }
        model.upsert(updated)
        if let refreshed = model.asset(id: updated.id) { model.connect(refreshed) }
    }

    private var templateSection: some View {
        CardContainer(title: L("模板套用")) {
            VStack(alignment: .leading, spacing: Tokens.gapM) {
                Picker("", selection: templateBinding) {
                    Text(L("不使用模板")).tag(Optional<UUID>.none)
                    ForEach(model.templates) { template in
                        Text(template.name).tag(Optional(template.id))
                    }
                }
                .labelsHidden()

                FieldHint(text: L("选择模板即为该资产绑定并保存；下方预览与后续连接立即按模板解析。"))

                HStack(spacing: Tokens.gapM) {
                    Button(L("套用到本次")) { applyTemplate() }
                        .controlSize(.small)
                        .disabled(asset.templateID == nil)
                    Button(L("清空覆盖")) { overrides = .none }
                        .controlSize(.small)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous)
                .stroke(request.highlightTemplate ? Tokens.accent : Color.clear,
                        lineWidth: request.highlightTemplate ? 2 : 0)
        )
    }

    /// 选择即绑定：写入资产 templateID 并持久化；「不使用模板」为解绑
    private var templateBinding: Binding<UUID?> {
        Binding(
            get: { asset.templateID },
            set: { model.assignTemplate($0, to: [asset.id]) }
        )
    }

    private var overrideSection: some View {
        CardContainer(title: L("本次连接覆盖")) {
            VStack(alignment: .leading, spacing: Tokens.gapM) {
                row(L("窗口模式"), help: ParamHelp.windowMode) {
                    Picker("", selection: $overrides.windowMode) {
                        Text(L("跟随默认")).tag(Optional<WindowMode>.none)
                        ForEach(WindowMode.allCases) { mode in
                            Text(mode.title).tag(Optional(mode))
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                row(L("色深"), help: ParamHelp.colorDepth) {
                    Picker("", selection: $overrides.colorDepth) {
                        Text(L("跟随默认")).tag(Optional<ColorDepth>.none)
                        ForEach(ColorDepth.allCases) { depth in
                            Text(depth.title).tag(Optional(depth))
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                Divider()

                Toggle(L("驱动器映射"), isOn: redirectBinding(\.drives))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help(ParamHelp.drives)
                Toggle(L("音频"), isOn: redirectBinding(\.audio))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help(ParamHelp.audio)
                Toggle(L("使用粘贴板"), isOn: redirectBinding(\.clipboard))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help(ParamHelp.clipboard)

                Divider()

                row(L("分辨率 宽 × 高")) {
                    HStack(spacing: Tokens.gapS) {
                        TextField("", value: widthBinding, format: .number.grouping(.never))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("×").foregroundStyle(Tokens.mutedForeground)
                        TextField("", value: heightBinding, format: .number.grouping(.never))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }

                row(L("用户名")) {
                    TextField(L("用户名"), text: usernameBinding)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var previewSection: some View {
        CardContainer(title: L("当前生效参数预览")) {
            VStack(alignment: .leading, spacing: Tokens.gapS) {
                ForEach(model.effectiveParameters(for: asset).rows) { item in
                    HStack(spacing: Tokens.gapM) {
                        Text(item.key)
                            .font(.system(size: 11))
                            .foregroundStyle(Tokens.mutedForeground)
                            .frame(width: 100, alignment: .leading)
                        Text(item.value)
                            .font(.system(size: 12))
                            .foregroundStyle(Tokens.primaryForeground)
                        Spacer(minLength: 0)
                        SourceBadge(source: item.source)
                    }
                }
                FieldHint(text: L("徽章表示参数来源：自定义 / 模板 / 默认。"))
            }
        }
    }

    private func row<Content: View>(_ label: String, help: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: Tokens.gapM) {
            HStack(spacing: Tokens.gapS) {
                FormLabel(text: label)
                if let help {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.subtleForeground)
                        .help(help)
                }
            }
            .frame(width: 140, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }

    // MARK: - 绑定

    private func redirectBinding(_ keyPath: WritableKeyPath<RedirectionOptions, Bool>) -> Binding<Bool> {
        Binding(
            get: { (overrides.redirects ?? RedirectionOptions())[keyPath: keyPath] },
            set: { newValue in
                var redirects = overrides.redirects ?? RedirectionOptions()
                redirects[keyPath: keyPath] = newValue
                overrides.redirects = redirects
            }
        )
    }

    private var widthBinding: Binding<Int> {
        Binding(
            get: { overrides.width ?? 0 },
            set: { overrides.width = $0 == 0 ? nil : $0 }
        )
    }

    private var heightBinding: Binding<Int> {
        Binding(
            get: { overrides.height ?? 0 },
            set: { overrides.height = $0 == 0 ? nil : $0 }
        )
    }

    private var usernameBinding: Binding<String> {
        Binding(
            get: { overrides.username ?? "" },
            set: { overrides.username = $0.isEmpty ? nil : $0 }
        )
    }

    // MARK: - 动作

    private func applyTemplate() {
        guard let template = model.template(id: asset.templateID) else { return }
        overrides.windowMode = template.windowMode
        overrides.colorDepth = template.colorDepth
        overrides.redirects = template.redirects
    }
}
