import Foundation
import SwiftUI

/// 国际化：以中文原文为键，切到英文时查表替换；缺表项回落原文，不出现空白
final class Localization: ObservableObject {
    static let shared = Localization()

    @Published var language: AppLanguage = .zh

    func translate(_ key: String) -> String {
        guard language == .en else { return key }
        return Localization.english[key] ?? key
    }
}

func L(_ key: String) -> String { Localization.shared.translate(key) }
