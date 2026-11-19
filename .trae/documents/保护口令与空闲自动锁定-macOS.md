# 保护口令与空闲自动锁定（macOS）实现计划

> 需求来源：`.trae/specs/add-protection-passphrase/spec.md`（原 spec 面向 Windows/C# 工程，本计划将其映射到当前的 macOS Swift/SwiftUI 工程 OpenNodeDesk），并在 spec 基础上增加**恢复口令**能力与**大气的口令窗口**要求。

## Summary

为 OpenNodeDesk 增加一个**可选**的应用级保护口令：

- 设置页新增「保护口令」区块：启用开关、口令 / 确认口令、空闲锁定时长（1/5/10/15/30/60 分钟，默认 10）、「立即锁定」按钮、风险提示。
- 口令以 **PBKDF2-SHA256 + 16 字节随机盐 + 10 万次迭代** 哈希后写入本地设置文件，不存明文。
- **每次设置 / 修改 / 重置口令，都会生成一串一次性展示的「恢复口令」**：以同样的 PBKDF2 哈希落库，明文只在设置完成时弹出的大气卡片里展示一次，供用户抄写或复制保存。忘记口令时，可在锁定窗口输入恢复口令 → 设置新口令 → **同时生成并展示新的恢复口令**（旧恢复口令立即失效）。
- 启用后：**启动即锁定**；空闲达阈值自动锁定；可手动「立即锁定」。
- 锁定态：主窗口（含工具栏）被全窗覆盖层遮挡并屏蔽交互；任何一次锁定都会**关闭所有子窗口（独立 SSH 窗口 + 各类 sheet）**。
- 口令 / 恢复口令均可错误重试；口令错 5 次后禁用口令输入（仍可用恢复口令），恢复口令也错 5 次后**只能清空本地数据**重置。
- 默认关闭：全新安装与旧配置升级后行为与现在完全一致。

## Current State Analysis

