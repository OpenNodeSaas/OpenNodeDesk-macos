import SwiftUI
import AppKit

/// 恢复口令展示卡片：口令设置 / 修改后、以及用恢复口令重置后各展示一次，明文只出现这一回。
struct RecoveryCodeSheet: View {
    var request: RecoveryCodeRequest

    @EnvironmentObject var model: AppModel

    @State private var copied = false

    private var groups: [String] {
        request.code.split(separator: "-").map(String.init)
    }

    var body: some View {
        VStack(spacing: Tokens.gapXL) {
            VStack(spacing: Tokens.gapS) {
                Image(systemName: "key.fill")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Tokens.accent)
                Text(L("你的恢复口令"))
                    .font(.system(size: 20, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.mutedForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            codeBlock

            warningBlock

            HStack(spacing: Tokens.gapM) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(request.code, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Label(copied ? L("已复制") : L("复制"), systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                Button(L("我已妥善保存")) { model.recoverySheet = nil }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Tokens.gapXXL)
        .frame(width: 520)
        .onDisappear { model.recoverySheet = nil }
    }

    private var subtitle: String {
        switch request.reason {
        case .created:
            return L("保护口令已设置。请把恢复口令保存在安全处以备忘记口令时重置。")
        case .reset:
            return L("保护口令已重置。旧的恢复口令已作废，请保存这串新的恢复口令。")
        }
    }

    private var codeBlock: some View {
        HStack(spacing: Tokens.gapM) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                Text(group)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Tokens.primaryForeground)
                    .padding(.horizontal, Tokens.gapM)
                    .padding(.vertical, Tokens.gapM)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous)
                            .fill(Tokens.fieldBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous)
                            .stroke(Tokens.softBorder, lineWidth: 1)
                    )
                    .textSelection(.enabled)
            }
        }
    }

    private var warningBlock: some View {
        HStack(alignment: .top, spacing: Tokens.gapS) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Tokens.warning)
            Text(L("恢复口令仅显示这一次，关闭后无法再次查看；若不慎遗失，忘记口令时将只能清空本地数据。"))
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
}
