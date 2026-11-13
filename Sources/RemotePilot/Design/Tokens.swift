import SwiftUI
import AppKit

/// 设计令牌：浅色/深色两套语义色，跟随系统外观即时生效
enum Tokens {
    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    static func alpha(_ color: NSColor, _ value: CGFloat) -> NSColor {
        color.withAlphaComponent(value)
    }

    // 底色
    static let appBackground = dynamic(light: NSColor(white: 0.95, alpha: 1), dark: NSColor(white: 0.11, alpha: 1))
    static let sidebarBackground = dynamic(light: NSColor(white: 0.92, alpha: 1), dark: NSColor(white: 0.14, alpha: 1))
    static let surfaceBackground = dynamic(light: .white, dark: NSColor(white: 0.17, alpha: 1))
    static let cardBackground = dynamic(light: .white, dark: NSColor(white: 0.19, alpha: 1))
    static let fieldBackground = dynamic(light: NSColor(white: 0.99, alpha: 1), dark: NSColor(white: 0.13, alpha: 1))

    // 文字
    static let primaryForeground = Color(nsColor: .labelColor)
    static let mutedForeground = Color(nsColor: .secondaryLabelColor)
    static let subtleForeground = Color(nsColor: .tertiaryLabelColor)

    // 描边与分隔
    static let border = Color(nsColor: .separatorColor)
    static let softBorder = dynamic(light: NSColor(white: 0.90, alpha: 1), dark: NSColor(white: 0.28, alpha: 1))

    // 状态语义色
    static let success = Color(nsColor: .systemGreen)
    static let warning = Color(nsColor: .systemOrange)
    static let danger = Color(nsColor: .systemRed)
    static let info = Color(nsColor: .systemBlue)
    static let accent = Color.accentColor

    // 行/选中
    static let selectedRow = dynamic(light: NSColor(srgbRed: 0.85, green: 0.91, blue: 0.99, alpha: 1), dark: NSColor(srgbRed: 0.16, green: 0.25, blue: 0.38, alpha: 1))
    static let alternateRow = dynamic(light: NSColor(white: 0.975, alpha: 1), dark: NSColor(white: 0.205, alpha: 1))
    static let expiryRow = dynamic(light: NSColor(srgbRed: 1.0, green: 0.96, blue: 0.87, alpha: 1), dark: NSColor(srgbRed: 0.30, green: 0.22, blue: 0.08, alpha: 1))

    // 形状
    static let controlRadius: CGFloat = 4
    static let cardRadius: CGFloat = 8

    // 间距（基础单位 4）
    static let gapXS: CGFloat = 4
    static let gapS: CGFloat = 6
    static let gapM: CGFloat = 8
    static let gapL: CGFloat = 12
    static let gapXL: CGFloat = 16
    static let gapXXL: CGFloat = 24

    static func protoColor(_ proto: RemoteProtocol) -> Color {
        switch proto {
        case .rdp: return Color(nsColor: .systemBlue)
        case .ssh: return Color(nsColor: .systemGreen)
        case .vnc: return Color(nsColor: .systemPurple)
        }
    }

    static func statusColor(_ status: ProbeStatus) -> Color {
        switch status {
        case .reachable: return success
        case .unreachable: return danger
        case .unknown: return mutedForeground
        }
    }

    static func sessionStateColor(_ state: SessionState) -> Color {
        switch state {
        case .connected: return success
        case .connecting: return warning
        case .failed: return danger
        case .disconnected: return mutedForeground
        }
    }

    static func sourceColor(_ source: ParamSource) -> Color {
        switch source {
        case .custom: return accent
        case .template: return Color(nsColor: .systemPurple)
        case .builtin: return mutedForeground
        }
    }
}
