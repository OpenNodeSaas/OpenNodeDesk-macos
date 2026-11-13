import Foundation

// ssh 需要交互输入密码时会以本二进制作为 SSH_ASKPASS 程序回调（见 Views/Sessions/TerminalHost.swift）。
// 该分支必须早于 SwiftUI 启动处理：只向标准输出写出凭据后立即退出，不创建任何窗口。
if let assetID = ProcessInfo.processInfo.environment["REMOTEPILOT_ASKPASS"] {
    AskPass.run(assetID: assetID)
}

MainActor.assumeIsolated {
    RemotePilotApp.main()
}
