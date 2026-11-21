import Foundation

// MARK: - 探测

enum ProbeStatus: String, Codable {
    case reachable
    case unreachable
    case unknown

    var title: String {
        switch self {
        case .reachable: return L("可达")
        case .unreachable: return L("不可达")
        case .unknown: return L("未检测")
        }
    }
}

struct ProbeResult: Codable, Hashable {
    var status: ProbeStatus = .unknown
    var latencyMs: Int?
    var checkedAt: Date?
    var detail: String?

    static let unknown = ProbeResult()

    var summary: String {
        guard let checkedAt else { return L("未检测") }
        let time = DateFormatter.localizedString(from: checkedAt, dateStyle: .none, timeStyle: .short)
        switch status {
        case .reachable:
            return L("可达") + " · " + L("耗时 {v} 毫秒").replacingOccurrences(of: "{v}", with: "\(latencyMs ?? 0)") + " · \(time)"
        case .unreachable:
            return L("不可达") + " · \(time)"
        case .unknown:
            return L("未检测")
        }
    }
}

// MARK: - 会话

enum SessionState: String {
    case connecting
    case connected
    case failed
    case disconnected

    var title: String {
        switch self {
        case .connecting: return L("连接中")
        case .connected: return L("已连接")
        case .failed: return L("连接失败")
        case .disconnected: return L("已断开")
        }
    }

    var isLive: Bool { self == .connected || self == .connecting }
}

/// 就地诊断：原因 + 检查建议
struct Diagnostic: Identifiable, Equatable {
    var id = UUID()
    var cause: String
    var suggestions: [String]
    var isProbeRelated: Bool = false
}

/// 会话承载方式
enum SessionCarrier {
    /// 应用内终端
    case embeddedTerminal
    /// 外部承载客户端（RDP / VNC）
    case externalClient(name: String)
}

struct Session: Identifiable {
    var id = UUID()
    var assetID: UUID
    var name: String
    var host: String
    var port: Int
    var proto: RemoteProtocol
    var username: String
    var state: SessionState = .connecting
    var carrier: SessionCarrier = .embeddedTerminal
    var message: String?
    var diagnostic: Diagnostic?
    var startedAt: Date = Date()
    /// SSH 独立窗口会话：不进入工作台标签与分屏
    var isDetached: Bool = false

    var address: String { "\(host):\(port)" }
}

// MARK: - 工作台布局

enum WorkspaceLayout: String, CaseIterable, Identifiable {
    case single      // 单屏
    case row1x2      // 1×2
    case col2x1      // 2×1
    case grid2x2     // 2×2
    case grid2x3     // 2×3
    case grid3x3     // 3×3

    var id: String { rawValue }

    var columns: Int {
        switch self {
        case .single: return 1
        case .row1x2: return 2
        case .col2x1: return 1
        case .grid2x2: return 2
        case .grid2x3: return 3
        case .grid3x3: return 3
        }
    }

    var rows: Int {
        switch self {
        case .single: return 1
        case .row1x2: return 1
        case .col2x1: return 2
        case .grid2x2: return 2
        case .grid2x3: return 2
        case .grid3x3: return 3
        }
    }

    var capacity: Int { columns * rows }

    var title: String {
        switch self {
        case .single: return L("单屏")
        case .row1x2: return "1×2"
        case .col2x1: return "2×1"
        case .grid2x2: return "2×2"
        case .grid2x3: return "2×3"
        case .grid3x3: return "3×3"
        }
    }

    /// SF Symbol，作为布局切换按钮图标
    var symbol: String {
        switch self {
        case .single: return "rectangle"
        case .row1x2: return "rectangle.split.2x1"
        case .col2x1: return "rectangle.split.1x2"
        case .grid2x2: return "rectangle.split.2x2"
        case .grid2x3: return "rectangle.split.3x2"
        case .grid3x3: return "rectangle.split.3x3"
        }
    }
}

// MARK: - 导航

enum NavSection: Hashable {
    case assets
    case workspace
    case favorites
    case recent
    case templates
    case settings
    case help
    case group(String)

    var title: String {
        switch self {
        case .assets: return L("资产中心")
        case .workspace: return L("会话工作台")
        case .favorites: return L("收藏列表")
        case .recent: return L("最近使用")
        case .templates: return L("连接方案模板")
        case .settings: return L("设置")
        case .help: return L("帮助手册")
        case .group(let name): return name
        }
    }

    var symbol: String {
        switch self {
        case .assets: return "square.grid.2x2"
        case .workspace: return "rectangle.3.group"
        case .favorites: return "star"
        case .recent: return "clock.arrow.circlepath"
        case .templates: return "puzzlepiece"
        case .settings: return "gearshape"
        case .help: return "questionmark.circle"
        case .group: return "folder"
        }
    }
}

// MARK: - 导入导出

