import SwiftUI
import AppKit

/// 资产编辑：新增 / 编辑连接目标；选协议即动态显隐相关字段
struct AssetEditorView: View {
    var request: EditorRequest

    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// 编辑中的副本：保存前不动原资产
    @State private var draft: Asset
    @State private var password: String = ""
    @State private var passphrase: String = ""

    init(request: EditorRequest) {
        self.request = request
        _draft = State(initialValue: request.asset)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView { form }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            bottomBar
        }
        .frame(width: 620, height: 660)
        .onAppear {
            password = model.password(for: request.asset) ?? ""
        }
    }

    // MARK: - 头部 / 底部

    private var header: some View {
        HStack(spacing: Tokens.gapM) {
            Text(request.isNew ? L("新增资产") : L("编辑资产"))
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            if !draft.host.isEmpty {
                Text(draft.address)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Tokens.mutedForeground)
            }
        }
        .padding(.horizontal, Tokens.gapXL)
        .padding(.vertical, Tokens.gapL)
    }

    private var bottomBar: some View {
        HStack(spacing: Tokens.gapM) {
            Spacer()
            Button(L("取消")) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(L("保存")) { save() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!isValid)
        }
        .padding(.horizontal, Tokens.gapXL)
        .padding(.vertical, Tokens.gapL)
    }

    // MARK: - 表单

    private var form: some View {
        VStack(alignment: .leading, spacing: Tokens.gapL) {
            CardContainer(title: L("基本信息")) {
                VStack(alignment: .leading, spacing: Tokens.gapM) {
                    fieldRow(L("名称")) {
                        TextField(L("资产名称"), text: $draft.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    fieldRow(L("分组")) {
                        HStack(spacing: Tokens.gapS) {
                            TextField(L("分组（可输入新建）"), text: $draft.group)
                                .textFieldStyle(.roundedBorder)
                            Menu(L("选择分组")) {
                                ForEach(model.groups, id: \.name) { group in
                                    Button(group.name.isEmpty ? L("未分组") : group.name) {
                                        draft.group = group.name
                                    }
                                }
                            }
                            .fixedSize()
                        }
                    }

                    fieldRow(L("负责人")) {
                        TextField(L("负责人"), text: $draft.owner)
                            .textFieldStyle(.roundedBorder)
                    }

                    fieldRow(L("协议")) {
                        Picker("", selection: $draft.proto) {
                            ForEach(RemoteProtocol.allCases) { proto in
                                Text(proto.title).tag(proto)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        // 切换协议：端口仍是上一协议默认值时自动跟随新协议默认端口
                        .onChange(of: draft.proto) { oldValue, newValue in
                            if draft.port == oldValue.defaultPort {
                                draft.port = newValue.defaultPort
                            }
                        }
                    }

                    fieldRow(L("主机")) {
                        VStack(alignment: .leading, spacing: Tokens.gapXS) {
                            TextField(L("主机地址或域名"), text: $draft.host)
                                .textFieldStyle(.roundedBorder)
                            if !isHostValid {
                                FieldHint(text: L("主机不能为空"), isError: true)
                            }
                        }
                    }

                    fieldRow(L("端口")) {
                        VStack(alignment: .leading, spacing: Tokens.gapXS) {
                            TextField(L("端口"), value: $draft.port, format: .number.grouping(.never))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 110)
                            if !isPortValid {
                                FieldHint(text: L("端口需在 1–65535 之间"), isError: true)
                            }
                        }
                    }

                    fieldRow(L("连接方案模板")) {
                        Picker("", selection: $draft.templateID) {
                            Text(L("不使用模板")).tag(Optional<UUID>.none)
                            ForEach(model.templates) { template in
                                Text(template.name).tag(Optional(template.id))
                            }
                        }
                        .labelsHidden()
                    }
                }
            }

            CardContainer(title: L("认证")) {
                VStack(alignment: .leading, spacing: Tokens.gapM) {
                    fieldRow(L("用户名")) {
                        TextField(L("用户名"), text: $draft.username)
                            .textFieldStyle(.roundedBorder)
                    }

                    fieldRow(L("密码")) {
                        SecureField(L("密码"), text: $password)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: Tokens.gapXS) {
                        Toggle(L("记住密码"), isOn: $draft.rememberPassword)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        FieldHint(text: ParamHelp.rememberPassword)
                    }

                    if draft.proto == .ssh {
                        Divider()

                        fieldRow(L("SSH 密钥路径")) {
                            HStack(spacing: Tokens.gapS) {
                                TextField(L("密钥文件路径"), text: $draft.sshKeyPath)
                                    .textFieldStyle(.roundedBorder)
                                Button(L("浏览…")) { browseKey() }
                                    .controlSize(.small)
                            }
                        }

                        fieldRow(L("SSH 密钥口令")) {
                            SecureField(L("密钥口令"), text: $passphrase)
                                .textFieldStyle(.roundedBorder)
                        }

                        fieldRow(L("跳板机")) {
                            TextField(L("user@host"), text: $draft.jumpHost)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

            CardContainer(title: L("业务信息")) {
                VStack(alignment: .leading, spacing: Tokens.gapM) {
                    VStack(alignment: .leading, spacing: Tokens.gapS) {
                        Toggle(L("设置到期日"), isOn: expiryEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        if draft.expiry != nil {
                            DatePicker("", selection: expiryBinding, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                    }

                    fieldRow(L("备注 1")) {
                        TextField(L("备注 1"), text: $draft.note1)
                            .textFieldStyle(.roundedBorder)
                    }
                    fieldRow(L("备注 2")) {
                        TextField(L("备注 2"), text: $draft.note2)
                            .textFieldStyle(.roundedBorder)
                    }
                    fieldRow(L("备注 3")) {
                        TextField(L("备注 3"), text: $draft.note3)
                            .textFieldStyle(.roundedBorder)
                    }
                    fieldRow(L("备注 4")) {
                        TextField(L("备注 4"), text: $draft.note4)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            if draft.proto == .rdp {
                CardContainer(title: L("重定向")) {
                    VStack(alignment: .leading, spacing: Tokens.gapM) {
                        Toggle(L("驱动器映射"), isOn: $draft.redirects.drives)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .help(ParamHelp.drives)
                        Toggle(L("音频"), isOn: $draft.redirects.audio)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .help(ParamHelp.audio)
                        Toggle(L("使用粘贴板"), isOn: $draft.redirects.clipboard)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .help(ParamHelp.clipboard)

                        Divider()

                        fieldRow(L("分辨率 宽 × 高")) {
                            HStack(spacing: Tokens.gapS) {
                                TextField("", value: $draft.displayWidth, format: .number.grouping(.never))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                Text("×").foregroundStyle(Tokens.mutedForeground)
                                TextField("", value: $draft.displayHeight, format: .number.grouping(.never))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                            FieldHint(text: L("留 0 表示跟随全局设置"))
                        }
                    }
                }
            }
        }
        .padding(Tokens.gapXL)
    }

    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.gapXS) {
            FormLabel(text: label)
            content()
        }
    }

    // MARK: - 校验

    private var isHostValid: Bool {
        !draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isPortValid: Bool {
        (1...65535).contains(draft.port)
    }

    private var isValid: Bool { isHostValid && isPortValid }

    private var expiryEnabled: Binding<Bool> {
        Binding(
            get: { draft.expiry != nil },
            set: { on in draft.expiry = on ? (draft.expiry ?? Date()) : nil }
        )
    }

    private var expiryBinding: Binding<Date> {
        Binding(
            get: { draft.expiry ?? Date() },
            set: { draft.expiry = $0 }
        )
    }

    // MARK: - 动作

    private func browseKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            draft.sshKeyPath = url.path
        }
    }

    private func save() {
        guard isValid else { return }
        model.upsert(draft)
        model.storePassword(password, for: draft, remember: draft.rememberPassword)
        if !passphrase.isEmpty {
            model.storeKeyPassphrase(passphrase, for: draft)
        }
        model.setStatus(
            L("已保存资产：{v}").replacingOccurrences(of: "{v}", with: draft.displayName),
            kind: .success
        )
        dismiss()
    }
}
