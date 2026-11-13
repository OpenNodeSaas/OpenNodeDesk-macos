import Foundation

// MARK: - 协议

enum RemoteProtocol: String, Codable, CaseIterable, Identifiable, Hashable {
    case rdp
    case ssh
    case vnc

    var id: String { rawValue }

    var defaultPort: Int {
        switch self {
        case .rdp: return 3389
        case .ssh: return 22
        case .vnc: return 5900
        }
    }

    /// 协议徽章文案（技术标识，不做翻译）
    var badge: String { rawValue.uppercased() }

    var title: String {
        switch self {
        case .rdp: return "RDP"
        case .ssh: return "SSH"
        case .vnc: return "VNC"
        }
    }
}

// MARK: - 连接参数选项

enum WindowMode: String, Codable, CaseIterable, Identifiable {
    case windowed
    case fullscreen
    case smallWindow
    case tabbed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .windowed: return L("普通窗口")
        case .fullscreen: return L("全屏")
        case .smallWindow: return L("小窗")
        case .tabbed: return L("标签页")
        }
    }
}

/// 重定向（本地资源映射到远程会话）
struct RedirectionOptions: Codable, Hashable {
    var drives: Bool = false
    var audio: Bool = false
    var clipboard: Bool = true

    var isAnyEnabled: Bool { drives || audio || clipboard }

    var summary: String {
        var parts: [String] = []
        if drives { parts.append(L("驱动器")) }
        if audio { parts.append(L("音频")) }
        if clipboard { parts.append(L("剪贴板")) }
        return parts.isEmpty ? L("无") : parts.joined(separator: " / ")
    }
}

enum ColorDepth: Int, Codable, CaseIterable, Identifiable {
    case bpp8 = 8
    case bpp15 = 15
    case bpp16 = 16
    case bpp24 = 24
    case bpp32 = 32

    var id: Int { rawValue }
    var title: String { "\(rawValue)" }
}

// MARK: - 资产

struct Asset: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var group: String = ""
    var host: String = ""
    var port: Int = RemoteProtocol.rdp.defaultPort
    var proto: RemoteProtocol = .rdp
    var templateID: UUID?
    var username: String = ""
    /// 是否在系统钥匙串中保存了密码
    var rememberPassword: Bool = false
    var sshKeyPath: String = ""
    var jumpHost: String = ""
    var owner: String = ""
    var expiry: Date?
    var note1: String = ""
    var note2: String = ""
    var note3: String = ""
    var note4: String = ""
    var redirects = RedirectionOptions()
    var displayWidth: Int = 0
    var displayHeight: Int = 0
    /// SSH 独立窗口尺寸：0 表示未设置（按「模板 → 默认 1000×640」解析）
    var sshWindowWidth: Int = 0
    var sshWindowHeight: Int = 0
    var isFavorite: Bool = false
    var lastConnectedAt: Date?
    var createdAt: Date = Date()

    /// 备注 1/2/3/4 的集合视图，便于导出与表格列渲染
    var notes: [String] {
        get { [note1, note2, note3, note4] }
        set {
            note1 = newValue.indices.contains(0) ? newValue[0] : ""
            note2 = newValue.indices.contains(1) ? newValue[1] : ""
            note3 = newValue.indices.contains(2) ? newValue[2] : ""
            note4 = newValue.indices.contains(3) ? newValue[3] : ""
        }
    }

    var address: String { "\(host):\(port)" }

    var displayName: String { name.isEmpty ? host : name }

    /// 到期预警：剩余天数 <= 30 天（含已过期）
    var expiryState: ExpiryState {
        guard let expiry else { return .none }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: expiry)).day ?? 0
        if days < 0 { return .expired(abs(days)) }
        if days <= 30 { return .soon(days) }
        return .fine(days)
    }

    enum ExpiryState {
        case none
        case expired(Int)
        case soon(Int)
        case fine(Int)

        var isWarning: Bool {
            switch self {
            case .expired, .soon: return true
            case .none, .fine: return false
            }
        }

        var text: String {
            switch self {
            case .none: return "—"
            case .expired(let d): return L("已过期 {d} 天").replacingOccurrences(of: "{d}", with: "\(d)")
            case .soon(let d): return L("剩余 {d} 天").replacingOccurrences(of: "{d}", with: "\(d)")
            case .fine(let d): return L("剩余 {d} 天").replacingOccurrences(of: "{d}", with: "\(d)")
            }
        }
    }
}

