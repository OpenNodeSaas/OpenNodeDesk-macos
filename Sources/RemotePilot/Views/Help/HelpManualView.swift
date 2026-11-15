import SwiftUI
import AppKit

/// 帮助手册章节：AppModel.focusedHelpSection / openHelp(_:) 依赖此类型
/// 注意：类型名与成员名必须与调用方保持一致
enum HelpSection: String, CaseIterable, Identifiable {
    case vnc
    case vncFaq
    case rdpFaq
    case sshFaq
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vnc: return L("VNC 使用说明")
        case .vncFaq: return L("VNC 常见疑点")
        case .rdpFaq: return L("RDP 常见疑点")
        case .sshFaq: return L("SSH 常见疑点")
        case .general: return L("通用说明")
        }
    }

    /// 失败诊断的跳转落点：按协议选最相关的章节，避免一律落到「通用说明」
    static func forProtocol(_ proto: RemoteProtocol?) -> HelpSection {
        switch proto {
        case .rdp: return .rdpFaq
        case .vnc: return .vnc
        case .ssh: return .sshFaq
        case nil: return .general
        }
    }
}

/// 帮助手册：客户端配置 + 协议疑点 + 通用说明，一页内自足，无需外部搜索
struct HelpManualView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let maxContentWidth: CGFloat = 720

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.gapXL) {
                    header
                    migrationNotice
                    ForEach(HelpSection.allCases) { section in
                        sectionCard(section).id(section)
                    }
                }
                .frame(maxWidth: maxContentWidth, alignment: .leading)
                .padding(Tokens.gapXXL)
                .frame(maxWidth: .infinity)
            }
            .background(Tokens.appBackground)
            .onAppear {
                DispatchQueue.main.async { focus(proxy, animated: false) }
            }
            .onChange(of: model.focusedHelpSection) { _, _ in
                focus(proxy, animated: true)
            }
        }
    }

    // MARK: - 页首

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.gapS) {
            Text(L("帮助手册")).font(.system(size: 22, weight: .bold))
            Text(L("覆盖「客户端配置 + 协议疑点 + 通用说明」，无需再外部搜索。"))
                .font(.system(size: 12))
                .foregroundStyle(Tokens.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 配置迁移提示

    /// 客户端配置卡已迁出到「设置」页（见 PRODUCT_UX_DESIGN_DELTA §8），原位仅保留一行提示
    private var migrationNotice: some View {
        Text(L("VNC 客户端的路径与启动参数已迁移到左侧导航的「设置」页。"))
            .font(.system(size: 12))
            .foregroundStyle(Tokens.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 章节卡片

    private func sectionCard(_ section: HelpSection) -> some View {
        let focused = model.focusedHelpSection == section
        return CardContainer(title: section.title) {
            VStack(alignment: .leading, spacing: Tokens.gapM) {
                ForEach(Array(blocks(for: section).enumerated()), id: \.offset) { _, block in
                    VStack(alignment: .leading, spacing: Tokens.gapXS) {
                        if let heading = block.heading {
                            Text(heading).font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Tokens.primaryForeground)
                        }
                        Text(block.body)
                            .font(.system(size: 12))
                            .foregroundStyle(Tokens.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.cardRadius, style: .continuous)
                .stroke(focused ? Tokens.accent : Color.clear, lineWidth: 2)
        )
    }

    // MARK: - 行为

    private func focus(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let section = model.focusedHelpSection else { return }
        // 尊重系统「减少动态效果」：开启时直接跳转，不做滚动动画
        if animated && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(section, anchor: .top) }
        } else {
            proxy.scrollTo(section, anchor: .top)
        }
    }

    // MARK: - 章节正文

    private struct HelpBlock {
        var heading: String?
        var body: String
    }

    private func blocks(for section: HelpSection) -> [HelpBlock] {
        switch section {
        case .vnc:
            return [
                HelpBlock(heading: L("如何选取客户端"), body: L("本产品不自己渲染远程画面，而是调用 macOS 上的承载客户端。VNC 优先使用系统「屏幕共享」（内置，支持标准 VNC 服务），无需安装；如需 RealVNC / TigerVNC 等外装客户端，可在左侧「设置」页的「VNC 承载客户端」用「浏览…」指定，或点「自动探测」填入本机已安装的客户端路径。")),
                HelpBlock(heading: L("参数模板与占位符"), body: L("参数模板会把占位符替换为本次连接的值后再传给客户端：{host} 主机名或 IP、{port} 端口、{display} 显示编号、{user} 用户名、{password} 已保存的密码。默认模板 {host}::{display} 适用于系统屏幕共享与多数 VNC Viewer。")),
                HelpBlock(heading: L("密码如何传递"), body: L("使用系统「屏幕共享」时，会弹出系统窗口要求输入 VNC 密码，密码不经过本产品；外装客户端可在模板中使用 {password} 占位符自动填充，但请注意密码会出现在进程启动参数中，最终安全性由客户端与系统决定。")),
                HelpBlock(heading: L("端口与 display 编号"), body: L("VNC 端口 = 5900 + 显示编号：端口 5900 对应 display 0，端口 5901 对应 display 1，依此类推。填写资产端口时可直接用 5900/5901，模板里的 {display} 会自动换算。")),
                HelpBlock(heading: L("认证失败如何排查"), body: L("若提示认证失败或反复弹窗：确认输入的是「VNC 密码」（与系统登录密码可能不同）；确认服务端要求的用户名/密码格式；部分服务端启用了 TLS/加密插件，需要在外装客户端中开启相应选项。")),
            ]
        case .vncFaq:
            return [
                HelpBlock(heading: L("连接被拒绝或立即断开"), body: L("多半是端口或 display 编号不对。先确认服务监听端口（默认 5900），再核对资产的端口与 {display} 是否匹配；系统「屏幕共享」连接标准 VNC 服务时通常无需用户名。")),
                HelpBlock(heading: L("画面黑屏或只有灰底"), body: L("可能是服务端会话尚未创建，或显示器处于休眠。请先在被控端登录并保持桌面会话；虚拟显示服务需确认已启动对应 display。")),
                HelpBlock(heading: L("多处弹窗要求密码"), body: L("说明密码未被记住。外装客户端需在模板中配置 {password}；系统「屏幕共享」不接收外部密码，每次连接都会由系统弹窗询问。")),
            ]
        case .rdpFaq:
            return [
                HelpBlock(heading: L("自动填充密码需要先授权"), body: L("Windows App 的密码框不提供“记住密码”，因此本产品会在密码框弹出后，通过 macOS 的「辅助功能」接口自动填入钥匙串中保存的密码并提交。首次使用需前往「系统设置 → 隐私与安全性 → 辅助功能」勾选 OpenNodeDesk，否则不会自动填充（仍可在密码框手动输入）。授权按应用签名记录，正式版本使用固定签名，只需授权一次；本地重新构建后如失效，取消勾选再勾选即可。")),
                HelpBlock(heading: L("自动填充未生效"), body: L("先确认「辅助功能」已授权；再确认该资产勾选了「记住密码」并且钥匙串读取正常——读取被系统拒绝或条目丢失时，本产品会在点连接时弹出「输入凭据」让你重填一次。密码本身已过期（远程端改过密码）同样会提示认证失败，需要重新保存。")),
                HelpBlock(heading: L("首次打开提示来源不明的 .rdp 文件"), body: L("本产品会为每次连接生成一个临时 .rdp 文件并交给 Microsoft Windows App 打开。由于该文件非 Apple 签名，系统可能弹窗提示「…来自身份不明的开发者，确定要打开吗？」，确认来源为本产品后选择「打开」即可。")),
                HelpBlock(heading: L("窗口标题从何而来"), body: L("Windows App 的窗口标题取自 .rdp 文件中的目标地址与会话信息，因此通常显示远程主机名或 IP，与资产名称无关。若希望标题更易辨认，可让远程主机的计算机名更具辨识度。")),
                HelpBlock(heading: L("重定向为什么没有生效"), body: L("驱动器、音频、剪贴板重定向需要两端共同支持。本产品已在 .rdp 中写入相应键值（如 drivestoredirect:s:*），但远程 Windows 的组策略可能禁用重定向；请确认远程主机策略允许该重定向，并使用 Windows App（而非旧版客户端）。")),
                HelpBlock(heading: L("为何不支持单窗口标签页"), body: L("本平台差异：macOS 上的 Windows App 不支持在单个窗口内用标签页承载多个会话。选择「标签页」模式时，本产品会按普通窗口打开；多会话请使用「会话工作台」的分屏布局。")),
            ]
        case .sshFaq:
            return [
                HelpBlock(heading: L("通过跳板机连接"), body: L("若资产填写了「跳板机」，会使用 SSH 的 -J（ProxyJump）经跳板机转发。跳板机格式为 [user@]host[:port]；请确保本机能登录该跳板机，或已在跳板机上配置免密。")),
                HelpBlock(heading: L("密钥口令（passphrase）"), body: L("使用带口令的私钥时，请在凭据对话框中输入密钥口令；口令会保存在 macOS 系统钥匙串中，下次连接自动取用，不写入数据文件。")),
                HelpBlock(heading: L("认证失败后如何重试"), body: L("认证失败会弹出凭据对话框，可重新填写用户名、密码或密钥路径后重试。修正后本产品会关闭旧会话并立即用新凭据重连。")),
                HelpBlock(heading: L("密码保存在哪里"), body: L("勾选「记住密码」后，密码存放在 macOS 系统钥匙串（Keychain）中，而非本产品的数据文件；取消勾选或删除资产时会一并清除。")),
            ]
        case .general:
            return [
                HelpBlock(heading: L("数据存放位置"), body: L("资产、模板与设置保存在 ~/Library/Application Support/RemotePilot 目录下（如 assets.json、settings.json）。可在「导入 / 导出」中备份或迁移。")),
                HelpBlock(heading: L("导出与导入迁移"), body: L("在「资产中心」使用导出功能生成 CSV/JSON 备份，换机后通过导入合并（按协议 + 主机 + 端口去重）。导出默认不勾选敏感字段，密码不会包含在导出文件中。")),
                HelpBlock(heading: L("隐私与凭据安全"), body: L("密码与密钥口令只写入 macOS 系统钥匙串，绝不写入明文数据文件；因此换机迁移后需要重新输入密码。同步到云端时同样只同步资产与模板，不包含任何密码。")),
            ]
        }
    }
}
