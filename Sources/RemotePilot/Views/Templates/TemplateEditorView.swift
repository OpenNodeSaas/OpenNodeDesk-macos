import SwiftUI

/// 模板编辑：新建 / 编辑连接方案模板
struct TemplateEditorView: View {
    var template: ConnectionTemplate
    var isNew: Bool

    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// 编辑中的副本：保存前不动原模板
    @State private var draft: ConnectionTemplate
    /// 名称非空校验的就地提示
    @State private var nameError = false

    init(template: ConnectionTemplate, isNew: Bool) {
        self.template = template
        self.isNew = isNew
        _draft = State(initialValue: template)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView { form }
            Divider()
            bottomBar
        }
        .frame(width: 480, height: 560)
    }

    // MARK: - 头部/底部

    private var header: some View {
        HStack {
            Text(isNew ? L("新建模板") : L("编辑模板"))
                .font(.system(size: 14, weight: .semibold))
            Spacer()
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
                .keyboardShortcut(.defaultAction)
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
                        VStack(alignment: .leading, spacing: Tokens.gapXS) {
                            TextField(L("模板名称"), text: $draft.name)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: draft.name) { _, newValue in
                                    if nameError && !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                                        nameError = false
                                    }
                                }
                            if nameError {
                                FieldHint(text: L("名称不能为空"), isError: true)
                            }
                        }
                    }

                    fieldRow(L("协议")) {
                        Picker("", selection: $draft.proto) {
                            ForEach(RemoteProtocol.allCases) { proto in
                                Text(proto.title).tag(proto)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        // 切换协议自动填该协议默认端口
                        .onChange(of: draft.proto) { _, newValue in
                            draft.port = newValue.defaultPort
                        }
                    }

                    fieldRow(L("端口")) {
                        TextField(L("端口"), value: $draft.port, format: .number.grouping(.never))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                    }

                    fieldRow(L("用户名")) {
                        TextField(L("用户名"), text: $draft.username)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            // 渐进披露：仅 RDP 显示显示与重定向
            if draft.proto == .rdp {
                CardContainer(title: L("显示与重定向")) {
                    VStack(alignment: .leading, spacing: Tokens.gapM) {
                        fieldRow(L("窗口模式")) {
                            HStack(spacing: Tokens.gapS) {
                                Picker("", selection: $draft.windowMode) {
                                    ForEach(WindowMode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .labelsHidden()
                                .fixedSize()
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Tokens.subtleForeground)
                                    .help(ParamHelp.windowMode)
                            }
                        }

                        fieldRow(L("色深")) {
                            HStack(spacing: Tokens.gapS) {
                                Picker("", selection: $draft.colorDepth) {
                                    ForEach(ColorDepth.allCases) { depth in
                                        Text(depth.title).tag(depth)
                                    }
                                }
                                .labelsHidden()
                                .fixedSize()
                                Text(L("{v} 位").replacingOccurrences(of: "{v}", with: "\(draft.colorDepth.rawValue)"))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Tokens.mutedForeground)
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Tokens.subtleForeground)
                                    .help(ParamHelp.colorDepth)
                            }
                        }

                        Divider()

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
                    }
                }
            }

            // 渐进披露：仅 SSH 显示 SSH 设置（窗口大小）
            if draft.proto == .ssh {
                CardContainer(title: L("SSH 设置")) {
                    VStack(alignment: .leading, spacing: Tokens.gapM) {
                        fieldRow(L("窗口大小")) {
                            VStack(alignment: .leading, spacing: Tokens.gapXS) {
                                HStack(spacing: Tokens.gapS) {
                                    TextField("", value: $draft.sshWindowWidth, format: .number.grouping(.never))
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                    Text("×").foregroundStyle(Tokens.mutedForeground)
                                    TextField("", value: $draft.sshWindowHeight, format: .number.grouping(.never))
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                }
                                FieldHint(text: L("宽 320–7680、高 240–4320；作为 SSH 独立窗口的初始尺寸。"))
                            }
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

    // MARK: - 保存

    private func save() {
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            nameError = true
            return
        }
        var toSave = draft
        toSave.name = trimmed
        toSave.updatedAt = Date()
        // SSH 窗口大小校验区间：宽 320–7680、高 240–4320
        if toSave.proto == .ssh {
            toSave.sshWindowWidth = min(max(toSave.sshWindowWidth, 320), 7680)
            toSave.sshWindowHeight = min(max(toSave.sshWindowHeight, 240), 4320)
        }
        model.upsertTemplate(toSave)
        model.templateEditRequest = nil
        model.setStatus(
            isNew
                ? L("已新建模板「{v}」").replacingOccurrences(of: "{v}", with: trimmed)
                : L("已保存模板「{v}」").replacingOccurrences(of: "{v}", with: trimmed),
            kind: .success
        )
        dismiss()
    }
}