| 主题 | 现状（已核实） |
| --- | --- |
| 设置持久化 | [AppSettings.swift](file:///Users/samwhong/workspace/remotepilot_macos/Sources/RemotePilot/Models/AppSettings.swift) 是 `Codable` struct，由 [AppModel.loadFromDisk](file:///Users/samwhong/workspace/remotepilot_macos/Sources/RemotePilot/App/AppModel.swift#L122-L129) 从 `settings.json` 读取；[Storage.swift](file:///Users/samwhong/workspace/remotepilot_macos/Sources/RemotePilot/Core/Storage.swift) 负责读写，目录为 `~/Library/Application Support/RemotePilot` |
| 凭据 | [Keychain.swift](file:///Users/samwhong/workspace/remotepilot_macos/Sources/RemotePilot/Core/Keychain.swift) service = `com.remotepilot.macos`，账号键 `asset.<UUID>.password` / `asset.<UUID>.keypassphrase` |
| 设置页 | [SettingsView.swift](file:///Users/samwhong/workspace/remotepilot_macos/Sources/RemotePilot/Views/Settings/SettingsView.swift) 由若干 `CardContainer` 卡片组成，底部统一「保存」按钮 + `syncFromSettings()` / `save()` |
| 主窗口 | [RootView.swift](file:///Users/samwhong/workspace/remotepilot_macos/Sources/RemotePilot/Views/App/RootView.swift) = `NavigationSplitView` + `StatusBar`，sheet 由 `model` 上各 `@Published` 触发（`.sheet(item:)` / `.sheet(isPresented:)`）；[RemotePilotApp.swift](file:///Users/samwhong/workspace/remotepilot_macos/Sources/RemotePilot/App/RemotePilotApp.swift) 提供菜单命令 |
| 独立 SSH 窗口 | [SSHWindowManager.swift](file:///Users/samwhong/workspace/remotepilot_macos/Sources/RemotePilot/Views/Sessions/SSHWindowManager.swift) 单例，`handles: [UUID: Handle]`，已有 `closeWindow(forAsset:)`，**无 closeAll** |
| 国际化 | 中文原文为 key，英文表在 [EnglishStrings.swift](file:///Users/samwhong/workspace/remotepilot_macos/Sources/RemotePilot/Localization/EnglishStrings.swift)，缺项回落原文；`L()` 宏 |
| 构建 | `Package.swift` 只有一个 `executableTarget`，**无 testTarget**；`Makefile` 提供 `make check` / `make bundle` |
| 设计令牌 | [Tokens.swift](file:///Users/samwhong/workspace/remotepilot_macos/Sources/RemotePilot/Design/Tokens.swift)（`cardBackground` / `danger` / `mutedForeground` 等）与 [Components.swift](file:///Users/samwhong/workspace/remotepilot_macos/Sources/RemotePilot/Design/Components.swift) 的 `CardContainer` / `FormLabel` / `FieldHint` |

**已识别的风险（必须处理）**：Swift 对 struct 的**合成 Decodable 不会使用属性默认值**——旧 `settings.json` 缺少新增字段时整个 `AppSettings` 解码失败，`Storage.load` 返回 nil，用户全部设置（主题、语言、客户端路径…）被重置。因此在 `AppSettings` 中新增字段的同时，必须改为**逐字段 `decodeIfPresent` 的自定义解码**，这才是 spec 要求的「向前兼容」。

## Proposed Changes

### 1. 新增 `Sources/RemotePilot/Core/ProtectionHasher.swift`（新建）

纯函数式口令 / 恢复口令哈希工具，使用系统 CommonCrypto（`import CommonCrypto`，macOS SDK 自带模块，无需新增依赖）：

```swift
enum ProtectionHasher {
    static let iterations = 100_000
    static let keyLength = 32        // SHA-256
    static let saltLength = 16
    /// Crockford Base32（去掉易混的 I / L / O / U），不参与哈希、仅用于生成可读恢复口令
    private static let recoveryAlphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    static func makeSalt() -> Data                             // SecRandomCopyBytes
    static func derive(password: String, salt: Data) -> Data   // CCKeyDerivationPBKDF + kCCPRFHmacAlgSHA256
    static func create(_ secret: String) -> (salt: String, hash: String)   // 返回 Base64
    static func verify(_ secret: String, saltBase64: String, hashBase64: String) -> Bool
        // Base64 / 长度非法一律 false 不抛异常；比较用固定时间比较，避免时序泄漏

    /// 生成 20 位恢复口令，按 4 组 × 5 位用 "-" 分隔，如 K7M29-QPT4B-3VH8L-ZR6WX
    static func makeRecoveryCode() -> String
    /// 校验前归一化：去空格/连字符、转大写、O→0、I/L→1（容忍用户抄写误差）
    static func normalizeRecoveryCode(_ code: String) -> String

    private static func constantTimeEquals(_ a: Data, _ b: Data) -> Bool
}
```

- 恢复口令用同一个 `create/verify`（PBKDF2-SHA256）哈希，强度与口令一致；`makeRecoveryCode()` 的随机源同为 `SecRandomCopyBytes`。

### 2. `Sources/RemotePilot/Models/AppSettings.swift`（修改）

- 新增持久化字段：
  ```swift
  var protectionEnabled: Bool = false
  var protectionIdleMinutes: Int = 10
  var protectionSalt: String = ""
  var protectionHash: String = ""
  var protectionRecoverySalt: String = ""
  var protectionRecoveryHash: String = ""
  ```
- 新增常量：
  ```swift
  static let protectionIdleOptions = [1, 5, 10, 15, 30, 60]   // 分钟档位
  static let protectionDefaultIdleMinutes = 10
  ```
- **改为自定义 `init(from decoder:)`**：所有既有字段与新增字段一律 `decodeIfPresent(...) ?? 默认值`；解码后做规范化：
  - `protectionIdleMinutes` 不在 `protectionIdleOptions` 内 → 回落 `10`；
  - `protectionEnabled == true` 但 `protectionSalt` / `protectionHash` 任一为空 → 回落 `false`（避免永远无法解锁的死锁）。
- 新增便捷计算属性：
  ```swift
  var hasProtectionCredential: Bool { protectionEnabled && !protectionSalt.isEmpty && !protectionHash.isEmpty }
  var hasRecoveryCredential: Bool { !protectionRecoverySalt.isEmpty && !protectionRecoveryHash.isEmpty }
  ```

### 3. `Sources/RemotePilot/Core/SSHWindowManager.swift`（修改）

新增：

```swift
func closeAll() {
    for (_, handle) in handles { handle.window.delegate = nil; handle.window.close() }
    handles.removeAll()
}
```

（不走 `windowWillClose` 回调，避免重复 terminate 会话；会话清理由 `AppModel.lock()` 统一处理。）

### 4. `Sources/RemotePilot/App/AppModel.swift`（修改）

新增状态：

```swift
@Published var isLocked = false
@Published var unlockAttempts = 0        // 口令错误次数
@Published var recoveryAttempts = 0      // 恢复口令错误次数
@Published var unlockError: String?
@Published var recoverySheet: RecoveryCodeRequest?   // 触发「展示恢复口令」sheet
private var idleTimer: Timer?
```

新增请求模型（与既有 `EditorRequest` 等同风格）：

```swift
struct RecoveryCodeRequest: Identifiable {
    enum Reason { case created, reset }   // 首次启用/改口令 vs 用恢复口令重置后
    var id = UUID()
    var code: String
    var reason: Reason
}
```

新增/调整方法：

- `init()` 末尾：`loadFromDisk()` 之后，若 `settings.hasProtectionCredential` → `isLocked = true`；随后 `restartIdleMonitor()`。
- `saveSettings()` 末尾追加 `restartIdleMonitor()`。
- `@discardableResult func setProtection(enabled: Bool, idleMinutes: Int, newPassword: String?) -> String?`
  - 写回 `protectionEnabled` / `protectionIdleMinutes`；
  - `newPassword` 非空 → `ProtectionHasher.create` 生成新 salt/hash，并 `makeRecoveryCode()` 生成新恢复口令、同样 `create` 后写入 `protectionRecoverySalt/Hash`，**返回恢复口令明文**；
  - `newPassword` 为空 → 保留既有 salt/hash 与恢复口令，返回 `nil`；
  - `enabled == false` → 清空 4 个凭据字段；
  - `saveSettings()` 后返回结果。
- `restartIdleMonitor()`：`invalidate` 旧 timer；`guard settings.hasProtectionCredential else { return }`；`Timer.scheduledTimer(withTimeInterval: 5, repeats: true)` 中调用 `checkIdleLock()`。
- `checkIdleLock()`：`guard !isLocked, !hasOpenModalSheet() else { return }`；若 `systemIdleSeconds() >= Double(settings.protectionIdleMinutes * 60)` → `lock()`。
- `systemIdleSeconds() -> TimeInterval`：`CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)`（系统级最后输入时间，窗口后台/隐藏时同样有效；`~0` 即 `kCGAnyInputEventType`）。
- `hasOpenModalSheet() -> Bool`：任一 sheet 处于呈现态（`editorRequest/planRequest/credentialRequest/templateEditRequest/recoverySheet` 非 nil，或 `showImportSheet/showExportSheet/showSyncSheet/showFeedbackSheet` 为 true）；额外 `NSApp.keyWindow?.attachedSheet != nil` 兜底。
- `lock()`：
  1. 关闭所有 sheet（各 item 置 nil、各 bool 置 false）；
  2. `SSHWindowManager.shared.closeAll()`；
  3. `sessions.removeAll { $0.isDetached }`；
  4. `unlockAttempts = 0`、`recoveryAttempts = 0`、`unlockError = nil`、`isLocked = true`。
- `unlock(password:) -> Bool`：
  - 校验通过 → `isLocked = false`、两个计数清零、`unlockError = nil`、`restartIdleMonitor()`、`setStatus(就绪)`；
  - 失败 → `unlockAttempts += 1`，`unlockError = L("口令错误，还可尝试 {n} 次")`（`n = max(0, 5 - unlockAttempts)`）。
- `verifyRecoveryCode(_ code: String) -> Bool`：
  - 用 `normalizeRecoveryCode` 归一化后校验 `protectionRecoverySalt/Hash`；
  - 成功 → `recoveryAttempts = 0`、`unlockError = nil`，返回 true；
  - 失败 → `recoveryAttempts += 1`、`unlockError = L("恢复口令错误，还可尝试 {n} 次")`，返回 false。
- `resetPasswordWithRecovery(newPassword: String) -> String?`：等价于 `setProtection(enabled: true, idleMinutes: 现有档位, newPassword: newPassword)`，返回新恢复口令；随后 `isLocked = false`、两个计数清零、`restartIdleMonitor()`。
- `wipeLocalDataAndReset()`：删除 `settings.json` / `assets.json` / `templates.json` / `probe.json` / `layout.json`（`FileManager.removeItem`，忽略失败），清除这些资产在钥匙串中的 `password` / `keypassphrase`；随后 `TerminalRegistry.shared.terminateAll()` 并重置内存状态：`assets/templates/probeResults/sessions` 清空、`settings = AppSettings()`、`isLocked = false`、两个计数清零、`unlockError = nil`，`setStatus` 提示已重置。

> 会话/终端回收参照现有 `closeAllSessions()` 的写法（[AppModel.swift](file:///Users/samwhong/workspace/remotepilot_macos/Sources/RemotePilot/App/AppModel.swift#L668-L676)）。

### 5. 新增 `Sources/RemotePilot/Views/App/LockOverlayView.swift`（新建，**大气**）

全窗锁定覆盖层，`@EnvironmentObject var model: AppModel`。视觉基调：**不透明全窗底 + 居中大卡片**，宽松留白，圆角 16，柔和阴影，主按钮通栏。

- 底：`Tokens.appBackground` 铺满（可用 `.overlay` 加轻微径向渐变提升厚度感，不引入新色值）。
- 主卡片：宽 460 / 高自适应，`padding(gapXXL)`，`cornerRadius 16`，`Tokens.cardBackground` + `Tokens.softBorder` 描边 + `shadow(color: .black.opacity(0.18), radius: 24, y: 8)`。
- 内容（口令态）：
  - 锁图标 `lock.shield` 或 `lock.fill`，`font(.system(size: 44, weight: .light))`，`Tokens.accent`；
  - 标题「已锁定」`font(.system(size: 22, weight: .semibold))`；副标题「请输入保护口令以继续使用」`size 12`、`mutedForeground`；
  - 大号口令输入：`SecureField` + `.font(.system(size: 15))`、`.textFieldStyle(.plain)`、高 40、圆角 8、`Tokens.fieldBackground` + 描边（`.focused` 时描边用 `Tokens.accent`）；
  - 通栏主按钮「解锁」：`.buttonStyle(.borderedProminent)`、`.controlSize(.large)`、`.frame(maxWidth: .infinity)`、高 36；
  - `unlockError` 文案：`size 12`、`Tokens.danger`、`.fixedSize(horizontal:false, vertical:true)`；
  - 次要文字按钮「忘记口令？使用恢复口令重置」：`.buttonStyle(.link)`，`disabled(!model.settings.hasRecoveryCredential)`；
  - 回车提交：`.onSubmit { submit() }`；子视图 `@FocusState` 自动聚焦。
- 恢复口令态（两步）：
  1. **校验恢复口令**：标题「使用恢复口令」、说明文案、大号输入框（等宽字号 15、自动大写）、「验证」按钮、「返回」链接；
  2. **设置新口令**：口令 + 确认口令两个大号输入框、「重置并解锁」按钮；成功后 `model.recoverySheet = RecoveryCodeRequest(code: 新码, reason: .reset)` 展示新恢复口令。
  - 若 `model.recoveryAttempts >= 5` → 只保留「清空数据并进入」（二次确认 `confirmationDialog` → `model.wipeLocalDataAndReset()`）。
- 口令态 `model.unlockAttempts >= 5` 时：禁用口令框与「解锁」按钮，提示「口令已连续错误 5 次，可使用恢复口令重置，或清空本地数据」，保留恢复口令入口与「清空数据并进入」。

### 6. 新增 `Sources/RemotePilot/Views/App/RecoveryCodeSheet.swift`（新建，**大气**）

恢复口令展示 sheet，由 `model.recoverySheet` 驱动（`.sheet(item:)`），`onDisappear` 置 `model.recoverySheet = nil`。

- 卡片宽 520，`padding(gapXXL)`，圆角 16，标题区：图标 `key.fill` + 「你的恢复口令」`size 20 semibold`，副标题按 `reason` 区分：
  - `.created`：「口令已设置。请立即抄写或复制下面的恢复口令——它只显示这一次。忘记口令时用它重置。」
  - `.reset`：「口令已重置。下面是新的恢复口令，旧的已失效，请重新保存。」
- 口令码以大气的分块展示：4 组等宽大字（`font(.system(size: 20, weight: .semibold, design: .monospaced))`），每组一个圆角胶囊底；整体居中，字距放宽（`tracking(2)`）。
- 「复制」按钮（`NSPasteboard.general.clearContents(); setString(code, forType: .string)`），点击后 1.5 秒内文案切为「已复制」。
- 警示区：`Tokens.warning` 色提示「我们不会再次显示这串口令，也无法帮你找回；请妥善保存。」
- 通栏主按钮「我已妥善保存」→ 关闭 sheet。

### 7. `Sources/RemotePilot/Views/App/RootView.swift`（修改）

- 把现有 `NavigationSplitView { ... }` 包一层 `ZStack`：

```swift
ZStack {
    NavigationSplitView { ... }   // 现有内容保持不变
    if model.isLocked { LockOverlayView().environmentObject(model) }
}
```

- 覆盖层出现时隐藏命令工具栏：把 [commandToolbar](file:///Users/samwhong/workspace/remotepilot_macos/Sources/RemotePilot/Views/App/RootView.swift#L77-L128) 的条件由 `if showsCommandBar` 改为 `if showsCommandBar && !model.isLocked`（工具栏是 AppKit 独立视图，不被 overlay 遮挡，必须显式隐藏）。
- 根视图追加 `.allowsHitTesting(!model.isLocked)` 作为双保险。
- 新增 `.sheet(item: $model.recoverySheet) { RecoveryCodeSheet(request: $0) }`（与既有 sheet 并列）。

### 8. `Sources/RemotePilot/App/RemotePilotApp.swift`（修改）

锁定期间菜单快捷键仍需屏蔽。在每个会改变状态的命令动作闭包首行加 `guard !model.isLocked else { return }`（`新增资产`、`保存设置`、`导入资产`、`导出选中`、`云端同步`、`连接选中`、`打开连接方案`、`探测全部`、`探测选中`、`关闭当前会话`、`关闭全部会话`、`聚焦搜索`、`表格视图`、`宫格视图`、`切换详情面板`、`帮助手册`、`意见反馈`）。

### 9. `Sources/RemotePilot/Views/Settings/SettingsView.swift`（修改）

- 新增 `@State`：`protectionEnabled`、`idleMinutes: Int`、`password1`、`password2`，以及计算属性 `hasExistingPassword = model.settings.hasProtectionCredential`。
- 在 `independentWindowCard` 之后插入 `protectionCard`（`CardContainer(title: L("保护口令"))`）：
  - `Toggle(L("启用保护口令"), isOn: $protectionEnabled)`（`.switch`）；
  - `SecureField` 口令 / 确认口令 + `FormLabel`；`FieldHint` 说明「已设置口令时留空表示不修改口令」；
  - `Picker` 空闲锁定时长：`ForEach(AppSettings.protectionIdleOptions)`，文案 `"\(minutes)" + L(" 分钟")`，`.disabled(!protectionEnabled)`；
  - `Button(L("立即锁定"))`，`.disabled(!model.settings.protectionEnabled)`（只对**已保存**的启用状态生效，避免与「保存后弹恢复口令」流程交叠）；
  - 风险提示 `FieldHint`（`Tokens.warning` 文字色）：说明忘记口令可用恢复口令重置、两者都丢失且连续错误 5 次只能清空数据，给出数据文件路径 `~/Library/Application Support/RemotePilot/settings.json`（资产在 `assets.json`），提示提前备份。
- `syncFromSettings()` 回填上述状态；`save()`：
  - 校验：`protectionEnabled == true && !hasExistingPassword` 时，口令为空 / 少于 4 位 → `model.setStatus(..., kind: .failure)` 且**不落盘**并 `return`；两次不一致 → 同样拒绝并提示；
  - 其余既有设置照旧写回；新增部分调用：
    ```swift
    let newPassword: String? = (protectionEnabled && !password1.isEmpty) ? password1 : nil
    let recovery = model.setProtection(enabled: protectionEnabled, idleMinutes: idleMinutes, newPassword: newPassword)
    if let recovery { model.recoverySheet = RecoveryCodeRequest(code: recovery, reason: .created) }
    ```
  - 成功后清空 `password1` / `password2`（避免内存中残留明文）。
- 「立即锁定」动作：`model.saveSettings()`（确保已保存状态一致）后 `model.lock()`。

### 10. `Sources/RemotePilot/Localization/EnglishStrings.swift`（修改）

为以下新增中文键补齐英文（成对，键为中文原文）：

- 区块与控件：`保护口令`、`启用保护口令`、`口令`、`确认口令`、`空闲锁定时长`、`立即锁定`、` 分钟`、`已设置口令时留空表示不修改口令`
- 风险提示：「忘记口令可用恢复口令重置；连续 5 次错误只能清空本地数据。数据文件位于 …，请提前备份。」
- 锁定态：`已锁定`、`请输入保护口令以继续使用`、`解锁`、`口令错误，还可尝试 {n} 次`、`口令已连续错误 5 次，可使用恢复口令重置，或清空本地数据`
- 恢复口令：`你的恢复口令`、`忘记口令？使用恢复口令重置`、`使用恢复口令`、`验证`、`返回`、`恢复口令错误，还可尝试 {n} 次`、`重置并解锁`、`复制`、`已复制`、`我们不会再次显示这串口令，也无法帮你找回；请妥善保存。`、`我已妥善保存`、`口令已设置。…只显示这一次…`、`口令已重置。下面是新的恢复口令，旧的已失效，请重新保存。`
- 清空数据：`清空数据并进入`、`取消`、`口令与恢复口令均连续错误，只能清空本地数据后重新进入`、`本地数据已清空，保护口令已关闭`
- 校验错误：`启用保护口令时必须设置口令（至少 4 位）`、`两次输入的口令不一致`

## Assumptions & Decisions

1. **持久化位置**：保护口令相关字段写入 `settings.json`（属于 `AppSettings`），而非 spec 中 Windows 的 `assets.json`；这是 macOS 工程的既有约定（资产在 `assets.json`，设置在 `settings.json`）。
2. **向前兼容**：`AppSettings` 改用逐字段 `decodeIfPresent` 自定义解码，同时修掉「新增字段导致旧配置整体重置」的既有隐患（对齐 ponytail 规则 6）。
3. **恢复口令生成时机**：**每次设置 / 修改 / 重置口令都重新生成**，明文只展示一次，旧恢复口令立即失效——规则单一、无歧义，且不需要额外的「查看恢复口令」入口。
4. **错误计数分两档**：口令错 5 次只禁用口令输入（恢复口令仍可用），恢复口令再错 5 次才只剩「清空数据」。这是对 spec「5 次错误只能销毁」的合理细化——否则用户刚错 5 次就被剥夺了唯一自救手段。
5. **数据销毁兜底**：采用**就地重置**而非重启进程——删除本地数据文件 + 清空内存状态，直接以「空数据、保护口令关闭」进入应用；用户观感等价，且避免重启黑屏与重入风险。
6. **不新增单元测试 target**：当前 `Package.swift` 仅有一个 `executableTarget`，无法被测试 target import（需拆出 library，改动过大）。以 `swift build` 编译通过 + 手工清单为准；`ProtectionHasher` 仍写成无副作用纯函数，便于后续单独验证。
7. **锁定范围**：只锁主窗口交互（覆盖层 + 隐藏工具栏 + 菜单动作 guard）；独立 SSH 窗口不参与锁定，而是在锁定时被**关闭**（对齐 spec 范围说明）。
8. **关闭保护口令**：不强制二次输入当前口令（用户此刻已处于解锁态，可直接关闭）；关闭即清空 4 个凭据字段。
9. **「大气」的落地口径**：不引入新配色，仅通过大尺寸卡片（圆角 16 + 柔和阴影）、放大字号层级（22/20/15/12）、宽松间距（gapXXL）、通栏大按钮、大号输入框与恢复口令的分块等宽展示来体现；沿用 `Tokens` 现有语义色，兼容亮/暗模式。
10. `CGEventSource.secondsSinceLastEventType(.combinedSessionState, ...)` 为系统级空闲时间，无需任何系统授权。

## Verification

1. `make check`（`swift build -c release`）编译通过，无新增告警。
2. `make bundle` 出包成功（版本号不变，签名沿用固定自签名身份）。
3. 手工验证清单（UI 由用户自行确认）：
   - 默认关闭：新旧配置启动后行为与之前一致，`settings.json` 中 `protectionEnabled` 为 false。
   - 设置页可启用：启用 + 口令 <4 位 / 两次不一致 → 保存被拒并提示，`settings.json` 未变。
   - 启用保存后：立即弹出**大气的恢复口令卡片**，可复制、可关闭；`settings.json` 中只有 salt/hash，无明文。
   - 启用并保存后重启：启动即锁定，正确口令可进入。
   - 空闲锁定：设 1 分钟，无操作 1 分钟自动锁定；持续有键鼠输入不锁定；锁定期间有 sheet 打开时跳过。
   - 手动「立即锁定」：已保存启用时可用、关闭时禁用；点击后独立 SSH 窗口与 sheet 被关闭并进入锁定态。
   - 解锁：错误口令提示剩余次数并清空输入框；回车可提交；正确口令解锁后错误计数清零、空闲重新计时。
   - 恢复口令：锁定窗口点「忘记口令？使用恢复口令重置」→ 输入恢复口令（大小写/连字符容错）→ 设置新口令 → 弹出**新的**恢复口令卡片；旧恢复口令再试应失败。
   - 口令错 5 次：口令输入与解锁按钮禁用，恢复口令入口仍可用；恢复口令再错 5 次 → 只剩「清空数据并进入」，确认后 `settings.json`/`assets.json` 等被删除、钥匙串凭据清除，应用以空数据且保护口令关闭状态进入。
   - 中文/英文切换后，新增文案成对显示，无硬编码中文残留。
4. 兼容性回归：旧 `settings.json`（缺 6 个新字段）加载后主题/语言/客户端路径等既有设置**不丢失**，保护口令为关闭。
