import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// SFTP 文件浏览器窗口：按资产唯一，重复打开时置前
@MainActor
final class SFTPWindowManager: NSObject, NSWindowDelegate {
    static let shared = SFTPWindowManager()

    private var windows: [UUID: NSWindow] = [:]

    func open(asset: Asset, settings: AppSettings) {
        if let existing = windows[asset.id] {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let size = NSSize(width: 900, height: 580)
        let hosting = NSHostingView(rootView: SFTPBrowserView(asset: asset, settings: settings))
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SFTP — \(asset.displayName) (\(asset.host))"
        window.contentView = hosting
        window.minSize = NSSize(width: 680, height: 420)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        windows[asset.id] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 关闭全部窗口（进入锁定态时调用）
    func closeAll() {
        for (_, window) in windows {
            window.delegate = nil
            window.close()
        }
        windows.removeAll()
    }

    /// 事件所在窗口是否属于本管理器的 SFTP 窗口（双击打开的被动监听用它筛选）
    func owns(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        return windows.values.contains { $0 === window }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let assetID = windows.first(where: { $0.value === window })?.key else { return }
        windows.removeValue(forKey: assetID)
    }
}

// MARK: - 浏览器界面

struct SFTPBrowserView: View {
    let asset: Asset
    let settings: AppSettings

    @State private var path = ""
    @State private var entries: [SFTPEntry] = []
    @State private var selection: Set<SFTPEntry.ID> = []
    @State private var loading = false
    @State private var errorText: String?
    @State private var transfers: [TransferItem] = []
    @State private var isDropTargeted = false
    @State private var newFolderName = ""
    @State private var showNewFolderPrompt = false
    @State private var showDeletePrompt = false
    @State private var started = false
    @State private var doubleClickMonitor: Any?

    private var service: SFTPService { SFTPService(asset: asset, settings: settings) }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
            if !transfers.isEmpty {
                Divider()
                transferPanel
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 680, minHeight: 420)
        .background(Tokens.surfaceBackground)
        .task {
            guard !started else { return }
            started = true
            await initialLoad()
        }
        .onAppear(perform: installDoubleClickOpen)
        .onDisappear(perform: removeDoubleClickOpen)
        .alert(L("新建文件夹"), isPresented: $showNewFolderPrompt) {
            TextField(L("文件夹名称"), text: $newFolderName)
            Button(L("取消"), role: .cancel) { newFolderName = "" }
            Button(L("创建")) { createFolder() }
        } message: {
            Text(L("将在当前远端目录下创建一个新文件夹。"))
        }
        .alert(
            L("确认删除所选 {n} 项？").replacingOccurrences(of: "{n}", with: "\(selection.count)"),
            isPresented: $showDeletePrompt
        ) {
            Button(L("取消"), role: .cancel) {}
            Button(L("删除"), role: .destructive) { deleteSelected() }
        } message: {
            Text(L("删除后无法恢复；目录需要为空才能删除。"))
        }
    }

    // MARK: 工具条

    private var toolbar: some View {
        HStack(spacing: Tokens.gapM) {
            Button { navigate(to: SFTPService.parent(of: path)) } label: {
                Image(systemName: "chevron.up")
            }
            .help(L("上级目录"))
            .disabled(path.isEmpty || path == "/" || loading)

            Button { Task { await load(path) } } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help(L("刷新"))
            .disabled(path.isEmpty || loading)

            Text(path.isEmpty ? "—" : path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Tokens.mutedForeground)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(path)

            Spacer(minLength: Tokens.gapM)

            if loading { ProgressView().controlSize(.small) }

            Button(L("上传")) { pickUpload() }
                .disabled(path.isEmpty)
            Button(L("下载")) { pickDownload() }
                .disabled(selection.isEmpty)
            Button(L("新建文件夹")) { newFolderName = ""; showNewFolderPrompt = true }
                .disabled(path.isEmpty)
            Button(L("删除")) { showDeletePrompt = true }
                .disabled(selection.isEmpty)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, Tokens.gapM)
        .frame(height: 38)
    }

    // MARK: 文件列表

    private var content: some View {
        ZStack {
            List(entries, selection: $selection) { entry in
                row(entry)
                    .contextMenu {
                        Button(L("打开")) { open(entry) }
                            .disabled(!entry.isDirectory)
                        Button(L("下载")) { download([entry]) }
                        Divider()
                        Button(L("删除"), role: .destructive) {
                            selection = [entry.id]
                            showDeletePrompt = true
                        }
                    }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            if entries.isEmpty && !loading && errorText == nil {
                Text(L("目录为空"))
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.mutedForeground)
            }

            if isDropTargeted {
                RoundedRectangle(cornerRadius: Tokens.cardRadius)
                    .strokeBorder(Tokens.accent, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .padding(Tokens.gapXS)
                    .allowsHitTesting(false)
                Text(L("松开以上传到当前目录"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.accent)
                    .padding(Tokens.gapS)
                    .background(Tokens.surfaceBackground.opacity(0.9), in: RoundedRectangle(cornerRadius: Tokens.controlRadius))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func row(_ entry: SFTPEntry) -> some View {
        HStack(spacing: Tokens.gapM) {
            Image(systemName: entry.isDirectory ? "folder.fill" : (entry.isSymlink ? "link" : "doc"))
                .font(.system(size: 11))
                .foregroundStyle(entry.isDirectory ? Tokens.accent : Tokens.mutedForeground)
                .frame(width: 14)
            Text(entry.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: Tokens.gapM)
            Text(entry.isDirectory ? "—" : Self.sizeText(entry.size))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Tokens.mutedForeground)
                .frame(width: 82, alignment: .trailing)
            Text(entry.modified.map(Self.dateText) ?? "—")
                .font(.system(size: 11))
                .foregroundStyle(Tokens.mutedForeground)
                .frame(width: 118, alignment: .trailing)
            Text(entry.permissions)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Tokens.subtleForeground)
                .frame(width: 96, alignment: .trailing)
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
    }

    // MARK: 传输队列

    private var transferPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Tokens.gapS) {
                Text(L("传输队列"))
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Button(L("清除已完成")) {
                    transfers.removeAll { $0.state.isFinished }
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
            }
            .padding(.horizontal, Tokens.gapM)
            .frame(height: 26)

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.gapXS) {
                    ForEach(transfers) { item in
                        HStack(spacing: Tokens.gapS) {
                            Image(systemName: item.direction.symbol)
                                .font(.system(size: 10))
                                .foregroundStyle(Tokens.mutedForeground)
                                .frame(width: 12)
                            Text(item.title)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: Tokens.gapS)
                            switch item.state {
                            case .running:
                                ProgressView().controlSize(.mini)
                            case .done:
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Tokens.success)
                            case .failed(let reason):
                                Text(reason)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Tokens.danger)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Image(systemName: "xmark.octagon.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Tokens.danger)
                            }
                        }
                    }
                }
                .padding(.horizontal, Tokens.gapM)
                .padding(.bottom, Tokens.gapS)
            }
            .frame(height: 96)
        }
    }

    private var statusBar: some View {
        HStack(spacing: Tokens.gapM) {
            if let errorText {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Tokens.warning)
                Text(errorText)
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.danger)
                    .lineLimit(2)
            } else {
                Text(loading
                     ? L("正在读取远端目录…")
                     : L("{n} 项").replacingOccurrences(of: "{n}", with: "\(entries.count)"))
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.mutedForeground)
            }
            Spacer(minLength: Tokens.gapM)
            Text("\(asset.username.isEmpty ? "" : asset.username + "@")\(asset.host):\(asset.port)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Tokens.subtleForeground)
        }
        .padding(.horizontal, Tokens.gapM)
        .frame(height: 24)
    }

    // MARK: 读取

    private func initialLoad() async {
        loading = true
        errorText = nil
        do {
            let home = try await service.workingDirectory()
            loading = false
            await load(home)
        } catch {
            loading = false
            errorText = Self.describe(error)
        }
    }

    private func load(_ target: String) async {
        guard !target.isEmpty else { return }
        loading = true
        errorText = nil
        do {
            entries = try await service.list(target)
            path = target
            selection = []
        } catch {
            errorText = Self.describe(error)
        }
        loading = false
    }

    private func navigate(to target: String) {
        Task { await load(target) }
    }

    // MARK: 双击打开

    /// 行上挂 TapGesture(count: 2) 会让 List 为区分单击/双击把单击选中多押后约 250ms，
    /// 选起来发涩。改成被动监听鼠标事件：单击仍由 List 即时选中，双击时事件自带 clickCount。
    private func installDoubleClickOpen() {
        guard doubleClickMonitor == nil else { return }
        doubleClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            if event.clickCount == 2, SFTPWindowManager.shared.owns(event.window) {
                openSelectedEntry()
            }
            return event
        }
    }

    private func removeDoubleClickOpen() {
        if let monitor = doubleClickMonitor { NSEvent.removeMonitor(monitor) }
        doubleClickMonitor = nil
    }

    /// 双击时打开当前唯一选中的条目（选中多个时不猜）
    private func openSelectedEntry() {
        guard selection.count == 1,
              let entry = entries.first(where: { selection.contains($0.id) }) else { return }
        open(entry)
    }

    private func open(_ entry: SFTPEntry) {
        guard entry.isDirectory else { return }
        navigate(to: entry.path)
    }

    // MARK: 上传

    private func pickUpload() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = L("选择要上传的文件或文件夹（上传到当前远端目录）")
        panel.prompt = L("上传")
        guard panel.runModal() == .OK else { return }
        upload(panel.urls)
    }

    private func upload(_ urls: [URL]) {
        let directory = path
        guard !directory.isEmpty, !urls.isEmpty else { return }
        let items = urls.map { TransferItem(title: $0.lastPathComponent, direction: .upload) }
        transfers.append(contentsOf: items)
        Task {
            for (index, url) in urls.enumerated() {
                let id = items[index].id
                do {
                    try await service.upload(localPath: url.path, toRemoteDirectory: directory, resume: true)
                    updateTransfer(id) { $0.state = .done }
                } catch {
                    updateTransfer(id) { $0.state = .failed(Self.describe(error)) }
                }
            }
            await load(directory)
        }
    }

    /// Finder 拖入：逐个解析 file URL 后上传
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let identifier = UTType.fileURL.identifier
        let candidates = providers.filter { $0.hasItemConformingToTypeIdentifier(identifier) }
        guard !candidates.isEmpty else { return false }

        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for provider in candidates {
            group.enter()
            provider.loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
                defer { group.leave() }
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let value = item as? URL {
                    url = value
                }
                guard let url else { return }
                lock.lock()
                urls.append(url)
                lock.unlock()
            }
        }
        group.notify(queue: .main) {
            let sorted = urls.sorted { $0.path < $1.path }
            Task { @MainActor in upload(sorted) }
        }
        return true
    }

    // MARK: 下载

    private func pickDownload() {
        download(entries.filter { selection.contains($0.id) })
    }

    private func download(_ targets: [SFTPEntry]) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = L("选择下载保存的本地文件夹")
        panel.prompt = L("下载到此处")
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        download(targets, to: directory)
    }

    private func download(_ targets: [SFTPEntry], to directory: URL) {
        guard !targets.isEmpty else { return }
        let items = targets.map { TransferItem(title: $0.name, direction: .download) }
        transfers.append(contentsOf: items)
        Task {
            for (index, entry) in targets.enumerated() {
                let id = items[index].id
                do {
                    try await service.download(
                        remotePath: entry.path,
                        into: directory.path,
                        isDirectory: entry.isDirectory,
                        resume: true
                    )
                    updateTransfer(id) { $0.state = .done }
                } catch {
                    updateTransfer(id) { $0.state = .failed(Self.describe(error)) }
                }
            }
        }
    }

    // MARK: 新建 / 删除

    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        newFolderName = ""
        guard !name.isEmpty else { return }
        let target = SFTPService.join(path, name)
        Task {
            do {
                try await service.makeDirectory(target)
                await load(path)
            } catch {
                errorText = Self.describe(error)
            }
        }
    }

    private func deleteSelected() {
        let targets = entries.filter { selection.contains($0.id) }
        guard !targets.isEmpty else { return }
        Task {
            for entry in targets {
                do {
                    try await service.remove(entry)
                } catch {
                    errorText = Self.describe(error)
                }
            }
            await load(path)
        }
    }

    // MARK: 辅助

    private func updateTransfer(_ id: UUID, _ mutate: (inout TransferItem) -> Void) {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else { return }
        mutate(&transfers[index])
    }

    private static func describe(_ error: Error) -> String {
        let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let firstLine = text.split(separator: "\n").first.map(String.init) ?? text
        return firstLine.trimmingCharacters(in: .whitespaces)
    }

    private static func sizeText(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static func dateText(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

// MARK: - 传输项

struct TransferItem: Identifiable {
    enum Direction {
        case upload
        case download

        var symbol: String {
            switch self {
            case .upload: return "arrow.up.circle"
            case .download: return "arrow.down.circle"
            }
        }
    }

    enum State {
        case running
        case done
        case failed(String)

        var isFinished: Bool {
            switch self {
            case .running: return false
            case .done, .failed: return true
            }
        }
    }

    let id = UUID()
    let title: String
    let direction: Direction
    var state: State = .running
}
