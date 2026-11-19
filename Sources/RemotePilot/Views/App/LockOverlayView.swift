import SwiftUI

/// 锁定覆盖层：空闲超时 / 启动 / 手动锁定后遮挡整个窗口，必须先验证口令。
/// 口令连续错误 5 次后仅保留「恢复口令」入口；恢复口令再错 5 次后只能清空本地数据。
struct LockOverlayView: View {
    @EnvironmentObject var model: AppModel

    private enum Step {
        case unlock          // 输入口令
        case recoveryCode    // 输入恢复口令
        case recoveryReset   // 用恢复口令校验通过后设置新口令
    }

    @State private var step: Step = .unlock
    @State private var password = ""
    @State private var recoveryInput = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showWipeConfirm = false
    @State private var shake = false
    @FocusState private var focus: Field?

    private enum Field { case password, recovery, newPassword, confirm }

    private var passwordExhausted: Bool { model.unlockAttempts >= AppSettings.protectionMaxAttempts }
    private var recoveryExhausted: Bool { model.recoveryAttempts >= AppSettings.protectionMaxAttempts }

    var body: some View {
        ZStack {
            Tokens.appBackground.ignoresSafeArea()
            card
                .frame(width: 460)
                .padding(Tokens.gapXXL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
        // 口令输入期间出现错误即轻微抖动，强化「不对」的反馈；尊重系统的减少动态效果
        .offset(x: shake ? -8 : 0)
        .animation(.default, value: shake)
        .onAppear { focus = .password }
    }

    // MARK: - 卡片

    private var card: some View {
        VStack(spacing: Tokens.gapXL) {
            icon
            heading
            content
            message
            actions
        }
        .padding(Tokens.gapXXL)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Tokens.surfaceBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Tokens.softBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
    }

    private var icon: some View {
        Image(systemName: step == .unlock ? "lock.shield" : "key.viewfinder")
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(Tokens.accent)
    }

    private var heading: some View {
        VStack(spacing: Tokens.gapS) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Tokens.primaryForeground)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Tokens.mutedForeground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .unlock: unlockField
        case .recoveryCode: recoveryField
        case .recoveryReset: resetFields
        }
    }

    private var unlockField: some View {
        secureInput(
            placeholder: L("请输入保护口令"),
            text: $password,
            field: .password,
            enabled: !passwordExhausted,
            onSubmit: submitUnlock
        )
    }

    private var recoveryField: some View {
        VStack(alignment: .leading, spacing: Tokens.gapS) {
            TextField(L("请输入恢复口令"), text: $recoveryInput)
                .textFieldStyle(.plain)
                .font(.system(size: 15, design: .monospaced))
                .multilineTextAlignment(.center)
                .textCase(.uppercase)
                .autocorrectionDisabled()
                .padding(.horizontal, Tokens.gapL)
                .frame(height: 40)
                .background(fieldStyle)
                .focused($focus, equals: .recovery)
                .onSubmit { submitRecoveryCode() }
                .disabled(recoveryExhausted)
            FieldHint(text: L("不区分大小写，可省略分隔符「-」。"), isError: recoveryExhausted)
        }
    }

    private var resetFields: some View {
        VStack(spacing: Tokens.gapM) {
            secureInput(
                placeholder: L("设置新口令"),
                text: $newPassword,
                field: .newPassword,
                enabled: true,
                onSubmit: { focus = .confirm }
            )
            secureInput(
                placeholder: L("再次输入新口令"),
                text: $confirmPassword,
                field: .confirm,
                enabled: true,
                onSubmit: submitReset
            )
            FieldHint(text: L("口令长度至少 4 位；设置后将换发一串新的恢复口令。"), isError: newMismatch)
        }
    }

