import AppKit
import ApplicationServices

/// Windows App 的凭据框不提供“记住密码”，外部也无法通过 .rdp 注入密码。
/// 这里在其密码框出现后，用辅助功能接口聚焦并把钥匙串里的密码键入，然后回车提交。
/// 全程只在内存中传递密码，不落盘；需要用户在系统设置中授予「辅助功能」权限。
@MainActor
enum RDPAutoFill {

    /// 诊断日志：unified log 有时抓不到，同时写一份到缓存目录便于排查
    private static func log(_ message: String) {
        NSLog("RDPAutoFill: %@", message)
        let url = Storage.cacheDirectory.appendingPathComponent("rdp-autofill.log")
        let line = "\(Date()) \(message)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// 请求「辅助功能」权限；已授权时返回 true，未授权会弹出系统引导
    @discardableResult
    static func requestPermission() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// 打开外部客户端后调用：轮询等待密码框出现并自动填入
    static func start(password: String, bundleID: String = "com.microsoft.rdc.macos") {
        guard !password.isEmpty else {
            log("无钥匙串密码，跳过自动填充")
            return
        }
        guard requestPermission() else {
            log("缺少「辅助功能」权限，已打开系统设置")
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        log("已授权，长度 \(password.count)，等待密码框出现")
        Task { @MainActor in
            let deadline = Date().addingTimeInterval(15)
            var lastReport: String?
            while Date() < deadline {
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                    let report = secureField(pid: app.processIdentifier)
                    if let field = report.field {
                        app.activate()
                        log("找到密码框")
                        submit(password: password, field: field, pid: app.processIdentifier)
                        return
                    }
                    if report.summary != lastReport {
                        lastReport = report.summary
                        log("未找到：\(report.summary)")
                    }
                } else {
                    if lastReport != "客户端未运行" {
                        lastReport = "客户端未运行"
                        log("未找到：客户端未运行")
                    }
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            log("等待超时，未找到密码框")
        }
    }

    // MARK: - 查找密码框

    private struct FieldScan {
        var field: AXUIElement?
        var summary: String
    }

    /// 遍历 AX 树查找安全输入框；同时返回节点统计，便于区分「权限不足」与「结构不匹配」
    private static func secureField(pid: pid_t) -> FieldScan {
        let app = AXUIElementCreateApplication(pid)
        var queue: [(AXUIElement, Int)] = [(app, 0)]
        var visited = 0
        var windows = 0
        var textFields = 0
        var errorCode: AXError = .success

        while !queue.isEmpty, visited < 4000 {
            let (element, depth) = queue.removeFirst()
            visited += 1
            if depth > 30 { continue }

            let role = attribute(element, kAXRoleAttribute) as? String
            let subrole = attribute(element, kAXSubroleAttribute) as? String
            if role == "AXWindow" { windows += 1 }
            if role == "AXTextField" { textFields += 1 }
            if role == "AXTextField", subrole == "AXSecureTextField" {
                return FieldScan(field: element, summary: "ok")
            }
            if role == "AXSecureTextField" {
                return FieldScan(field: element, summary: "ok")
            }

            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
            if result != .success, errorCode == .success { errorCode = result }
            if result == .success, let children = value as? [AXUIElement] {
                queue.append(contentsOf: children.map { ($0, depth + 1) })
            }
        }
        let summary = "节点 \(visited)，窗口 \(windows)，文本框 \(textFields)，错误 \(errorCode.rawValue)"
        return FieldScan(field: nil, summary: summary)
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    // MARK: - 填入并提交

    private static func submit(password: String, field: AXUIElement, pid: pid_t) {
        AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        // 安全输入框的值读不回，无法验证 AX 写值是否生效；
        // 统一只用键盘输入，避免「写值 + 键入」把密码填两遍
        clearField(pid: pid)
        typeUnicode(password, pid: pid)
        NSLog("RDPAutoFill: typed %ld chars", password.count)
        usleep(150_000)
        pressReturn(pid: pid)
    }

    /// 清空密码框里可能残留的旧内容，避免新旧密码拼接
    private static func clearField(pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        if let down = CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: true) {
            down.flags = .maskCommand
            down.postToPid(pid)
        }
        if let up = CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: false) {
            up.flags = .maskCommand
            up.postToPid(pid)
        }
        CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true)?.postToPid(pid)
        CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false)?.postToPid(pid)
    }

    private static func typeUnicode(_ text: String, pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        for character in text {
            var units = Array(String(character).utf16)
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
                down.postToPid(pid)
            }
            // keyUp 不再携带字符：否则同一个字符会被输入两次
            CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)?.postToPid(pid)
            usleep(8_000)
        }
    }

    private static func pressReturn(pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)?.postToPid(pid)
        CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)?.postToPid(pid)
    }
}
