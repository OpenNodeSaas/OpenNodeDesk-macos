# Tasks

- [ ] Task 1: 新增 `ProtectionHasher` 服务并写单元测试
  - [ ] SubTask 1.1: 在 `src/OpenNodeDesk/Services/ProtectionHasher.cs` 实现 `Create(string password)` 返回 `(string SaltBase64, string HashBase64)`，使用 PBKDF2-SHA256 + 16 字节随机盐 + 固定迭代次数（100000）
  - [ ] SubTask 1.2: 实现 `Verify(string password, string saltBase64, string hashBase64)`，用固定时间比较（`CryptographicOperations.FixedTimeEquals`）
  - [ ] SubTask 1.3: 在 `tests/OpenNodeDesk.Tests/` 增加测试：同口令不同盐产生不同哈希；正确口令校验通过；错误口令校验失败；空/非法参数返回 false 不抛异常
  - [ ] SubTask 1.4: 运行 `dotnet test tests\OpenNodeDesk.Tests\OpenNodeDesk.Tests.csproj -c Release --nologo` 全通过

- [ ] Task 2: `AssetStoreData` 新增保护口令字段并做向前兼容
  - [ ] SubTask 2.1: `Services/AssetStore.cs` 的 `AssetStoreData` 新增 `bool ProtectionEnabled { get; init; }`、`int ProtectionIdleMinutes { get; init; } = 10`、`string ProtectionSalt { get; init; } = ""`、`string ProtectionHash { get; init; } = ""`
  - [ ] SubTask 2.2: `Load()` 增加校验：`ProtectionIdleMinutes` 仅允许 1/5/10/15/30/60，非法回落 10；`ProtectionEnabled` 为 true 但 Salt/Hash 任一为空时回落为 false（避免永远无法解锁）
  - [ ] SubTask 2.3: 增加测试：旧格式 JSON（无新字段）加载后保护口令为关闭且空闲时长为 10；含新字段时可正确往返
  - [ ] SubTask 2.4: 构建并跑测试

- [ ] Task 3: 设置页新增「保护口令」区块
  - [ ] SubTask 3.1: `Controls/SettingsView.xaml` 在现有卡片序列后新增一个 `Border` 卡片（复用现有卡片样式），包含：启用勾选框、口令 `PasswordBox`、确认口令 `PasswordBox`、空闲时长 `ComboBox`（1/5/10/15/30/60 分钟）、「立即锁定」按钮、风险提示文本（含 `%LocalAppData%\FastRdp\RemoteOps\assets.json` 与「请提前备份」）
  - [ ] SubTask 3.2: 空闲时长选项与「立即锁定」按钮仅在启用时可用（未启用时 `IsEnabled=False`），口令框在已有口令时留空表示「不修改」
  - [ ] SubTask 3.3: `SettingsView.xaml.cs` 新增 `LoadSettings(...)` 入参（`protectionEnabled`、`protectionIdleMinutes`、`hasExistingPassword`）与对外属性（`ProtectionEnabled`、`ProtectionIdleMinutes`、`NewPassword`），并新增 `LockRequested` 事件供「立即锁定」按钮触发（保存前先落盘再触发，由主窗口处理锁定）
  - [ ] SubTask 3.4: `BtnSave_Click` 前增加校验：启用且无已保存口令时必须输入口令（≥4 位）且两次一致；启用且已有口令时留空视为不修改；校验失败弹提示并阻止 `Saved` 触发（用 `ValidationResult`/提前 return 实现）
  - [ ] SubTask 3.5: `ApplyStaticTexts()` 回填新增文案
  - [ ] SubTask 3.6: 构建通过

- [ ] Task 4: 主窗口锁定覆盖层
  - [ ] SubTask 4.1: `MainWindow.xaml` 在根 `Grid` 最后新增锁定覆盖层（默认 `Visibility=Collapsed`，`Panel.ZIndex` 最高，背景半透明+居中卡片）：标题、`PasswordBox`、解锁按钮、错误提示 `TextBlock`（含剩余次数）、清空数据提示区
  - [ ] SubTask 4.2: `MainWindow.xaml.cs` 增加 `EnterLock()` / `ExitLock()` 方法：`EnterLock()` 先关闭所有已打开子窗口（`OwnedWindows` 中可见窗口逐个 `Close()`），再切换覆盖层可见性、聚焦口令框、清空输入与错误提示
  - [ ] SubTask 4.3: 解锁逻辑：调用 `ProtectionHasher.Verify`；成功则 `ExitLock()` 并重置错误计数与空闲计时；失败则错误计数 +1、提示剩余次数、清空输入框
  - [ ] SubTask 4.4: 支持回车键解锁（`PasswordBox.KeyDown` 处理 `Key.Enter`）
  - [ ] SubTask 4.5: 接线设置页「立即锁定」：仅在保护口令已启用（或本次保存即启用）时可用；点击先保存设置、再调用 `EnterLock()`；未启用时按钮保持禁用
  - [ ] SubTask 4.6: 构建通过

