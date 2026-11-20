import Foundation

// MARK: - 模型

/// 远端目录条目（由 `sftp ls -la` 输出解析）
struct SFTPEntry: Identifiable, Hashable {
    let name: String
    let path: String
    let isDirectory: Bool
    let isSymlink: Bool
    let size: Int64
    let permissions: String
    let modified: Date?

    var id: String { path }
}

struct SFTPFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - 服务

/// 远端文件传输：复用系统 `/usr/bin/sftp` 的批处理模式。
/// 认证与内嵌终端一致（SSH_ASKPASS 回调本应用，从钥匙串取密码），不引入新的三方依赖。
struct SFTPService {
    let asset: Asset
    private let extraArgs: [String]

    init(asset: Asset, settings: AppSettings) {
        self.asset = asset
        self.extraArgs = settings.sshExtraArgs
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    // MARK: 路径工具

    static func join(_ base: String, _ name: String) -> String {
        guard !base.isEmpty else { return name }
        return base.hasSuffix("/") ? base + name : base + "/" + name
    }

    static func parent(of path: String) -> String {
        guard path != "/", !path.isEmpty else { return "/" }
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        guard let index = trimmed.lastIndex(of: "/") else { return "/" }
        return index == trimmed.startIndex ? "/" : String(trimmed[trimmed.startIndex..<index])
    }

    // MARK: 查询

    /// 登录后的远端默认目录（`sftp pwd` 输出）
    /// 注意：`sftp -b` 会把命令回显成 `sftp> pwd`，真正的取值在 “Remote working directory:” 之后。
    func workingDirectory() async throws -> String {
        let output = try await run(["pwd"])
        if let path = Self.parseRemotePath(output) {
            return path
        }
        throw SFTPFailure(message: L("无法获取远端目录：{detail}")
            .replacingOccurrences(of: "{detail}", with: output.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    func list(_ path: String) async throws -> [SFTPEntry] {
        let output = try await run(["ls -la \(Self.quote(path))"])
        return Self.parseListing(output, base: path)
    }

    // MARK: 变更

    /// 上传本地文件或目录；文件使用 `reput` 自动断点续传
    func upload(localPath: String, toRemoteDirectory directory: String, resume: Bool) async throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: localPath, isDirectory: &isDirectory) else {
            throw SFTPFailure(message: L("本地文件不存在：{path}").replacingOccurrences(of: "{path}", with: localPath))
        }
        let remote = Self.join(directory, (localPath as NSString).lastPathComponent)
        let source = Self.quote(localPath)
        let target = Self.quote(remote)
        let command: String
        if isDirectory.boolValue {
            command = "put -r \(source) \(target)"
        } else if resume {
            command = "reput \(source) \(target)"
        } else {
            command = "put -p \(source) \(target)"
        }
        _ = try await run([command])
    }

    /// 下载远端文件或目录；文件使用 `reget` 自动断点续传
    func download(remotePath: String, into localDirectory: String, isDirectory: Bool, resume: Bool) async throws {
        let local = (localDirectory as NSString).appendingPathComponent((remotePath as NSString).lastPathComponent)
        let source = Self.quote(remotePath)
        let target = Self.quote(local)
        let command: String
        if isDirectory {
            command = "get -r -p \(source) \(target)"
        } else if resume {
            command = "reget \(source) \(target)"
        } else {
            command = "get -p \(source) \(target)"
        }
        _ = try await run([command])
    }

    func makeDirectory(_ path: String) async throws {
        _ = try await run(["mkdir \(Self.quote(path))"])
    }

    func remove(_ entry: SFTPEntry) async throws {
        _ = try await run(["\(entry.isDirectory ? "rmdir" : "rm") \(Self.quote(entry.path))"])
    }

    // MARK: 进程执行

    /// 以批处理模式执行一组 sftp 命令；任一命令失败即抛错（sftp 批处理默认中止）
    private func run(_ commands: [String]) async throws -> String {
        let batchURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-pilot-sftp-\(UUID().uuidString).batch")
        try commands.joined(separator: "\n").appending("\n")
            .write(to: batchURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: batchURL) }

        var arguments = [
            "-b", batchURL.path,
            "-P", "\(asset.port)",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ServerAliveInterval=30"
        ]
        if !asset.sshKeyPath.isEmpty {
            arguments.append(contentsOf: ["-i", asset.sshKeyPath, "-o", "IdentitiesOnly=yes"])
        }
        if !asset.jumpHost.isEmpty {
            arguments.append(contentsOf: ["-J", asset.jumpHost])
        }
        arguments.append(contentsOf: extraArgs)
        arguments.append(asset.username.isEmpty ? asset.host : "\(asset.username)@\(asset.host)")

        var environment = ProcessInfo.processInfo.environment
        if let executable = Bundle.main.executablePath ?? CommandLine.arguments.first {
            environment["SSH_ASKPASS"] = executable
            environment["SSH_ASKPASS_REQUIRE"] = "force"
            environment["REMOTEPILOT_ASKPASS"] = asset.id.uuidString
        }
        // 远端 ls 的月份为英文缩写，解析依赖 C locale
        environment["LC_ALL"] = "C"
        environment["LANG"] = "C"

        let result = try await ProcessRunner.run(
            executable: "/usr/bin/sftp",
            arguments: arguments,
            environment: environment
        )
        guard result.status == 0 else {
            throw SFTPFailure(message: Self.describe(result))
        }
        return result.stdout
    }

    private static func describe(_ result: ProcessRunner.Result) -> String {
        let detail = [result.stderr, result.stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let detail else {
            return L("SFTP 操作失败（退出码 {code}）")
                .replacingOccurrences(of: "{code}", with: "\(result.status)")
        }
        return detail
    }

    /// sftp 批处理命令里的路径：双引号包裹，转义反斜杠与引号
    private static func quote(_ path: String) -> String {
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    // MARK: ls 解析

    private static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// 去掉 `sftp -b` 回显的命令前缀，例如 "sftp> pwd"
    private static func strippingPrompt(_ line: String) -> String {
        var text = line
        while text.hasPrefix("sftp>") {
            text = String(text.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        }
        return text
    }

    private static func parseRemotePath(_ output: String) -> String? {
        let marker = "Remote working directory:"
        for raw in output.split(separator: "\n") {
            let line = strippingPrompt(String(raw)).trimmingCharacters(in: .whitespaces)
            if let range = line.range(of: marker) {
                let value = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { return value }
            }
        }
        // 兼容只回显路径的版本：取最后一行绝对路径
        for raw in output.split(separator: "\n").reversed() {
            let line = strippingPrompt(String(raw)).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("/") { return line }
        }
        return nil
    }

    private static func parseListing(_ output: String, base: String) -> [SFTPEntry] {
        var entries: [SFTPEntry] = []
        for raw in output.split(separator: "\n") {
            if let entry = parseEntryLine(strippingPrompt(String(raw)), base: base) {
                entries.append(entry)
            }
        }
        return entries.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// 单行解析，例如：`drwxr-xr-x      ? samwhong  wheel  192 Nov 20 08:15 /tmp/sftptest/a.txt`
    /// 注意 sftp 客户端的特殊格式：链接数是 `?`（非数字），名称列是完整路径。
    private static func parseEntryLine(_ line: String, base: String) -> SFTPEntry? {
        let tokens = line.split(whereSeparator: { $0.isWhitespace })
        guard tokens.count >= 8 else { return nil }
        let permissions = String(tokens[0].prefix(10))
        guard permissions.count == 10,
              let first = permissions.first,
              "-?bcdlps".contains(first) else { return nil }

        // 定位月份：其后紧跟“日 + 时间/年份”，前一个 token 为文件大小
        var monthIndex: Int?
        var index = 1
        while index + 2 < tokens.count {
            if monthNames.contains(String(tokens[index])),
               Int(tokens[index + 1]) != nil,
               isTimeOrYear(String(tokens[index + 2])) {
                monthIndex = index
                break
            }
            index += 1
        }
        guard let month = monthIndex else { return nil }

        // 名称从时间/年份之后的原始位置截取，保留文件名里的空格
        var raw = String(line[tokens[month + 2].endIndex...]).trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return nil }
        let isSymlink = permissions.hasPrefix("l")
        if isSymlink, let arrow = raw.range(of: " -> ") {
            raw = String(raw[raw.startIndex..<arrow.lowerBound])
        }

        let name: String
        let path: String
        if raw.hasPrefix("/") {
            // sftp 客户端输出完整路径：去掉结尾斜杠后取最后一段作为名称
            var absolute = raw
            while absolute.count > 1, absolute.hasSuffix("/") { absolute.removeLast() }
            name = absolute.split(separator: "/").last.map(String.init) ?? absolute
            path = absolute
        } else {
            name = raw
            path = join(base, raw)
        }
        guard name != ".", name != ".." else { return nil }

        return SFTPEntry(
            name: name,
            path: path,
            isDirectory: permissions.hasPrefix("d"),
            isSymlink: isSymlink,
            size: Int64(tokens[month - 1]) ?? 0,
            permissions: permissions,
            modified: parseDate(
                month: String(tokens[month]),
                day: String(tokens[month + 1]),
                timeOrYear: String(tokens[month + 2])
            )
        )
    }

    /// `ls -l` 的时间列：近半年显示 “HH:MM”，更早显示四位年份
    private static func isTimeOrYear(_ token: String) -> Bool {
        if token.contains(":") { return true }
        return token.count == 4 && Int(token) != nil
    }

    private static func parseDate(month: String, day: String, timeOrYear: String) -> Date? {
        guard let monthIndex = monthNames.firstIndex(of: month),
              let dayValue = Int(day) else { return nil }
        let calendar = Calendar.current
        let now = Date()
        var components = DateComponents()
        components.month = monthIndex + 1
        components.day = dayValue
        if timeOrYear.contains(":") {
            let parts = timeOrYear.split(separator: ":")
            components.hour = Int(parts.first ?? "0")
            components.minute = parts.count > 1 ? Int(parts[1]) : 0
            components.year = calendar.component(.year, from: now)
            // `ls` 对近半年内的文件只显示时间：若解析结果晚于当前时间，说明是去年的文件
            if let date = calendar.date(from: components), date > now.addingTimeInterval(86_400) {
                components.year = (components.year ?? 0) - 1
            }
        } else {
            components.year = Int(timeOrYear)
        }
        return calendar.date(from: components)
    }
}

// MARK: - 子进程执行

/// 异步执行子进程并收集 stdout/stderr；读管道与等待退出都在后台线程完成
enum ProcessRunner {
    struct Result {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    private final class OutputBox {
        private let lock = NSLock()
        private var out = Data()
        private var err = Data()

        func append(_ data: Data, toStdout: Bool) {
            guard !data.isEmpty else { return }
            lock.lock()
            if toStdout { out.append(data) } else { err.append(data) }
            lock.unlock()
        }

        var stdout: String { lock.lock(); defer { lock.unlock() }; return String(data: out, encoding: .utf8) ?? "" }
        var stderr: String { lock.lock(); defer { lock.unlock() }; return String(data: err, encoding: .utf8) ?? "" }
    }

    static func run(executable: String, arguments: [String], environment: [String: String]) async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = environment
            process.standardInput = FileHandle.nullDevice

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            let box = OutputBox()
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    box.append(data, toStdout: true)
                }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    box.append(data, toStdout: false)
                }
            }
            process.terminationHandler = { finished in
                // 退出后把管道里剩余数据读干净，避免截断
                box.append(outPipe.fileHandleForReading.readDataToEndOfFile(), toStdout: true)
                box.append(errPipe.fileHandleForReading.readDataToEndOfFile(), toStdout: false)
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(
                    returning: Result(status: finished.terminationStatus, stdout: box.stdout, stderr: box.stderr)
                )
            }
            do {
                try process.run()
            } catch {
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: SFTPFailure(message: error.localizedDescription))
            }
        }
    }
}
