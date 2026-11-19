import SwiftUI

// MARK: - 徽章

struct ProtocolBadge: View {
    let proto: RemoteProtocol

    var body: some View {
        Text(proto.badge)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous).fill(Tokens.protoColor(proto)))
            .accessibilityLabel(L("协议：{v}").replacingOccurrences(of: "{v}", with: proto.title))
    }
}

struct StatusBadge: View {
    let result: ProbeResult
    var compact: Bool = false

    private var status: ProbeStatus { result.status }

    var body: some View {
        HStack(spacing: Tokens.gapXS) {
            Circle().fill(Tokens.statusColor(status)).frame(width: 7, height: 7)
            // 状态不只靠颜色区分：始终带文字
            Text(status.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(status == .unknown ? Tokens.mutedForeground : Tokens.statusColor(status))
            if !compact, status == .reachable, let latency = result.latencyMs {
                Text("\(latency)ms").font(.system(size: 11)).foregroundStyle(Tokens.subtleForeground).monospacedDigit()
            }
        }
        .help(result.summary)
    }
}

struct SessionStateDot: View {
    let state: SessionState

    var body: some View {
        HStack(spacing: Tokens.gapXS) {
            Circle()
                .fill(Tokens.sessionStateColor(state))
                .frame(width: 7, height: 7)
                .overlay(Circle().stroke(Tokens.sessionStateColor(state).opacity(0.25), lineWidth: 3))
            Text(state.title).font(.system(size: 11)).foregroundStyle(Tokens.mutedForeground)
        }
    }
}

struct SourceBadge: View {
    let source: ParamSource

    var body: some View {
        Text(source.label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Tokens.sourceColor(source))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Tokens.sourceColor(source).opacity(0.12))
            )
    }
}

// MARK: - 容器

struct CardContainer<Content: View>: View {
    var title: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.gapM) {
            if let title {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Tokens.mutedForeground)
            }
            content()
        }
        .padding(Tokens.gapL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous).fill(Tokens.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous).stroke(Tokens.softBorder, lineWidth: 1))
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Tokens.gapL) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Tokens.subtleForeground)
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Tokens.mutedForeground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.borderedProminent).controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Tokens.gapXXL)
    }
}

// MARK: - 诊断卡（失败可解释可恢复）

struct DiagnosticCard: View {
    let diagnostic: Diagnostic
    var onRetry: (() -> Void)?
    var onOpenHelp: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.gapM) {
            HStack(spacing: Tokens.gapS) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Tokens.warning)
                Text(L("就地诊断")).font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            Text(diagnostic.cause)
                .font(.system(size: 12))
                .foregroundStyle(Tokens.primaryForeground)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Tokens.gapXS) {
                Text(L("检查建议")).font(.system(size: 11, weight: .semibold)).foregroundStyle(Tokens.mutedForeground)
                ForEach(Array(diagnostic.suggestions.enumerated()), id: \.offset) { _, suggestion in
                    HStack(alignment: .top, spacing: Tokens.gapS) {
                        Text("•").foregroundStyle(Tokens.mutedForeground)
                        Text(suggestion)
                            .font(.system(size: 11))
                            .foregroundStyle(Tokens.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if diagnostic.isProbeRelated {
                Text(L("探测失败不等于无法连接：目标可能只屏蔽了端口探测。"))
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.mutedForeground)
            }

            HStack(spacing: Tokens.gapM) {
                if let onRetry {
                    Button(L("重试"), action: onRetry).buttonStyle(.borderedProminent).controlSize(.small)
                }
                if let onOpenHelp {
                    Button(L("查看帮助"), action: onOpenHelp).buttonStyle(.link).controlSize(.small)
                }
            }
        }
        .padding(Tokens.gapL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous).fill(Tokens.warning.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous).stroke(Tokens.warning.opacity(0.5), lineWidth: 1))
    }
}

// MARK: - 分组徽章

