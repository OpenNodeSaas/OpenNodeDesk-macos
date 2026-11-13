import Foundation
import SwiftUI

/// 状态栏语义
enum StatusKind {
    case idle
    case progress
    case success
    case warning
    case failure

    var color: Color {
        switch self {
        case .idle: return Tokens.mutedForeground
        case .progress: return Tokens.info
        case .success: return Tokens.success
        case .warning: return Tokens.warning
        case .failure: return Tokens.danger
        }
    }

    var symbol: String {
        switch self {
        case .idle: return "circle.dashed"
        case .progress: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failure: return "xmark.octagon.fill"
        }
    }
}

struct EditorRequest: Identifiable {
    var id = UUID()
    var asset: Asset
    var isNew: Bool
}

struct PlanRequest: Identifiable {
    var id = UUID()
    var asset: Asset
    var highlightTemplate: Bool = false
}

struct CredentialRequest: Identifiable {
    var id = UUID()
    var asset: Asset
    var failureMessage: String?
}

struct TemplateEditRequest: Identifiable {
    var id = UUID()
    var template: ConnectionTemplate
    var isNew: Bool
}

/// 应用状态中枢：资产、模板、设置、探测、会话、导航统一收口
@MainActor
final class AppModel: ObservableObject {

    // MARK: 持久化数据

    @Published var assets: [Asset] = []
    @Published var templates: [ConnectionTemplate] = []
    @Published var settings = AppSettings()
    @Published var probeResults: [UUID: ProbeResult] = [:]

    // MARK: 导航与列表

    @Published var nav: NavSection = .assets
    @Published var searchText = ""
    @Published var selection: Set<UUID> = [] { didSet { syncSelectionToInspector() } }
    @Published var sortOrder: [KeyPathComparator<Asset>] = [KeyPathComparator(\Asset.name)]
    @Published var expiryBarExpanded = false

    // MARK: 会话工作台

    @Published var sessions: [Session] = []
    @Published var focusedSessionID: UUID?
    @Published var layout: WorkspaceLayout = .single
    @Published var maximizedSessionID: UUID?

    // MARK: 反馈

    @Published var statusMessage = L("就绪")
    @Published var statusKind: StatusKind = .idle
    @Published var isBusy = false
    @Published var lastDiagnostic: Diagnostic?
    @Published var diagnosticContext: (asset: Asset?, retry: (() -> Void)?)?

    // MARK: 弹窗/抽屉

    @Published var editorRequest: EditorRequest?
    @Published var planRequest: PlanRequest?
    @Published var credentialRequest: CredentialRequest?
    @Published var templateEditRequest: TemplateEditRequest?
    @Published var showImportSheet = false
    @Published var showExportSheet = false
    @Published var showSyncSheet = false
    @Published var showFeedbackSheet = false
    @Published var pendingDeletion: [Asset]? = nil
    @Published var pendingRemoteAssets: [Asset] = []
    @Published var inspectorPresented = false
    @Published var launchOverrides = LaunchOverrides.none
    @Published var focusedHelpSection: HelpSection?
    /// 自增令牌：菜单快捷键请求聚焦全局搜索框
    @Published var focusSearchTick = 0

    private var probeTimer: Timer?

    // MARK: - 生命周期

    init() {
        loadFromDisk()
        if assets.isEmpty && templates.isEmpty {
            seedSampleDataIfFirstLaunch()
        }
        applyLanguage()
        startAutoProbeIfNeeded()
    }

    private func loadFromDisk() {
        assets = Storage.load([Asset].self, from: "assets.json") ?? []
        templates = Storage.load([ConnectionTemplate].self, from: "templates.json") ?? []
        settings = Storage.load(AppSettings.self, from: "settings.json") ?? AppSettings()
        probeResults = Storage.load([UUID: ProbeResult].self, from: "probe.json") ?? [:]
        layout = WorkspaceLayout(rawValue: Storage.load(String.self, from: "layout.json") ?? "") ?? .single
        inspectorPresented = settings.inspectorShown
    }

