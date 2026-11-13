import SwiftUI

/// 底部状态栏：反馈文案 + 概览计数，常驻可见
struct StatusBar: View {
    @EnvironmentObject var model: AppModel

    private var reachableCount: Int {
        model.probeResults.values.filter { $0.status == .reachable }.count
    }

    var body: some View {
        HStack(spacing: Tokens.gapM) {
            Image(systemName: model.statusKind.symbol)
                .font(.system(size: 11))
                .foregroundStyle(model.statusKind.color)

            Text(model.statusMessage)
                .font(.system(size: 11))
                .foregroundStyle(Tokens.mutedForeground)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(model.statusMessage)

            if model.isBusy {
                ProgressView().controlSize(.small).scaleEffect(0.55).frame(width: 12, height: 12)
            }

            Spacer(minLength: Tokens.gapL)

            metric(L("资产 {n} 台").replacingOccurrences(of: "{n}", with: "\(model.assets.count)"))
            metric(
                L("可达 {ok} / {total}")
                    .replacingOccurrences(of: "{ok}", with: "\(reachableCount)")
                    .replacingOccurrences(of: "{total}", with: "\(model.assets.count)")
            )
            metric(L("会话 {n}").replacingOccurrences(of: "{n}", with: "\(model.sessions.count)"))
        }
        .padding(.horizontal, Tokens.gapL)
        .frame(height: 26)
        .background(Tokens.sidebarBackground)
        .overlay(alignment: .top) { Divider() }
    }

    private func metric(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .monospacedDigit()
            .foregroundStyle(Tokens.mutedForeground)
    }
}