struct GroupBadgeBar: View {
    let groups: [(name: String, count: Int)]
    let activeGroup: String?
    let onSelect: (String?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.gapS) {
                chip(name: L("全部"), count: groups.reduce(0) { $0 + $1.count }, isActive: activeGroup == nil) {
                    onSelect(nil)
                }
                ForEach(groups, id: \.name) { group in
                    chip(name: group.name.isEmpty ? L("未分组") : group.name, count: group.count, isActive: activeGroup == group.name) {
                        onSelect(activeGroup == group.name ? nil : group.name)
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func chip(name: String, count: Int, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.gapXS) {
                Text(name).font(.system(size: 11, weight: isActive ? .semibold : .regular))
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isActive ? Color.white.opacity(0.9) : Tokens.mutedForeground)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(isActive ? Color.white.opacity(0.22) : Tokens.softBorder))
            }
            .padding(.horizontal, Tokens.gapM)
            .padding(.vertical, 3)
            .background(Capsule().fill(isActive ? Tokens.accent : Tokens.surfaceBackground))
            .overlay(Capsule().stroke(isActive ? Color.clear : Tokens.softBorder, lineWidth: 1))
            .foregroundStyle(isActive ? Color.white : Tokens.primaryForeground)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(count > 0 ? L("{v} 台机器").replacingOccurrences(of: "{v}", with: "\(count)") : "")
    }
}

// MARK: - 到期预警汇总条

struct ExpirySummaryBar: View {
    let warningAssets: [Asset]
    @Binding var expanded: Bool
    var onReveal: (Asset) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                // 尊重系统「减少动态效果」：开启时直接切换，不做过渡动画
                if reduceMotion {
                    expanded.toggle()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
                }
            } label: {
                HStack(spacing: Tokens.gapM) {
                    Image(systemName: "clock.badge.exclamationmark.fill").foregroundStyle(Tokens.warning)
                    Text(L("凭证到期预警：{n} 台机器临期或已过期").replacingOccurrences(of: "{n}", with: "\(warningAssets.count)"))
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(expanded ? L("收起明细") : L("展开明细")).font(.system(size: 11)).foregroundStyle(Tokens.mutedForeground)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.system(size: 11)).foregroundStyle(Tokens.mutedForeground)
                }
                .padding(.horizontal, Tokens.gapL)
                .padding(.vertical, Tokens.gapM)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Divider()
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(warningAssets) { asset in
                            HStack(spacing: Tokens.gapM) {
                                ProtocolBadge(proto: asset.proto)
                                Text(asset.displayName).font(.system(size: 12))
                                Text(asset.address).font(.system(size: 11, design: .monospaced)).foregroundStyle(Tokens.mutedForeground)
                                Spacer()
                                Text(asset.owner.isEmpty ? "—" : asset.owner).font(.system(size: 11)).foregroundStyle(Tokens.mutedForeground)
                                Text(asset.expiryState.text).font(.system(size: 11, weight: .medium)).foregroundStyle(asset.expiryState.isWarning ? Tokens.warning : Tokens.mutedForeground)
                                Button(L("定位")) { onReveal(asset) }.buttonStyle(.link).controlSize(.small)
                            }
                            .padding(.horizontal, Tokens.gapL)
                            .padding(.vertical, Tokens.gapS)
                            if asset.id != warningAssets.last?.id { Divider() }
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .background(Tokens.warning.opacity(0.13))
        .overlay(RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous).stroke(Tokens.warning.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.controlRadius, style: .continuous))
    }
}

// MARK: - 表单辅助

struct FormLabel: View {
    let text: String

    var body: some View {
        Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(Tokens.mutedForeground)
    }
}

struct FieldHint: View {
    let text: String
    var isError: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(isError ? Tokens.danger : Tokens.subtleForeground)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 参数说明 Tooltip 的统一文案来源
/// 必须是计算属性：`static let` 只求值一次，切换语言后会残留旧语种文案
enum ParamHelp {
    static var drives: String { L("把本机磁盘映射进远程会话，远程可直接读写本地文件（仅 RDP 支持）。") }
    static var audio: String { L("把远程会话的声音在本机播放（仅 RDP 支持）。") }
    static var clipboard: String { L("本机与远程之间可直接复制粘贴文本。") }
    static var colorDepth: String { L("色深越高画面越细腻、占用带宽越大；远程桌面建议 24 位。") }
    static var probeInterval: String { L("按间隔自动探测已勾选资产的可达性；0 表示关闭自动探测。") }
    static var rememberPassword: String { L("密码保存在 macOS 系统钥匙串中，不写入本产品的数据文件；换机迁移需重新输入。") }
    static var windowMode: String { L("作用于下一次连接；本平台不支持的模式会按普通窗口打开。") }
}
