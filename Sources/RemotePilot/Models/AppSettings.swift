import Foundation
import SwiftUI

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L("跟随系统")
        case .light: return L("浅色")
        case .dark: return L("深色")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case zh
    case en

    var id: String { rawValue }

    var title: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        }
    }
}

enum ViewMode: String, Codable, CaseIterable, Identifiable {
    case table
    case grid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .table: return L("表格")
        case .grid: return L("宫格")
        }
    }
}

/// 列表字号（列设置浮层）
enum ListFontSize: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return L("小")
        case .medium: return L("中")
        case .large: return L("大")
        }
    }

    var points: CGFloat {
        switch self {
        case .small: return 11
        case .medium: return 12
        case .large: return 13
        }
    }

    var rowHeight: CGFloat {
        switch self {
        case .small: return 38
        case .medium: return 42
        case .large: return 46
        }
    }
}

/// SSH 终端配色方案（设置页预览色块即时跟随）
enum SSHColorScheme: String, Codable, CaseIterable, Identifiable {
    case dark
    case green
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return L("深色")
        case .green: return L("绿色")
        case .light: return L("浅色")
        }
    }

    /// 终端背景 / 前景色（以 sRGB 分量表达，便于 SwiftUI 与 AppKit 共用）
    var background: (r: CGFloat, g: CGFloat, b: CGFloat) {
        switch self {
        case .dark: return (0.10, 0.10, 0.10)
        case .green: return (0.02, 0.08, 0.03)
        case .light: return (0.99, 0.99, 0.99)
        }
    }

    var foreground: (r: CGFloat, g: CGFloat, b: CGFloat) {
        switch self {
        case .dark: return (0.93, 0.93, 0.93)
        case .green: return (0.42, 0.94, 0.45)
        case .light: return (0.12, 0.12, 0.12)
        }
    }
}

/// 全局设置（随资产一同持久化）
struct AppSettings: Codable {
    var theme: ThemeMode = .system
    var language: AppLanguage = .zh
    var viewMode: ViewMode = .table

    // 第二层命令栏：作用于「下一次连接」
    var windowMode: WindowMode = .windowed
    var redirects = RedirectionOptions()
    var colorDepth: ColorDepth = .bpp24

    // 右侧详情面板
    var probeInterval: Int = 0          // 秒；0 = 关闭
    var rememberPassword: Bool = true   // macOS：由系统钥匙串保存

    // 承载客户端（帮助手册中配置）
    var rdpClientPath: String = ""
    var rdpClientArgs: String = ""
    var vncClientPath: String = ""
    var vncClientArgs: String = "{host}::{display}"
    var sshExtraArgs: String = ""

    // 分辨率快速配置
    var displayWidth: Int = 1920
    var displayHeight: Int = 1080

    // SSH 终端外观（设置页）
    var sshTerminalFontSize: Int = 13
    var sshColorScheme: SSHColorScheme = .dark
    /// SSH 以独立窗口打开（不再占用工作台标签与分屏）
    var sshUsesIndependentWindow: Bool = false

    // 资产表格列设置
    var hiddenColumns: Set<String> = []
    var columnOrder: [String] = AssetColumn.allCases.map(\.rawValue)
    var listFontSize: ListFontSize = .medium

    // 云端同步
    var syncEndpoint: String = ""
    var syncToken: String = ""

    // 导航/面板状态
    var sidebarCollapsed: Bool = false
    var inspectorShown: Bool = false

    static let defaultRDPArgs = ""
    static let defaultVNCArgs = "{host}::{display}"
    /// SSH 窗口大小兜底值（资产与模板均未设置时）
    static let defaultSSHWindowWidth = 1000
    static let defaultSSHWindowHeight = 640
}

extension AppSettings {
    /// 全部列的持久化顺序：先按用户顺序，再补齐新增列
    var allColumnsInOrder: [AssetColumn] {
        let known = columnOrder.compactMap { AssetColumn(rawValue: $0) }
        let missing = AssetColumn.allCases.filter { !columnOrder.contains($0.rawValue) }
        return known + missing
    }

    /// 实际渲染的列：必要的隐藏项被忽略
    var visibleColumns: [AssetColumn] {
        allColumnsInOrder.filter { !hiddenColumns.contains($0.rawValue) || $0.isRequired }
    }

    func isColumnHidden(_ column: AssetColumn) -> Bool {
        !column.isRequired && hiddenColumns.contains(column.rawValue)
    }

    mutating func setColumn(_ column: AssetColumn, hidden: Bool) {
        guard !column.isRequired else { return }
        if hidden { hiddenColumns.insert(column.rawValue) } else { hiddenColumns.remove(column.rawValue) }
    }

    /// 将列在顺序中上移 / 下移一位
    mutating func moveColumn(_ column: AssetColumn, up: Bool) {
        var order = allColumnsInOrder
        guard let index = order.firstIndex(of: column) else { return }
        let target = up ? index - 1 : index + 1
        guard order.indices.contains(target) else { return }
        order.swapAt(index, target)
        columnOrder = order.map(\.rawValue)
    }

    func canMoveColumn(_ column: AssetColumn, up: Bool) -> Bool {
        let order = allColumnsInOrder
        guard let index = order.firstIndex(of: column) else { return false }
        return order.indices.contains(up ? index - 1 : index + 1)
    }
}
