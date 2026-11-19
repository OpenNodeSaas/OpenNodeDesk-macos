import SwiftUI
import AppKit

/// 设置页：客户端配置（自帮助手册迁入）+ SSH 终端外观 + SSH 独立窗口
struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    @State private var rdpPath = ""
    @State private var rdpArgs = ""
    @State private var vncPath = ""
    @State private var vncArgs = ""
    @State private var sshArgs = ""

    @State private var fontSize: Double = 13
    @State private var colorScheme: SSHColorScheme = .dark
    @State private var independentWindow = false

    @State private var protectionEnabled = false
    @State private var protectionIdle = AppSettings.protectionDefaultIdleMinutes
    @State private var protectionPassword = ""
    @State private var protectionConfirm = ""
    @State private var protectionAutoWipe = false
    @State private var protectionError: String?

    private let maxContentWidth: CGFloat = 720

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.gapXL) {
                header
                clientConfigCard
                terminalAppearanceCard
                independentWindowCard
                protectionCard
                footer
            }
            .frame(maxWidth: maxContentWidth, alignment: .leading)
            .padding(Tokens.gapXXL)
            .frame(maxWidth: .infinity)
        }
        .background(Tokens.appBackground)
        .onAppear { syncFromSettings() }
    }

    // MARK: - 页首

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.gapS) {
            Text(L("设置")).font(.system(size: 22, weight: .bold))
            Text(L("承载客户端、SSH 终端外观与会话打开方式，保存后随本地配置持久化。"))
                .font(.system(size: 12))
                .foregroundStyle(Tokens.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 7.1 客户端配置

    private var clientConfigCard: some View {
        CardContainer(title: L("客户端配置")) {
            VStack(alignment: .leading, spacing: Tokens.gapL) {
                carrierBlock(.rdp, title: L("RDP 承载客户端"), path: $rdpPath)
                Divider()
                carrierBlock(.vnc, title: L("VNC 承载客户端"), path: $vncPath)
                Divider()
                argumentField(
                    title: L("RDP 附加参数"),
                    hint: L("以 .rdp 文件的附加键值行追加，每行一个键值对，如 desktopscale:i:150；留空则使用默认配置。"),
                    text: $rdpArgs
                )
                argumentField(
                    title: L("VNC 启动参数模板"),
                    hint: L("可用占位符：{host} {port} {display} {user} {password}，默认 {host}::{display}。"),
                    text: $vncArgs
                )
                argumentField(
                    title: L("SSH 附加参数"),
                    hint: L("追加到内置 ssh 命令的额外参数，以空格分隔，如 -o PubkeyAuthentication=no。"),
                    text: $sshArgs
                )
                HStack {
                    Button(L("恢复默认参数")) { restoreDefaults() }
                        .controlSize(.small)
                    Spacer()
                }
            }
        }
    }

    /// 承载客户端区块：当前解析结果 + 路径编辑 + 浏览/自动探测 + 实时状态
    private func carrierBlock(_ proto: RemoteProtocol, title: String, path: Binding<String>) -> some View {
        let resolved = ClientDetector.resolve(proto, preferredPath: path.wrappedValue)
        let usesURLScheme = isURLScheme(resolved)
        let status = carrierStatus(proto, resolved: resolved, path: path.wrappedValue)

        return VStack(alignment: .leading, spacing: Tokens.gapS) {
            HStack(spacing: Tokens.gapM) {
                FormLabel(text: title)
                Spacer()
                HStack(spacing: Tokens.gapXS) {
                    Circle().fill(status.color).frame(width: 7, height: 7)
                    Text(status.text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(status.color)
                }
            }

            HStack(spacing: Tokens.gapM) {
                Text(resolved?.name ?? L("未检测到"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(resolved == nil ? Tokens.mutedForeground : Tokens.primaryForeground)
                Spacer()
            }

            HStack(spacing: Tokens.gapM) {
                TextField(L("客户端路径"), text: path)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .disabled(usesURLScheme)
                Button(L("浏览…")) { browse(into: path) }.controlSize(.small)
                Button(L("自动探测")) { path.wrappedValue = ClientDetector.defaultPath(for: proto) }.controlSize(.small)
            }

            if usesURLScheme {
                FieldHint(text: L("使用系统内置屏幕共享，无需指定路径。"))
            }
        }
    }

    private func argumentField(title: String, hint: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Tokens.gapXS) {
            FormLabel(text: title)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
            FieldHint(text: hint)
        }
    }

    // MARK: - 7.2 SSH 终端外观

    private var terminalAppearanceCard: some View {
        CardContainer(title: L("SSH 终端外观")) {
            VStack(alignment: .leading, spacing: Tokens.gapL) {
                VStack(alignment: .leading, spacing: Tokens.gapXS) {
                    FormLabel(text: L("字体大小"))
                    HStack(spacing: Tokens.gapM) {
                        Slider(value: $fontSize, in: 9...28, step: 1)
                            .frame(maxWidth: 320)
                        Text("\(Int(fontSize))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Tokens.mutedForeground)
                            .frame(width: 32, alignment: .leading)
                        Spacer()
                    }
                }

                VStack(alignment: .leading, spacing: Tokens.gapXS) {
                    FormLabel(text: L("配色方案"))
                    HStack(spacing: Tokens.gapM) {
                        Picker("", selection: $colorScheme) {
                            ForEach(SSHColorScheme.allCases) { scheme in
                                Text(scheme.title).tag(scheme)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: 160)
                        schemePreview
                        Spacer()
                    }
                }

                FieldHint(text: L("以独立窗口或内嵌终端打开 SSH 时生效，新建会话即采用该外观。"))
            }
        }
    }

    /// 预览色块：背景/前景即时跟随所选方案
    private var schemePreview: some View {
        let background = Color(
            red: colorScheme.background.r, green: colorScheme.background.g, blue: colorScheme.background.b
        )
        let foreground = Color(
            red: colorScheme.foreground.r, green: colorScheme.foreground.g, blue: colorScheme.foreground.b
        )
        return Text("Aa 123")
            .font(.system(size: CGFloat(fontSize), design: .monospaced))
            .foregroundStyle(foreground)
            .padding(.horizontal, Tokens.gapL)
            .padding(.vertical, Tokens.gapS)
            .background(RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous).fill(background))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous)
                    .stroke(Tokens.softBorder, lineWidth: 1)
            )
    }

    // MARK: - 7.3 SSH 独立窗口

    private var independentWindowCard: some View {
        CardContainer(title: L("SSH 独立窗口")) {
            VStack(alignment: .leading, spacing: Tokens.gapXS) {
                Toggle(L("SSH 以独立窗口打开"), isOn: $independentWindow)
                    .toggleStyle(.switch)
                FieldHint(text: L("开启后双击 SSH 资产直接打开独立窗口，不加入工作台、不跳转工作台；关闭窗口即断开该会话。窗口尺寸按「资产 → 绑定模板 → 默认 1000 × 640」解析。"))
            }
        }
    }

    // MARK: - 7.4 保护口令（自动锁定）

    private var protectionCard: some View {
        CardContainer(title: L("保护口令（自动锁定）")) {
            VStack(alignment: .leading, spacing: Tokens.gapL) {
                VStack(alignment: .leading, spacing: Tokens.gapXS) {
                    Toggle(L("启用保护口令"), isOn: $protectionEnabled)
                        .toggleStyle(.switch)
                    FieldHint(text: L("开启后，应用在设定时长内无键鼠输入即自动锁定，启动时也需先解锁。"))
                }

                if protectionEnabled {
                    Divider()
                    idlePicker
                    Divider()
                    passwordFields
                    Divider()
                    autoWipeBlock
                    actions
                    riskBlock
                }

                if let protectionError {
                    FieldHint(text: protectionError, isError: true)
                }

                HStack {
                    Spacer()
                    Button(L("应用保护口令设置")) { saveProtection() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var idlePicker: some View {
        VStack(alignment: .leading, spacing: Tokens.gapXS) {
            FormLabel(text: L("空闲锁定时长"))
            HStack(spacing: Tokens.gapM) {
                Picker("", selection: $protectionIdle) {
                    ForEach(AppSettings.protectionIdleOptions, id: \.self) { minutes in
                        Text(L("{n} 分钟").replacingOccurrences(of: "{n}", with: "\(minutes)")).tag(minutes)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 160)
                Spacer()
            }
            FieldHint(text: L("从最后一次键鼠输入算起，超时即锁定；锁定后自动关闭所有子窗口与会话窗口。"))
        }
    }

    private var passwordFields: some View {
        let modifying = model.settings.hasProtectionCredential
        return VStack(alignment: .leading, spacing: Tokens.gapL) {
            fieldRow(modifying ? L("修改口令（留空则不修改）") : L("设置口令")) {
                SecureField(L("口令"), text: $protectionPassword)
                    .textFieldStyle(.roundedBorder)
            }
            fieldRow(L("确认口令")) {
                SecureField(L("再次输入口令"), text: $protectionConfirm)
                    .textFieldStyle(.roundedBorder)
                    .disabled(protectionPassword.isEmpty)
            }
            FieldHint(text: modifying
                ? L("修改口令后会换发一串新的恢复口令，旧的恢复口令随即作废。")
                : L("口令至少 4 位；设置成功后会生成一串恢复口令，请务必妥善保存。"))
        }
    }

    private var autoWipeBlock: some View {
        VStack(alignment: .leading, spacing: Tokens.gapXS) {
            Toggle(L("连续输错达上限后自动清空本地数据"), isOn: $protectionAutoWipe)
                .toggleStyle(.switch)
            FieldHint(text: L("关闭时：口令与恢复口令连续错误 5 次后仅提示，需手动确认清空；开启时：达上限后直接自动清空本地数据，且不可撤销。"))
        }
    }

    private var actions: some View {
        HStack(spacing: Tokens.gapM) {
            Button(L("立即锁定")) { model.lock() }
                .controlSize(.small)
                .disabled(!model.settings.hasProtectionCredential)
            Spacer()
        }
    }

    private var riskBlock: some View {
        HStack(alignment: .top, spacing: Tokens.gapS) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Tokens.warning)
            Text(protectionAutoWipe
                ? L("口令与恢复口令均只保存哈希、无法找回明文。忘记口令时只能用恢复口令重置；连续错误 5 次将自动清空本地数据。")
                : L("口令与恢复口令均只保存哈希、无法找回明文。忘记口令时只能用恢复口令重置；连续错误 5 次后只能清空本地数据。"))
                .font(.system(size: 11))
                .foregroundStyle(Tokens.primaryForeground)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Tokens.gapM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous).fill(Tokens.warning.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous).stroke(Tokens.warning.opacity(0.5), lineWidth: 1))
    }

    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.gapXS) {
            FormLabel(text: label)
            content()
        }
    }

    // MARK: - 底部保存

    private var footer: some View {
        HStack {
            Spacer()
            Button(L("保存")) { save() }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - 行为

    private func syncFromSettings() {
        rdpPath = model.settings.rdpClientPath
        rdpArgs = model.settings.rdpClientArgs
        vncPath = model.settings.vncClientPath
        vncArgs = model.settings.vncClientArgs
        sshArgs = model.settings.sshExtraArgs
        fontSize = Double(model.settings.sshTerminalFontSize)
        colorScheme = model.settings.sshColorScheme
        independentWindow = model.settings.sshUsesIndependentWindow
        protectionEnabled = model.settings.protectionEnabled
        protectionIdle = model.settings.protectionIdleMinutes
        protectionAutoWipe = model.settings.protectionAutoWipe
        protectionPassword = ""
        protectionConfirm = ""
        protectionError = nil
    }

    private func restoreDefaults() {
        rdpArgs = AppSettings.defaultRDPArgs
        vncArgs = AppSettings.defaultVNCArgs
        sshArgs = ""
    }

    private func save() {
        model.settings.rdpClientPath = rdpPath
        model.settings.rdpClientArgs = rdpArgs
        model.settings.vncClientPath = vncPath
        model.settings.vncClientArgs = vncArgs
        model.settings.sshExtraArgs = sshArgs
        model.settings.sshTerminalFontSize = Int(fontSize)
        model.settings.sshColorScheme = colorScheme
        model.settings.sshUsesIndependentWindow = independentWindow
        model.saveSettings()
        model.setStatus(L("设置已保存"), kind: .success)
    }

    /// 应用保护口令设置：启用且填了口令时校验并换发恢复口令；关闭时清除全部凭据
    private func saveProtection() {
        protectionError = nil

        guard protectionEnabled else {
            model.setProtection(enabled: false, idleMinutes: protectionIdle, autoWipe: protectionAutoWipe, newPassword: nil)
            protectionPassword = ""
            protectionConfirm = ""
            model.setStatus(L("保护口令已关闭"), kind: .success)
            return
        }

        let hasCredential = model.settings.hasProtectionCredential
        // 首次启用必须设置口令；已启用则口令留空表示仅调整时长
        if !hasCredential && protectionPassword.isEmpty {
            protectionError = L("请设置保护口令。")
            return
        }
        if !protectionPassword.isEmpty {
            if protectionPassword.count < 4 {
                protectionError = L("口令长度至少 4 位。")
                return
            }
            if protectionPassword != protectionConfirm {
                protectionError = L("两次输入的口令不一致。")
                return
            }
        }

        let newPassword = protectionPassword.isEmpty ? nil : protectionPassword
        let code = model.setProtection(enabled: true, idleMinutes: protectionIdle, autoWipe: protectionAutoWipe, newPassword: newPassword)
        protectionPassword = ""
        protectionConfirm = ""
        if let code {
            model.recoverySheet = RecoveryCodeRequest(code: code, reason: .created)
        }
        model.setStatus(L("保护口令设置已保存"), kind: .success)
    }

    private func browse(into path: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        panel.message = L("选择承载客户端（.app 或可执行文件）")
        if panel.runModal() == .OK, let url = panel.url {
            path.wrappedValue = url.path
        }
    }

    // MARK: - 状态判定

    private struct CarrierStatus {
        var text: String
        var color: Color
    }

    private func carrierStatus(_ proto: RemoteProtocol, resolved: CarrierClient?, path: String) -> CarrierStatus {
        if path.isEmpty {
            if let auto = ClientDetector.candidates(for: proto).first {
                return CarrierStatus(
                    text: L("已就绪（自动探测：{v}）").replacingOccurrences(of: "{v}", with: auto.name),
                    color: Tokens.success
                )
            }
            return CarrierStatus(text: L("未检测到，请安装或手动指定路径"), color: Tokens.warning)
        }
        if !ClientDetector.isValid(path: path) {
            return CarrierStatus(text: L("路径不存在"), color: Tokens.danger)
        }
        let name = resolved?.name ?? L("已指定")
        return CarrierStatus(
            text: L("已就绪（{v}）").replacingOccurrences(of: "{v}", with: name),
            color: Tokens.success
        )
    }

    private func isURLScheme(_ client: CarrierClient?) -> Bool {
        guard let kind = client?.kind else { return false }
        if case .urlScheme = kind { return true }
        return false
    }
}
