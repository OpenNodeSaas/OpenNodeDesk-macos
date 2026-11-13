import SwiftUI
import AppKit

// 待替换：正式发布前替换为真实开源仓库地址
private let repositoryURL = "https://github.com/remotepilot/remotepilot"
// 待替换：正式发布前替换为真实支持邮箱
private let supportEmail = "support@remotepilot.dev"

/// 意见反馈对话框：开源仓库 / 邮件地址 + 可复制的完整反馈文本兜底
struct FeedbackSheet: View {
    @EnvironmentObject var model: AppModel

    @State private var detail = ""
    @State private var copiedFullText = false
    @State private var copiedField: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.gapXL) {
            header
            contactBlock
            Divider()
            fallbackBlock
            footer
        }
        .padding(Tokens.gapXXL)
        .frame(width: 560)
        .background(Tokens.surfaceBackground)
    }

    // MARK: - 页首

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.gapS) {
            Text(L("意见反馈")).font(.system(size: 18, weight: .bold))
            Text(L("欢迎通过开源仓库或邮件反馈问题与建议；若本机缺少邮件客户端，可复制下方全文后自行发送。"))
                .font(.system(size: 12))
                .foregroundStyle(Tokens.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 联系方式

    private var contactBlock: some View {
        VStack(alignment: .leading, spacing: Tokens.gapL) {
            contactRow(
                title: L("开源仓库"),
                value: repositoryURL,
                open: { openURL(repositoryURL) },
                copy: { copyText(repositoryURL, tag: "repo") },
                copied: copiedField == "repo"
            )
            contactRow(
                title: L("支持邮箱"),
                value: supportEmail,
                open: { openURL("mailto:\(supportEmail)") },
                copy: { copyText(supportEmail, tag: "mail") },
                copied: copiedField == "mail"
            )
        }
    }

    private func contactRow(title: String, value: String, open: @escaping () -> Void, copy: @escaping () -> Void, copied: Bool) -> some View {
        VStack(alignment: .leading, spacing: Tokens.gapXS) {
            FormLabel(text: title)
            HStack(spacing: Tokens.gapM) {
                Text(value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Tokens.primaryForeground)
                    .textSelection(.enabled)
                Spacer()
                Button(L("打开"), action: open).controlSize(.small)
                Button(copied ? L("已复制") : L("复制"), action: copy).controlSize(.small)
            }
        }
    }

    // MARK: - 兜底文本

    private var fallbackBlock: some View {
        VStack(alignment: .leading, spacing: Tokens.gapM) {
            FormLabel(text: L("反馈内容（可复制全文）"))
            TextEditor(text: $detail)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(Tokens.gapS)
                .frame(height: 96)
                .background(RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous).fill(Tokens.fieldBackground))
                .overlay(RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous).stroke(Tokens.softBorder, lineWidth: 1))
            FieldHint(text: L("在上方填写问题描述，再点「复制全文」；下面已自动附带产品版本与系统版本。"))

            ScrollView {
                Text(fullText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Tokens.mutedForeground)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 120)
            .padding(Tokens.gapS)
            .background(RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous).fill(Tokens.fieldBackground))
            .overlay(RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous).stroke(Tokens.softBorder, lineWidth: 1))
        }
    }

    private var footer: some View {
        HStack(spacing: Tokens.gapM) {
            Button(copiedFullText ? L("已复制全文") : L("复制全文")) {
                copyText(fullText, tag: nil)
                copiedFullText = true
            }
            .buttonStyle(.borderedProminent)
            Spacer()
            Button(L("关闭")) { model.showFeedbackSheet = false }
        }
    }

    // MARK: - 数据

    private var fullText: String {
        """
        \(L("【意见反馈】"))
        \(L("产品"))：RemotePilot \(appVersion)
        \(L("系统"))：\(ProcessInfo.processInfo.operatingSystemVersionString)

        \(L("问题描述"))
        \(detail.isEmpty ? L("（请在此填写复现步骤、期望与实际结果）") : detail)
        """
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        switch (short, build) {
        case let (s?, b?): return "\(s) (\(b))"
        case let (s?, nil): return s
        default: return "—"
        }
    }

    // MARK: - 行为

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    private func copyText(_ string: String, tag: String?) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        guard let tag else { return }
        copiedField = tag
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedField == tag { copiedField = nil }
        }
    }
}