// MARK: - 连接方案模板

struct ConnectionTemplate: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var proto: RemoteProtocol = .rdp
    var port: Int = RemoteProtocol.rdp.defaultPort
    var username: String = ""
    var redirects = RedirectionOptions()
    var windowMode: WindowMode = .windowed
    var colorDepth: ColorDepth = .bpp24
    /// SSH 独立窗口尺寸（模板默认 1000×640）
    var sshWindowWidth: Int = 1000
    var sshWindowHeight: Int = 640
    var usageCount: Int = 0
    var updatedAt: Date = Date()
}

// MARK: - 参数来源（参数可解释）

enum ParamSource: Equatable {
    case custom
    case template(String)
    case builtin

    var label: String {
        switch self {
        case .custom: return L("自定义")
        case .template(let name): return name.isEmpty ? L("模板") : L("模板") + " · " + name
        case .builtin: return L("默认")
        }
    }
}

struct ResolvedParameter<Value>: Identifiable {
    let key: String
    var value: Value
    var source: ParamSource

    var id: String { key }
}

/// 连接方案抽屉里展示的「当前生效参数」
struct EffectiveParameters {
    var port = ResolvedParameter(key: L("端口"), value: 0, source: ParamSource.builtin)
    var username = ResolvedParameter(key: L("用户名"), value: "", source: ParamSource.builtin)
    var windowMode = ResolvedParameter(key: L("窗口模式"), value: WindowMode.windowed, source: ParamSource.builtin)
    var colorDepth = ResolvedParameter(key: L("色深"), value: ColorDepth.bpp24, source: ParamSource.builtin)
    var drives = ResolvedParameter(key: L("驱动器映射"), value: false, source: ParamSource.builtin)
    var audio = ResolvedParameter(key: L("音频"), value: false, source: ParamSource.builtin)
    var clipboard = ResolvedParameter(key: L("剪贴板"), value: true, source: ParamSource.builtin)
    var resolution = ResolvedParameter(key: L("分辨率"), value: "—", source: ParamSource.builtin)

    var rows: [ResolvedParameter<String>] {
        [
            ResolvedParameter(key: port.key, value: "\(port.value)", source: port.source),
            ResolvedParameter(key: username.key, value: username.value.isEmpty ? "—" : username.value, source: username.source),
            ResolvedParameter(key: windowMode.key, value: windowMode.value.title, source: windowMode.source),
            ResolvedParameter(key: colorDepth.key, value: L("{v} 位").replacingOccurrences(of: "{v}", with: "\(colorDepth.value.rawValue)"), source: colorDepth.source),
            ResolvedParameter(key: drives.key, value: onOff(drives.value), source: drives.source),
            ResolvedParameter(key: audio.key, value: onOff(audio.value), source: audio.source),
            ResolvedParameter(key: clipboard.key, value: onOff(clipboard.value), source: clipboard.source),
            ResolvedParameter(key: resolution.key, value: resolution.value, source: resolution.source)
        ]
    }

    private func onOff(_ value: Bool) -> String { value ? L("开") : L("关") }
}

/// 抽屉里对「下一次连接」的临时覆盖
struct LaunchOverrides: Hashable {
    var windowMode: WindowMode?
    var colorDepth: ColorDepth?
    var redirects: RedirectionOptions?
    var width: Int?
    var height: Int?
    var username: String?

    var isEmpty: Bool {
        windowMode == nil && colorDepth == nil && redirects == nil && width == nil && height == nil && username == nil
    }

    static let none = LaunchOverrides()
}
