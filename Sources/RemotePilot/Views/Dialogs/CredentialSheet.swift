import SwiftUI
import AppKit

/// SSH 凭据补录：认证失败时弹出一次，输入后引导重连
struct CredentialSheet: View {
    var request: CredentialRequest

    @EnvironmentObject var model: AppModel

    @State private var username: String
    @State private var password: String
    @State private var keyPath: String
    @State private var passphrase: String
    @State private var remember: Bool = true

    init(request: CredentialRequest) {
        self.request = request
        _username = State(initialValue: request.asset.username)
        _password = State(initialValue: "")
        _keyPath = State(initialValue: request.asset.sshKeyPath)
        _passphrase = State(initialValue: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            VStack(alignment: .leading, spacing: Tokens.gapL) {
                if let message = request.failureMessage {
                    failureBlock(message)
                    FieldHint(text: L("本对话框每次连接尝试只提示一次，避免认证失败时反复弹出。"))
                }
                fields
            }
            .padding(Tokens.gapL)
            Divider()
            footer
        }
        .frame(width: 460)
    }

    // MARK: - 头部 / 底部

    private var header: some View {
        HStack(spacing: Tokens.gapS) {
            ProtocolBadge(proto: request.asset.proto)
            Text(L("输入凭据"))
                .font(.system(size: 14, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, Tokens.gapL)
        .padding(.vertical, Tokens.gapL)
    }

    private var footer: some View {
        HStack(spacing: Tokens.gapM) {
            Spacer()
            Button(L("取消")) { model.credentialRequest = nil }
                .keyboardShortcut(.cancelAction)
            Button(L("保存并连接")) {
                model.submitCredential(
                    asset: request.asset,
                    username: username,
                    password: password,
                    keyPath: keyPath,
                    passphrase: passphrase,
                    remember: remember
                )
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!canSubmit)
        }
        .padding(.horizontal, Tokens.gapL)
        .padding(.vertical, Tokens.gapL)
    }

    // MARK: - 内容

    private func failureBlock(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.gapM) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Tokens.warning)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tokens.primaryForeground)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Tokens.gapM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous).fill(Tokens.warning.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous).stroke(Tokens.warning.opacity(0.5), lineWidth: 1))
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: Tokens.gapL) {
            fieldRow(L("用户名")) {
                TextField(L("用户名"), text: $username)
                    .textFieldStyle(.roundedBorder)
            }

            fieldRow(L("密码")) {
                SecureField(L("密码"), text: $password)
                    .textFieldStyle(.roundedBorder)
            }

            if request.asset.proto == .ssh {
                fieldRow(L("SSH 密钥路径")) {
                    HStack(spacing: Tokens.gapS) {
                        TextField(L("密钥文件路径"), text: $keyPath)
                            .textFieldStyle(.roundedBorder)
                        Button(L("浏览…")) { browseKey() }
                            .controlSize(.small)
                    }
                }

                fieldRow(L("密钥口令")) {
                    SecureField(L("密钥口令"), text: $passphrase)
                        .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: Tokens.gapXS) {
                Toggle(L("记住凭据"), isOn: $remember)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                FieldHint(text: ParamHelp.rememberPassword)
            }
        }
    }

    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.gapXS) {
            FormLabel(text: label)
            content()
        }
    }

    // MARK: - 校验 / 动作

    private var canSubmit: Bool {
        !username.isEmpty && !(password.isEmpty && keyPath.isEmpty)
    }

    private func browseKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            keyPath = url.path
        }
    }
}
