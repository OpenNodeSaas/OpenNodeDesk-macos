import Foundation
import SwiftUI

/// 国际化：以中文原文为键，按当前语言查表替换；缺表项回落中文原文，不出现空白
final class Localization: ObservableObject {
    static let shared = Localization()

    @Published var language: AppLanguage = .zh

    func translate(_ key: String) -> String {
        guard let table = Localization.tables[language] else { return key }
        return table[key] ?? key
    }

    /// 语料表索引：中文（.zh）为原文，不建表
    private static let tables: [AppLanguage: [String: String]] = [
        .en: Localization.english,
        .zhTW: Localization.traditionalChinese,
        .ja: Localization.japanese,
        .ko: Localization.korean,
        .de: Localization.german,
        .fr: Localization.french,
        .es: Localization.spanish,
        .pt: Localization.portuguese,
        .ru: Localization.russian,
        .th: Localization.thai,
        .id: Localization.indonesian,
        .vi: Localization.vietnamese,
    ]
}

func L(_ key: String) -> String { Localization.shared.translate(key) }
