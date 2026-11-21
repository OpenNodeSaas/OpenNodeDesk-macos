import SwiftUI

/// 列设置浮层：列显隐 / 列排序 / 列表字号，改动即时生效并随本地配置持久化
struct ColumnSettingsPopover: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.gapL) {
            Text(L("列设置"))
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: Tokens.gapXS) {
                FormLabel(text: L("列表字号"))
                Picker("", selection: fontSizeBinding) {
                    ForEach(ListFontSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Divider()

            VStack(alignment: .leading, spacing: Tokens.gapS) {
                FormLabel(text: L("列显隐与排序"))
                ScrollView {
                    VStack(spacing: Tokens.gapXS) {
                        ForEach(model.settings.allColumnsInOrder) { column in
                            columnRow(column)
                        }
                    }
                    .padding(.trailing, Tokens.gapXS)
                }
                .frame(maxHeight: 240)
                FieldHint(text: L("「名称」「操作」为必要列，不可隐藏。"))
            }

            Divider()

            VStack(alignment: .leading, spacing: Tokens.gapS) {
                Button(L("恢复默认列宽")) {
                    model.settings.resetColumnWidths()
                    model.saveSettings()
                }
                .controlSize(.small)
                .disabled(model.settings.columnWidths.isEmpty)
                FieldHint(text: L("拖动表头右边缘可调整列宽，宽度会记住。"))
            }
        }
        .padding(Tokens.gapL)
        .frame(width: 320)
    }

    private func columnRow(_ column: AssetColumn) -> some View {
        HStack(spacing: Tokens.gapS) {
            Toggle(isOn: visibilityBinding(column)) {
                Text(column.title).font(.system(size: 12))
            }
            .toggleStyle(.checkbox)
            .disabled(column.isRequired)

            Spacer(minLength: Tokens.gapS)

            Button {
                model.settings.moveColumn(column, up: true)
                model.saveSettings()
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.borderless)
            .controlSize(.mini)
            .disabled(!model.settings.canMoveColumn(column, up: true))
            .help(L("上移"))
            .accessibilityLabel(L("上移"))

            Button {
                model.settings.moveColumn(column, up: false)
                model.saveSettings()
            } label: {
                Image(systemName: "arrow.down")
            }
            .buttonStyle(.borderless)
            .controlSize(.mini)
            .disabled(!model.settings.canMoveColumn(column, up: false))
            .help(L("下移"))
            .accessibilityLabel(L("下移"))
        }
    }

    private func visibilityBinding(_ column: AssetColumn) -> Binding<Bool> {
        Binding(
            get: { !model.settings.isColumnHidden(column) },
            set: { newValue in
                model.settings.setColumn(column, hidden: !newValue)
                model.saveSettings()
            }
        )
    }

    private var fontSizeBinding: Binding<ListFontSize> {
        Binding(
            get: { model.settings.listFontSize },
            set: { model.settings.listFontSize = $0; model.saveSettings() }
        )
    }
}