enum AssetField: String, CaseIterable, Identifiable {
    case name, group, host, port, proto, username, password, owner, expiry, note1, note2, note3, note4, template, jumpHost, sshKeyPath

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return L("名称")
        case .group: return L("分组")
        case .host: return L("主机")
        case .port: return L("端口")
        case .proto: return L("协议")
        case .username: return L("用户名")
        case .password: return L("密码")
        case .owner: return L("负责人")
        case .expiry: return L("到期日")
        case .note1: return L("备注 1")
        case .note2: return L("备注 2")
        case .note3: return L("备注 3")
        case .note4: return L("备注 4")
        case .template: return L("模板")
        case .jumpHost: return L("跳板机")
        case .sshKeyPath: return L("SSH 密钥")
        }
    }

    /// 敏感字段：导出默认不勾选
    var isSensitive: Bool { self == .password || self == .sshKeyPath }

    /// 导入时识别的表头别名（中英文均可）
    var headerAliases: [String] {
        switch self {
        case .name: return ["name", "名称", "资产名称", "别名"]
        case .group: return ["group", "分组", "组", "category"]
        case .host: return ["host", "ip", "主机", "地址", "ip地址", "hostname"]
        case .port: return ["port", "端口"]
        case .proto: return ["protocol", "proto", "协议", "类型"]
        case .username: return ["username", "user", "用户名", "账号", "登录名"]
        case .password: return ["password", "passwd", "密码"]
        case .owner: return ["owner", "负责人", "归属", "责任人"]
        case .expiry: return ["expiry", "expire", "expiredate", "到期日", "到期时间", "过期时间"]
        case .note1: return ["note1", "备注", "备注1", "说明"]
        case .note2: return ["note2", "备注2"]
        case .note3: return ["note3", "备注3"]
        case .note4: return ["note4", "customnote4", "其他备注4", "备注4", "备4"]
        case .template: return ["template", "模板", "连接方案"]
        case .jumpHost: return ["jumphost", "jump", "跳板机", "跳板"]
        case .sshKeyPath: return ["sshkey", "keypath", "密钥", "密钥路径", "ssh密钥"]
        }
    }

    /// 导出 CSV 的表头
    var exportHeader: String {
        switch self {
        case .name: return "name"
        case .group: return "group"
        case .host: return "host"
        case .port: return "port"
        case .proto: return "协议"
        case .username: return "username"
        case .password: return "password"
        case .owner: return "owner"
        case .expiry: return "expiry"
        case .note1: return "note1"
        case .note2: return "note2"
        case .note3: return "note3"
        case .note4: return "其他备注4"
        case .template: return "template"
        case .jumpHost: return "jumphost"
        case .sshKeyPath: return "sshkey"
        }
    }
}

// MARK: - 资产表格列（列显隐 / 列排序）

/// 表格可配置列：顺序与显隐随本地设置持久化，「名称」「操作」为必要列
enum AssetColumn: String, CaseIterable, Identifiable, Hashable {
    case group, owner, name, address, username, status, expiry, note1, note2, note3, note4, template, proto, actions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .group: return L("分组")
        case .owner: return L("负责人")
        case .name: return L("名称")
        case .address: return L("IP:端口")
        case .username: return L("用户名")
        case .status: return L("状态")
        case .expiry: return L("到期日")
        case .note1: return L("备注1")
        case .note2: return L("备注2")
        case .note3: return L("备注3")
        case .note4: return L("备注4")
        case .template: return L("模板")
        case .proto: return L("协议")
        case .actions: return L("操作")
        }
    }

    /// 「名称」「操作」不可隐藏
    var isRequired: Bool { self == .name || self == .actions }

    var isSortable: Bool { self != .actions }

    /// 固定列宽；名称列弹性（nil）
    var width: CGFloat? {
        switch self {
        case .group: return 96
        case .owner: return 88
        case .name: return nil
        case .address: return 144
        case .username: return 96
        case .status: return 96
        case .expiry: return 96
        case .note1, .note2, .note3, .note4: return 90
        case .template: return 110
        case .proto: return 60
        case .actions: return 68
        }
    }

    var minWidth: CGFloat { width ?? 140 }

    /// 拖拽可调列宽的上限（避免横向溢出被裁剪）
    static let maxWidth: CGFloat = 600

    /// 拖拽可调列宽的下限：只防止拖成零宽，不锁定列默认宽
    static let minResizeWidth: CGFloat = 40
}

/// 导入结果摘要
struct ImportOutcome {
    var imported: Int = 0
    var updated: Int = 0
    var skipped: Int = 0
    var failures: [ImportFailure] = []

    var total: Int { imported + updated + skipped + failures.count }
}

/// 导入冲突处理：IP（主机）+ 端口相同即视为重复
enum ImportConflictPolicy: String, CaseIterable, Identifiable {
    case skip
    case overwrite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .skip: return L("跳过重复")
        case .overwrite: return L("覆盖已有")
        }
    }
}

struct ImportFailure: Identifiable {
    var id = UUID()
    var line: Int
    var reason: String
    var raw: [String]
}