    private func seedSampleDataIfFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: "rpp.seeded") else { return }
        UserDefaults.standard.set(true, forKey: "rpp.seeded")
        // 首次启动给一条示例资产，保证空列表之外至少能立刻体验「搜索 → 回车 → 连接」
        var sample = Asset()
        sample.name = L("示例：本机 SSH")
        sample.group = L("示例分组")
        sample.host = "127.0.0.1"
        sample.port = 22
        sample.proto = .ssh
        assets = [sample]
        saveAssets()
    }

    func restoreThemeAndLanguage() {
        Localization.shared.language = settings.language
    }

    private func applyLanguage() {
        Localization.shared.language = settings.language
    }

    // MARK: - 持久化

    func saveAssets() { Storage.save(assets, to: "assets.json") }
    func saveTemplates() { Storage.save(templates, to: "templates.json") }
    func saveSettings() {
        Storage.save(settings, to: "settings.json")
        Storage.save(layout.rawValue, to: "layout.json")
        applyLanguage()
        startAutoProbeIfNeeded()
    }
    private func saveProbeResults() { Storage.save(probeResults, to: "probe.json") }

    // MARK: - 分组与筛选

    var groups: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for asset in assets { counts[asset.group, default: 0] += 1 }
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { ($0.name.isEmpty ? L("未分组") : $0.name) < ($1.name.isEmpty ? L("未分组") : $1.name) }
    }

    var activeGroupFilter: String? {
        if case .group(let name) = nav { return name }
        return nil
    }

    var filteredAssets: [Asset] {
        var result = assets

        switch nav {
        case .favorites: result = result.filter { $0.isFavorite }
        case .recent:
            result = result.filter { $0.lastConnectedAt != nil }
                .sorted { ($0.lastConnectedAt ?? .distantPast) > ($1.lastConnectedAt ?? .distantPast) }
        case .group(let name): result = result.filter { $0.group == name }
        case .assets, .workspace, .templates, .settings, .help: break
        }

        let keyword = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !keyword.isEmpty {
            result = result.filter { asset in
                let haystack = [asset.name, asset.host, "\(asset.host):\(asset.port)", asset.group, asset.owner, asset.username,
                                asset.note1, asset.note2, asset.note3, asset.note4, asset.proto.rawValue]
                    .joined(separator: " ").lowercased()
                return haystack.contains(keyword)
            }
        }

        if case .recent = nav {
            return result
        }
        return result.sorted(using: sortOrder)
    }

    var warningAssets: [Asset] {
        assets.filter { $0.expiryState.isWarning }
            .sorted { lhs, rhs in
                (lhs.expiry ?? .distantFuture) < (rhs.expiry ?? .distantFuture)
            }
    }

    var selectedAssets: [Asset] { assets.filter { selection.contains($0.id) } }

    var inspectorAsset: Asset? {
        if let id = selection.first, selection.count == 1 { return assets.first { $0.id == id } }
        return nil
    }

    private func syncSelectionToInspector() {
        if inspectorPresented && selection.isEmpty { inspectorPresented = false }
    }

    func asset(id: UUID) -> Asset? { assets.first { $0.id == id } }

    func template(id: UUID?) -> ConnectionTemplate? {
        guard let id else { return nil }
        return templates.first { $0.id == id }
    }

    // MARK: - 资产 CRUD

    func upsert(_ asset: Asset) {
        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
            assets[index] = asset
        } else {
            assets.append(asset)
            selection = [asset.id]
        }
        if !asset.rememberPassword {
            Keychain.remove(account: Keychain.passwordAccount(asset.id))
        }
        saveAssets()
    }

    func requestDelete(_ ids: Set<UUID>) {
        let targets = assets.filter { ids.contains($0.id) }
        guard !targets.isEmpty else { return }
        pendingDeletion = targets
    }

    func confirmDelete() {
        guard let targets = pendingDeletion else { return }
        let ids = Set(targets.map { $0.id })
        for asset in targets {
            Keychain.remove(account: Keychain.passwordAccount(asset.id))
            Keychain.remove(account: Keychain.keyPassphraseAccount(asset.id))
            probeResults.removeValue(forKey: asset.id)
            closeSessions(for: asset.id)
        }
        assets.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
        pendingDeletion = nil
        saveAssets()
        saveProbeResults()
        setStatus(L("已删除 {n} 条资产").replacingOccurrences(of: "{n}", with: "\(targets.count)"), kind: .success)
    }

    func toggleFavorite(_ asset: Asset) {
        guard let index = assets.firstIndex(where: { $0.id == asset.id }) else { return }
        assets[index].isFavorite.toggle()
        saveAssets()
    }

    func invertSelection() {
        let visible = Set(filteredAssets.map { $0.id })
        selection = visible.subtracting(selection)
    }

    func clearSelection() { selection = [] }

    func mergeImported(_ incoming: [Asset]) -> (added: Int, updated: Int) {
        var added = 0
        var updated = 0
        for asset in incoming {
            if let index = assets.firstIndex(where: { $0.host == asset.host && $0.port == asset.port && $0.proto == asset.proto }) {
                var merged = asset
                merged.id = assets[index].id
                merged.isFavorite = assets[index].isFavorite
                merged.templateID = assets[index].templateID
                assets[index] = merged
                updated += 1
            } else {
                assets.append(asset)
                added += 1
            }
        }
        saveAssets()
        return (added, updated)
    }

    // MARK: - 模板

    func upsertTemplate(_ template: ConnectionTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
        saveTemplates()
    }

    func duplicateTemplate(_ template: ConnectionTemplate) {
        var copy = template
        copy.id = UUID()
        copy.name = template.name + L(" 副本")
        copy.usageCount = 0
        templates.append(copy)
        saveTemplates()
    }

    func deleteTemplate(_ template: ConnectionTemplate) {
        templates.removeAll { $0.id == template.id }
        for index in assets.indices where assets[index].templateID == template.id {
            assets[index].templateID = nil
        }
        saveAssets()
        saveTemplates()
    }

    func templateUsageCount(_ template: ConnectionTemplate) -> Int {
        assets.filter { $0.templateID == template.id }.count
    }

    // MARK: - 凭据

    func password(for asset: Asset) -> String? {
        Keychain.secret(account: Keychain.passwordAccount(asset.id))
    }

    func storePassword(_ password: String, for asset: Asset, remember: Bool) {
        var updated = asset
        updated.rememberPassword = remember && !password.isEmpty
        if updated.rememberPassword {
            Keychain.store(password, account: Keychain.passwordAccount(asset.id))
        } else {
            Keychain.remove(account: Keychain.passwordAccount(asset.id))
        }
        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
            assets[index].rememberPassword = updated.rememberPassword
            saveAssets()
        }
    }

    func storeKeyPassphrase(_ passphrase: String, for asset: Asset) {
        guard !passphrase.isEmpty else { return }
        Keychain.store(passphrase, account: Keychain.keyPassphraseAccount(asset.id))
    }

    // MARK: - 参数解析（参数可解释）

    private func resolveRedirects(_ asset: Asset) -> (value: RedirectionOptions, source: ParamSource, perItemSource: ParamSource) {
        let builtin = RedirectionOptions()
        if let override = launchOverrides.redirects {
            return (override, .custom, .custom)
        }
        if asset.redirects != builtin {
            return (asset.redirects, .custom, .custom)
        }
        if let template = template(id: asset.templateID), template.redirects != builtin {
            return (template.redirects, .template(template.name), .template(template.name))
        }
        if settings.redirects != builtin {
            return (settings.redirects, .custom, .custom)
        }
        return (builtin, .builtin, .builtin)
    }

    func effectiveParameters(for asset: Asset) -> EffectiveParameters {
        var params = EffectiveParameters()
        let template = template(id: asset.templateID)

        params.port = ResolvedParameter(key: L("端口"), value: asset.port, source: asset.port == asset.proto.defaultPort ? .builtin : .custom)

        if !asset.username.isEmpty {
            params.username = ResolvedParameter(key: L("用户名"), value: asset.username, source: .custom)
        } else if let template, !template.username.isEmpty {
            params.username = ResolvedParameter(key: L("用户名"), value: template.username, source: .template(template.name))
        } else {
            params.username = ResolvedParameter(key: L("用户名"), value: "", source: .builtin)
        }

        if let override = launchOverrides.windowMode {
            params.windowMode = ResolvedParameter(key: L("窗口模式"), value: override, source: .custom)
        } else if let template, template.windowMode != WindowMode.windowed {
            params.windowMode = ResolvedParameter(key: L("窗口模式"), value: template.windowMode, source: .template(template.name))
        } else if settings.windowMode != .windowed {
            params.windowMode = ResolvedParameter(key: L("窗口模式"), value: settings.windowMode, source: .custom)
        } else {
            params.windowMode = ResolvedParameter(key: L("窗口模式"), value: .windowed, source: .builtin)
        }

        if let override = launchOverrides.colorDepth {
            params.colorDepth = ResolvedParameter(key: L("色深"), value: override, source: .custom)
        } else if let template, template.colorDepth != .bpp24 {
            params.colorDepth = ResolvedParameter(key: L("色深"), value: template.colorDepth, source: .template(template.name))
        } else if settings.colorDepth != .bpp24 {
            params.colorDepth = ResolvedParameter(key: L("色深"), value: settings.colorDepth, source: .custom)
        } else {
            params.colorDepth = ResolvedParameter(key: L("色深"), value: .bpp24, source: .builtin)
        }

        let redirects = resolveRedirects(asset)
        params.drives = ResolvedParameter(key: L("驱动器映射"), value: redirects.value.drives, source: redirects.perItemSource)
        params.audio = ResolvedParameter(key: L("音频"), value: redirects.value.audio, source: redirects.perItemSource)
        params.clipboard = ResolvedParameter(key: L("剪贴板"), value: redirects.value.clipboard, source: redirects.perItemSource)

        let resolution = resolveResolution(asset)
        params.resolution = ResolvedParameter(key: L("分辨率"), value: resolution.text, source: resolution.source)

        return params
    }

    private func resolveResolution(_ asset: Asset) -> (text: String, width: Int, height: Int, source: ParamSource) {
        if let width = launchOverrides.width, let height = launchOverrides.height {
            return ("\(width)×\(height)", width, height, .custom)
        }
        if asset.displayWidth > 0, asset.displayHeight > 0 {
            return ("\(asset.displayWidth)×\(asset.displayHeight)", asset.displayWidth, asset.displayHeight, .custom)
        }
        let width = settings.displayWidth, height = settings.displayHeight
        let isDefault = width == 1920 && height == 1080
        return ("\(width)×\(height)", width, height, isDefault ? .builtin : .custom)
    }

    func resolvePlan(for asset: Asset) -> LaunchPlan {
        let params = effectiveParameters(for: asset)
        let resolution = resolveResolution(asset)
        return LaunchPlan(
            windowMode: params.windowMode.value,
            colorDepth: params.colorDepth.value,
            redirects: RedirectionOptions(drives: params.drives.value, audio: params.audio.value, clipboard: params.clipboard.value),
            width: resolution.width,
            height: resolution.height,
            username: params.username.value,
            password: password(for: asset)
        )
    }

    /// SSH 独立窗口尺寸：资产自身配置 → 资产绑定的模板 → 产品默认 1000×640
    func resolveSSHWindowSize(_ asset: Asset) -> (width: Int, height: Int, source: ParamSource) {
        if asset.sshWindowWidth > 0, asset.sshWindowHeight > 0 {
            return (asset.sshWindowWidth, asset.sshWindowHeight, .custom)
        }
        if let template = template(id: asset.templateID), template.sshWindowWidth > 0, template.sshWindowHeight > 0 {
            return (template.sshWindowWidth, template.sshWindowHeight, .template(template.name))
        }
        return (AppSettings.defaultSSHWindowWidth, AppSettings.defaultSSHWindowHeight, .builtin)
    }

    // MARK: - 建连

    func connect(_ asset: Asset, switchToWorkspace: Bool = false) {
        guard !asset.host.isEmpty else {
            presentDiagnostic(
                Diagnostic(cause: L("该资产缺少主机地址，无法建立连接。"), suggestions: [L("在资产编辑中补全「主机」字段后重试")]),
                asset: asset,
                retry: nil
            )
            return
        }

        switch asset.proto {
        case .ssh:
            let hasCredential = password(for: asset) != nil || !asset.sshKeyPath.isEmpty
            if asset.username.isEmpty || !hasCredential {
                credentialRequest = CredentialRequest(asset: asset, failureMessage: nil)
                return
            }
            if settings.sshUsesIndependentWindow {
                // 独立窗口：不进入工作台标签与分屏
                openIndependentSSHWindow(for: asset)
            } else {
                openSession(for: asset, carrier: .embeddedTerminal)
            }
        case .rdp, .vnc:
            let session = openSession(for: asset, carrier: .externalClient(name: L("承载客户端")))
            launchExternal(asset: asset, sessionID: session.id)
        }

        markConnected(asset)
        if switchToWorkspace { nav = .workspace }
        setStatus(L("已发起连接：{v}").replacingOccurrences(of: "{v}", with: asset.displayName), kind: .success)
    }

    /// 供工作台占位页「打开窗口」复用：不新建会话，只重新拉起承载客户端
    func launchExternal(asset: Asset, sessionID: UUID) {
        let plan = resolvePlan(for: asset)
        let proto = asset.proto
        Task {
            do {
                if proto == .rdp {
                    try await ConnectionLauncher.launchRDP(asset: asset, plan: plan, settings: settings)
                } else {
                    try await ConnectionLauncher.launchVNC(asset: asset, plan: plan, settings: settings)
                }
                let carrierName = ClientDetector.resolve(proto, preferredPath: proto == .rdp ? settings.rdpClientPath : settings.vncClientPath)?.name ?? L("外部客户端")
                updateSession(sessionID) { session in
                    session.state = .connected
                    session.carrier = .externalClient(name: carrierName)
                    session.message = L("画面已由 {v} 承载").replacingOccurrences(of: "{v}", with: carrierName)
                    session.diagnostic = nil
                }
            } catch let error as LaunchError {
                let diagnostic = error.diagnostic
                updateSession(sessionID) { session in
                    session.state = .failed
                    session.message = diagnostic.cause
                    session.diagnostic = diagnostic
                }
                presentDiagnostic(diagnostic, asset: asset, retry: { [weak self] in
                    self?.retry(asset: asset)
                })
            } catch {
                let diagnostic = Diagnostic(cause: error.localizedDescription, suggestions: [L("确认承载客户端可用后重试")])
                updateSession(sessionID) { session in
                    session.state = .failed
                    session.message = diagnostic.cause
                    session.diagnostic = diagnostic
                }
                presentDiagnostic(diagnostic, asset: asset, retry: { [weak self] in self?.retry(asset: asset) })
            }
        }
    }

    func retry(asset: Asset) {
        closeSessions(for: asset.id)
        lastDiagnostic = nil
        diagnosticContext = nil
        connect(asset)
    }

    private func markConnected(_ asset: Asset) {
        guard let index = assets.firstIndex(where: { $0.id == asset.id }) else { return }
        assets[index].lastConnectedAt = Date()
        if let templateID = assets[index].templateID, let tIndex = templates.firstIndex(where: { $0.id == templateID }) {
            templates[tIndex].usageCount += 1
            saveTemplates()
        }
        saveAssets()
    }

    @discardableResult
    private func openSession(for asset: Asset, carrier: SessionCarrier) -> Session {
        let session = Session(
            assetID: asset.id,
            name: asset.displayName,
            host: asset.host,
            port: asset.port,
            proto: asset.proto,
            username: resolvePlan(for: asset).username,
            state: .connecting,
            carrier: carrier
        )
        sessions.append(session)
        focusedSessionID = session.id
        if layout == .single { focusedSessionID = session.id }
        // 已有会话时自动扩成能容纳的分屏
        if sessions.count > 1 && layout.capacity < sessions.count {
            layout = nextLayout(fitting: sessions.count)
        }
        return session
    }

    /// 工作台可见会话：SSH 独立窗口会话不计入标签与分屏
    var workspaceSessions: [Session] { sessions.filter { !$0.isDetached } }

    /// 以独立窗口打开 SSH：会话仍登记在 sessions 中（便于状态与凭据回调），但标记为 detached
    func openIndependentSSHWindow(for asset: Asset) {
        let size = resolveSSHWindowSize(asset)
        var session = Session(
            assetID: asset.id,
            name: asset.displayName,
            host: asset.host,
            port: asset.port,
            proto: asset.proto,
            username: resolvePlan(for: asset).username,
            state: .connecting,
            carrier: .embeddedTerminal
        )
        session.isDetached = true
        sessions.append(session)
        SSHWindowManager.shared.open(session: session, asset: asset, model: self, width: size.width, height: size.height)
    }

    private func nextLayout(fitting count: Int) -> WorkspaceLayout {
        switch count {
        case ...1: return .single
        case 2: return .row1x2
        case ...4: return .grid2x2
        case ...6: return .grid2x3
        default: return .grid3x3
        }
    }

    func updateSession(_ id: UUID, mutate: (inout Session) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        mutate(&sessions[index])
    }

    func markSessionConnected(_ id: UUID) {
        updateSession(id) { session in
            if session.state == .connecting || session.state == .failed {
                session.state = .connected
                session.message = nil
                session.diagnostic = nil
            }
        }
    }

    func markSessionFailed(_ id: UUID, diagnostic: Diagnostic, showCredentialPrompt: Bool = false) {
        updateSession(id) { session in
            session.state = .failed
            session.message = diagnostic.cause
            session.diagnostic = diagnostic
        }
        let target = sessions.first { $0.id == id }.flatMap { self.asset(id: $0.assetID) }
        presentDiagnostic(diagnostic, asset: target, retry: target.map { value in { [weak self] in self?.retry(asset: value) } })
        if showCredentialPrompt, let target {
            credentialRequest = CredentialRequest(asset: target, failureMessage: diagnostic.cause)
        }
    }

    func closeSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        if focusedSessionID == id { focusedSessionID = sessions.last?.id }
        if maximizedSessionID == id { maximizedSessionID = nil }
    }

    func closeSessions(for assetID: UUID) {
        SSHWindowManager.shared.closeWindow(forAsset: assetID)
        sessions.removeAll { $0.assetID == assetID }
        if let focused = focusedSessionID, !sessions.contains(where: { $0.id == focused }) {
            focusedSessionID = sessions.last?.id
        }
    }

    /// 关闭独立窗口时移除对应会话（窗口生命周期由 SSHWindowManager 驱动）
    func removeDetachedSession(assetID: UUID) {
        sessions.removeAll { $0.isDetached && $0.assetID == assetID }
    }

    func closeAllSessions() {
        // 仅关闭工作台会话；SSH 独立窗口由各自窗口关闭
        let ids = workspaceSessions.map { $0.id }
        for id in ids { TerminalRegistry.shared.terminate(sessionID: id) }
        sessions.removeAll { !$0.isDetached }
        focusedSessionID = nil
        maximizedSessionID = nil
        setStatus(L("已关闭全部会话"), kind: .success)
    }

    func session(id: UUID) -> Session? { sessions.first { $0.id == id } }

    // MARK: - 凭据流程

    func submitCredential(asset: Asset, username: String, password: String, keyPath: String, passphrase: String, remember: Bool) {
        var updated = asset
        updated.username = username
        updated.sshKeyPath = keyPath
        upsertCredentialChange(updated, password: password, passphrase: passphrase, remember: remember)
    }

    private func upsertCredentialChange(_ asset: Asset, password: String, passphrase: String, remember: Bool) {
        upsert(asset)
        storePassword(password, for: asset, remember: remember)
        if !passphrase.isEmpty { storeKeyPassphrase(passphrase, for: asset) }
        credentialRequest = nil
        closeSessions(for: asset.id)
        if let refreshed = self.asset(id: asset.id) {
            connect(refreshed)
        }
    }

    // MARK: - 探测

    func probe(_ targets: [Asset], timeout: TimeInterval = 3) {
        let list = targets.filter { !$0.host.isEmpty }
        guard !list.isEmpty else { return }
        isBusy = true
        setStatus(L("正在探测 {n} 台机器…").replacingOccurrences(of: "{n}", with: "\(list.count)"), kind: .progress)
        let inputs = list.map { (id: $0.id, host: $0.host, port: $0.port) }
        Task {
            let results = await ProbeService.probeAll(inputs, timeout: timeout)
            for (id, result) in results { probeResults[id] = result }
            saveProbeResults()
            isBusy = false
            let reachable = results.values.filter { $0.status == .reachable }.count
            setStatus(L("探测完成：{ok} 可达 / {total} 台").replacingOccurrences(of: "{ok}", with: "\(reachable)").replacingOccurrences(of: "{total}", with: "\(list.count)"), kind: reachable == list.count ? .success : .warning)
        }
    }

    func probeSelected() {
        let targets = selectedAssets.isEmpty ? assets : selectedAssets
        probe(targets)
    }

    /// 探测失败的就地诊断（规格 5.5）：原因 + 建议 + 重试。
    /// 不走弹窗打断，由详情面板在选中该资产时就地展示；文案明确区分「探测失败 ≠ 不能连」。
    func probeDiagnostic(for asset: Asset) -> Diagnostic? {
        guard let result = probeResults[asset.id], result.status == .unreachable else { return nil }
        return Diagnostic(
            cause: L("端口探测未收到响应：{v} 当前不可达。").replacingOccurrences(of: "{v}", with: asset.address),
            suggestions: [
                L("确认目标机器已开机、网络可达，且 {v} 端口未被防火墙拦截").replacingOccurrences(of: "{v}", with: "\(asset.port)"),
                L("部分主机屏蔽端口探测但不影响连接，可直接尝试连接以确认实际可用性")
            ],
            isProbeRelated: true
        )
    }

    /// 探测诊断卡上的「重试」：只重探这一台，避免整表重探
    func probeRetry(for asset: Asset) -> () -> Void {
        { [weak self] in self?.probe([asset]) }
    }

    private func startAutoProbeIfNeeded() {
        probeTimer?.invalidate()
        probeTimer = nil
        let interval = settings.probeInterval
        guard interval > 0 else { return }
        probeTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isBusy else { return }
                self.probe(self.assets)
            }
        }
    }

    // MARK: - 导入 / 导出 / 同步

    func applyImport(_ result: (assets: [Asset], failures: [ImportFailure])) -> ImportOutcome {
        let merged = mergeImported(result.assets)
        var outcome = ImportOutcome()
        outcome.imported = merged.added
        outcome.updated = merged.updated
        outcome.failures = result.failures
        return outcome
    }

    func exportCSV(fields: [AssetField], to url: URL) throws {
        let text = AssetExporter.csv(assets: selectedAssets.isEmpty ? filteredAssets : selectedAssets, fields: fields, templates: templates)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func syncFetch() async {
        isBusy = true
        setStatus(L("正在从云端拉取资产…"), kind: .progress)
        do {
            let remote = try await SyncClient.fetch(endpoint: settings.syncEndpoint, token: settings.syncToken)
            pendingRemoteAssets = remote
            isBusy = false
            setStatus(L("已拉取 {n} 条远端资产，请在预览中勾选").replacingOccurrences(of: "{n}", with: "\(remote.count)"), kind: .success)
        } catch let error as SyncError {
            isBusy = false
            presentDiagnostic(error.diagnostic, asset: nil, retry: { [weak self] in
                Task { await self?.syncFetch() }
            })
        } catch {
            isBusy = false
            setStatus(error.localizedDescription, kind: .failure)
        }
    }

    func commitSyncImport(_ selected: [Asset]) -> ImportOutcome {
        let merged = mergeImported(selected)
        var outcome = ImportOutcome()
        outcome.imported = merged.added
        outcome.updated = merged.updated
        pendingRemoteAssets = []
        return outcome
    }

    // MARK: - 状态与诊断

    func setStatus(_ message: String, kind: StatusKind = .idle) {
        statusMessage = message
        statusKind = kind
    }

    func presentDiagnostic(_ diagnostic: Diagnostic, asset: Asset?, retry: (() -> Void)?) {
        lastDiagnostic = diagnostic
        diagnosticContext = (asset, retry)
        setStatus(diagnostic.cause, kind: .failure)
    }

    func dismissDiagnostic() {
        lastDiagnostic = nil
        diagnosticContext = nil
    }

    func openHelp(_ section: HelpSection) {
        focusedHelpSection = section
        nav = .help
    }

    // MARK: - 导航辅助

    func revealAsset(_ asset: Asset) {
        nav = .assets
        searchText = ""
        selection = [asset.id]
        inspectorPresented = true
    }

    func selectGroup(_ group: String?) {
        if let group {
            nav = .group(group)
        } else {
            nav = .assets
        }
    }
}