    private var fieldStyle: some View {
        RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous)
            .fill(Tokens.fieldBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous)
                    .stroke(Tokens.softBorder, lineWidth: 1)
            )
    }

    private func secureInput(
        placeholder: String,
        text: Binding<String>,
        field: Field,
        enabled: Bool,
        onSubmit: @escaping () -> Void
    ) -> some View {
        SecureField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Tokens.gapL)
            .frame(height: 40)
            .background(fieldStyle)
            .focused($focus, equals: field)
            .disabled(!enabled)
            .onSubmit(onSubmit)
    }

    @ViewBuilder
    private var message: some View {
        if let error = model.unlockError {
            HStack(spacing: Tokens.gapS) {
                Image(systemName: "exclamationmark.circle.fill").font(.system(size: 12))
                Text(error).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Tokens.danger)
            .frame(maxWidth: .infinity, alignment: .center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var actions: some View {
        if step == .recoveryCode && recoveryExhausted {
            wipeActions
        } else {
            primaryAction
            secondaryAction
        }
    }

    private var primaryAction: some View {
        Button(primaryTitle, action: primarySubmit)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .keyboardShortcut(.defaultAction)
            .disabled(!canPrimarySubmit)
    }

    @ViewBuilder
    private var secondaryAction: some View {
        if step == .unlock {
            Button(L("忘记口令？使用恢复口令重置")) {
                step = .recoveryCode
                model.unlockError = nil
                DispatchQueue.main.async { focus = .recovery }
            }
            .buttonStyle(.link)
            .disabled(recoveryExhausted)
        } else if step == .recoveryReset {
            Button(L("返回口令解锁")) {
                step = .unlock
                model.unlockError = nil
                DispatchQueue.main.async { focus = .password }
            }
            .buttonStyle(.link)
        }
    }

    private var wipeActions: some View {
        VStack(spacing: Tokens.gapM) {
            Text(L("恢复口令也已连续错误，出于安全考虑只能清空本地数据后重新开始。"))
                .font(.system(size: 12))
                .foregroundStyle(Tokens.danger)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(L("清空本地数据…")) { showWipeConfirm = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Tokens.danger)
                .frame(maxWidth: .infinity)
        }
        .confirmationDialog(
            L("清空本地数据"),
            isPresented: $showWipeConfirm,
            titleVisibility: .visible
        ) {
            Button(L("清空并重新开始"), role: .destructive) { model.wipeLocalDataAndReset() }
            Button(L("取消"), role: .cancel) {}
        } message: {
            Text(L("将删除全部资产、模板与本地设置（系统钥匙串中的凭据一并清除），且不可撤销。"))
        }
    }

    // MARK: - 文案

    private var title: String {
        switch step {
        case .unlock: return L("已锁定")
        case .recoveryCode: return L("使用恢复口令")
        case .recoveryReset: return L("重置保护口令")
        }
    }

    private var subtitle: String {
        switch step {
        case .unlock where passwordExhausted:
            return L("口令已连续错误 5 次，请使用恢复口令重置后再解锁。")
        case .unlock:
            return L("应用因闲置已自动锁定，输入保护口令继续。")
        case .recoveryCode:
            return L("输入设置口令时生成的恢复口令，校验通过后可设置新口令。")
        case .recoveryReset:
            return L("恢复口令校验通过，请设置新的保护口令。")
        }
    }

    private var primaryTitle: String {
        switch step {
        case .unlock: return L("解锁")
        case .recoveryCode: return L("验证恢复口令")
        case .recoveryReset: return L("重置并解锁")
        }
    }

    private var canPrimarySubmit: Bool {
        switch step {
        case .unlock: return !password.isEmpty && !passwordExhausted
        case .recoveryCode: return !recoveryInput.isEmpty && !recoveryExhausted
        case .recoveryReset: return newPassword.count >= 4 && newPassword == confirmPassword
        }
    }

    private var newMismatch: Bool {
        !confirmPassword.isEmpty && newPassword != confirmPassword
    }

    // MARK: - 动作

    private func primarySubmit() {
        switch step {
        case .unlock: submitUnlock()
        case .recoveryCode: submitRecoveryCode()
        case .recoveryReset: submitReset()
        }
    }

    private func submitUnlock() {
        guard !password.isEmpty else { return }
        if model.unlock(password: password) {
            password = ""
        } else {
            password = ""
            triggerShake()
            focus = .password
        }
    }

    private func submitRecoveryCode() {
        guard !recoveryInput.isEmpty else { return }
        if model.verifyRecoveryCode(recoveryInput) {
            recoveryInput = ""
            newPassword = ""
            confirmPassword = ""
            step = .recoveryReset
            DispatchQueue.main.async { focus = .newPassword }
        } else {
            triggerShake()
            focus = .recovery
        }
    }

    private func submitReset() {
        guard newPassword.count >= 4, newPassword == confirmPassword else { return }
        if let code = model.resetPasswordWithRecovery(newPassword: newPassword) {
            model.recoverySheet = RecoveryCodeRequest(code: code, reason: .reset)
        }
        password = ""
        recoveryInput = ""
        newPassword = ""
        confirmPassword = ""
    }

    private func triggerShake() {
        shake = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { shake = false }
    }
}