- [ ] Task 5: 空闲检测与自动锁定
  - [ ] SubTask 5.1: 新增 `GetLastInputInfo` P/Invoke（`LASTINPUTINFO` 结构）封装到私有方法，返回距上次输入的毫秒数
  - [ ] SubTask 5.2: 用 `DispatcherTimer`（间隔 5 秒）在已启用保护口令且未锁定时检查；超过 `ProtectionIdleMinutes` 则 `EnterLock()`
  - [ ] SubTask 5.3: 若存在可见的模态子窗口（`OwnedWindows` 中可见窗口存在）则跳过本次判断
  - [ ] SubTask 5.4: 在 `OnClosed` 中停止并释放计时器；设置保存后按新的启用状态与时长重启/停止计时器
  - [ ] SubTask 5.5: 构建通过

- [ ] Task 6: 启动时锁定
  - [ ] SubTask 6.1: `LoadAssetsFromStore()` 完成后（窗口首次加载时）若 `ProtectionEnabled` 为 true，则 `EnterLock()`
  - [ ] SubTask 6.2: 启动锁定期间主窗口内容不可操作（覆盖层已屏蔽），且不触发自动锁定重复逻辑
  - [ ] SubTask 6.3: 手工验证：启用后重启程序，主窗口显示即锁定；输入正确口令后进入

- [ ] Task 7: 连续 5 次错误后的数据销毁兜底
  - [ ] SubTask 7.1: 错误计数达到 5 时禁用口令输入与解锁按钮，显示「只能清空本地数据后重新进入」提示与「清空数据并进入」按钮
  - [ ] SubTask 7.2: 点击后二次确认（`MessageBox` 警告会删除资产/模板/密码/口令），确认则删除 `assets.json` 并 `Application.Current.Shutdown()` 后重启程序（或用 `Process.Start` 重启当前 exe 后关闭）
  - [ ] SubTask 7.3: 取消则保持锁定态不可输入
  - [ ] SubTask 7.4: 手工验证：连续输错 5 次进入销毁界面；确认后程序以空数据且保护口令关闭状态启动

- [ ] Task 8: 设置保存接线与持久化
  - [ ] SubTask 8.1: `MainWindow.xaml.cs` 中 `SettingsView.Saved` 处理器读取新属性：启用则用 `ProtectionHasher.Create` 生成新 Salt/Hash（仅在输入了新口令时），关闭则清空 Salt/Hash
  - [ ] SubTask 8.2: `_assetStore.Save(data with { ProtectionEnabled = ..., ProtectionIdleMinutes = ..., ProtectionSalt = ..., ProtectionHash = ... })`
  - [ ] SubTask 8.3: 保存后重启空闲计时器，并在关闭保护口令时若处于锁定态则立即解锁
  - [ ] SubTask 8.4: `LoadAssetsFromStore()` 中把启用状态、时长、是否已有口令传给 `SettingsView.LoadSettings(...)`

- [ ] Task 9: 中英文文案补齐
  - [ ] SubTask 9.1: `Services/LocalizationManager.cs` 的 `_zhStrings` / `_enStrings` 成对新增：区块标题、启用、口令、确认口令、空闲时长、各档位文本、「立即锁定」、风险提示（含文件路径）、解锁标题/按钮/占位、错误提示模板（含剩余次数）、5 次错误销毁提示、销毁确认、保存校验错误（空/太短/不一致）
  - [ ] SubTask 9.2: 对应 `SettingsView` / `MainWindow` 的 `ResXxx` 常量与 XAML `DynamicResource` 已接上
  - [ ] SubTask 9.3: 构建通过

- [ ] Task 10: 最终验证
  - [ ] SubTask 10.1: `dotnet build OpenNodeDesk.sln -c Debug --nologo -v q` 0 警告 0 错误
  - [ ] SubTask 10.2: `dotnet test tests\OpenNodeDesk.Tests\OpenNodeDesk.Tests.csproj -c Release --nologo` 全部通过
  - [ ] SubTask 10.3: 手工验证清单：默认关闭不影响现有行为；启用后空闲锁定；打开 SSH 独立窗口后手动「立即锁定」会关闭该窗口并锁定；错误口令提示剩余次数；重启需口令；5 次错误可销毁重置

# Task Dependencies
- Task 2 依赖 Task 1（存储需要哈希格式）
- Task 3 依赖 Task 1、Task 2
- Task 4 依赖 Task 1、Task 2
- Task 5 依赖 Task 4
- Task 6 依赖 Task 4、Task 8
- Task 7 依赖 Task 4
- Task 8 依赖 Task 1、Task 2、Task 3
- Task 9 可与 Task 3/4 并行准备，但需在 Task 4、Task 8 之后统一补齐
- Task 10 依赖全部
