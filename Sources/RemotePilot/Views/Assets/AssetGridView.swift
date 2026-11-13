import Foundation
import SwiftUI

/// 卡片宫格视图：固定宽度卡片流式换行，悬停轻微抬升
struct AssetGridView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: Tokens.gapL)],
                spacing: Tokens.gapL
            ) {
                ForEach(model.filteredAssets) { asset in
                    AssetCard(asset: asset)
                }
            }
            .padding(Tokens.gapL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AssetCard: View {
    @EnvironmentObject var model: AppModel
    let asset: Asset
    @State private var hovering = false

    private var isSelected: Bool { model.selection.contains(asset.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.gapS) {
            HStack(spacing: Tokens.gapS) {
                Text(asset.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(asset.displayName)
                Spacer(minLength: Tokens.gapXS)
                StatusBadge(result: model.probeResults[asset.id] ?? ProbeResult.unknown, compact: true)
                Button {
                    model.toggleFavorite(asset)
                } label: {
                    Image(systemName: asset.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundStyle(asset.isFavorite ? Tokens.accent : Tokens.subtleForeground)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L("收藏"))
            }

            Text(asset.address)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Tokens.mutedForeground)
                .lineLimit(1)

            HStack(spacing: Tokens.gapXS) {
                Text(asset.group.isEmpty ? L("未分组") : asset.group)
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.mutedForeground)
                    .lineLimit(1)
                Text(asset.owner.isEmpty ? "—" : asset.owner)
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.subtleForeground)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Text(asset.expiryState.text)
                .font(.system(size: 11, weight: asset.expiryState.isWarning ? .medium : .regular))
                .foregroundStyle(asset.expiryState.isWarning ? Tokens.warning : Tokens.mutedForeground)
                .lineLimit(1)

            HStack(spacing: Tokens.gapS) {
                Button(L("快速连接")) {
                    model.connect(asset)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(L("编辑")) {
                    model.editorRequest = EditorRequest(asset: asset, isNew: false)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer(minLength: 0)

                if model.template(id: asset.templateID) != nil {
                    Button(L("模板")) {
                        model.planRequest = PlanRequest(asset: asset, highlightTemplate: true)
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                }
            }
        }
        .padding(Tokens.gapL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous)
                .fill(Tokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .shadow(color: hovering ? Color.black.opacity(0.12) : Color.clear,
                radius: hovering ? 12 : 0,
                x: 0,
                y: hovering ? 4 : 0)
        .contentShape(RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.08), value: hovering)
        .onTapGesture(count: 2) {
            model.connect(asset)
        }
        .onTapGesture {
            model.selection = [asset.id]
            model.inspectorPresented = true
        }
    }

    private var borderColor: Color {
        if isSelected { return Tokens.accent }
        if hovering { return Tokens.accent.opacity(0.5) }
        return Tokens.softBorder
    }

    private var borderWidth: CGFloat {
        isSelected ? 2 : 1
    }
}
