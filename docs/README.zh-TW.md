# OpenNodeDesk（macOS 版）

**專為 macOS 打造的本地優先遠端連線中樞。** 把散落各處的伺服器、帳號與連線參數收進一份可搜尋、
可重複使用、可攜帶的資產清單，並把「我要連那台機器」壓縮到三步以內。

[English](../README.md) · [简体中文](README.zh-CN.md) · **[繁體中文]** · [日本語](README.ja.md) · [한국어](README.ko.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português](README.pt.md) · [Русский](README.ru.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [Tiếng Việt](README.vi.md)

目前版本：**v2.3.5**

---

## 這是什麼

OpenNodeDesk 不是另一套遠端桌面用戶端。遠端畫面的畫質、周邊設備重新導向與音訊視訊能力，跟隨各
平台最成熟的用戶端——RDP 使用 Microsoft Windows App，VNC 使用系統內建的「螢幕共享」，SSH 使用
內建終端機。OpenNodeDesk 負責的是**前面那 90%**：資產清單、連線參數、認證資料、到期提醒與連線記錄。

設計原則：

- **三秒發起連線**——搜尋、按下 Return、畫面出現。
- **本地優先、可離線使用、免帳號**——沒有網路也能開啟、搜尋、編輯與發起連線。
- **不重造輪子**——遠端畫面交給平台上最合適的用戶端。
- **參數可解釋**——每個生效值都標註來源：自訂 / 範本 / 預設。
- **失敗可解釋**——錯誤就地給出原因與可執行的建議，而不是丟一句原始錯誤碼。
- **資料可攜帶**——一鍵匯出與匯入，換機搬移只需要一個檔案。
- **鍵盤優先**——核心操作全都有快速鍵。

## 功能

### 資產中心
- 表格與方格兩種版面；可依名稱、主機、群組、負責人與備註搜尋。
- 側邊欄提供我的最愛、最近連線，以及可展開／收合的群組。
- 欄位可顯示／隱藏與重新排序，清單字級全域可調。
- 到期預警：剩餘 30 天內或已過期的資產會就地標示。
- 匯入時依**主機 + 連接埠**判斷重複。

### RDP / SSH / VNC
- 各協定預設連接埠（3389 / 22 / 5900），可自由覆寫。
- **RDP**——為 Microsoft Windows App 產生暫存 `.rdp` 檔；視窗模式、色彩深度、磁碟機／音訊／剪貼簿
  重新導向與解析度皆可設定。偵測到 FreeRDP 命令列用戶端時，會直接帶入鑰匙圈中的密碼，跳過認證
  對話框。Windows App 認證對話框的自動填入使用 macOS「輔助使用」介面。
- **VNC**——預設使用系統內建的「螢幕共享」；外掛用戶端（RealVNC、TigerVNC 等）可設定啟動參數
  範本，支援 `{host} {port} {display} {user} {password}` 佔位符。
- **SSH**——應用程式內嵌真實終端機（SwiftTerm），支援跳板主機（`-J`）、私密金鑰驗證、金鑰密語，
  以及自訂額外的 `ssh` 參數。

### 連線方案範本
可重複使用的參數組合（協定、連接埠、使用者名稱、重新導向、視窗模式、色彩深度、SSH 視窗尺寸）。
每個生效參數都會同時顯示**目前值**與**來源**。

### 工作階段工作台
- 多個工作階段並排，可切換分割版面，單一工作階段可最大化。
- 工具列內建「開啟資產」輸入框：輸入名稱或主機後按下 Return，或直接從清單挑選。
- 支援把 SSH 工作階段開成獨立視窗，不佔用工作台。

### SFTP 檔案傳輸
- 每個資產一個完整的遠端檔案瀏覽器：目錄、大小、權限、修改時間。
- 上傳與下載檔案或整個目錄，支援續傳（`reput` / `reget`）。
- 新增資料夾、刪除檔案或空目錄，支援把檔案拖曳到目前目錄上傳。
- 入口有兩個：工作階段工具列按鈕與 SSH 終端機右鍵選單。

### SSH 終端機右鍵選單
就在游標處提供複製、貼上、全選與「檔案傳輸」。遠端程式接管滑鼠時（例如 vim、tmux），右鍵照常
交給遠端程式處理。

### 認證資料
- 密碼與金鑰密語**只**存放在 macOS 鑰匙圈中，絕不寫入資料檔案。
- 刪除資產或取消勾選「記住密碼」時，會同步清除鑰匙圈項目。

### 匯入、匯出與同步
- 支援從 CSV 或 Excel（`.xlsx`）匯入，自動辨識欄位對應並提供驗證預覽。
- 支援匯出 CSV 或 JSON，可逐欄位勾選；敏感欄位預設不勾選。
- 雲端同步會先取得預覽、勾選後再合併；只同步資產與範本，不包含任何密碼。

### 可達性探測
對單一資產、選取項目或全部資產做 TCP 探測，可手動觸發，也可依間隔自動執行。

### 保護密語（應用程式鎖定）
- 選用的保護密語鎖定，支援閒置自動鎖定（1～60 分鐘）。
- 密語使用 **PBKDF2-SHA256** 雜湊，10 萬次迭代 + 128 位元隨機鹽。
- 設定時一次性發放救援碼（Crockford Base32，相容 `O/0`、`I/L/1` 等易混淆字元）。
- 可設定：連續輸入錯誤 5 次後自動清空本地資料，或維持鎖定並需要手動清空。

### 外觀與說明
- 跟隨系統 / 淺色 / 深色主題；介面支援簡體中文與英文。
- 應用程式內說明手冊：涵蓋 VNC 使用說明、各協定常見疑點、資料存放位置與認證資料隱私。

## 環境需求

| 項目 | 需求 |
| --- | --- |
| macOS | 14.0（Sonoma）或更新版本 |
| RDP 承載用戶端 | Microsoft Windows App（App Store 安裝） |
| VNC 承載用戶端 | 系統「螢幕共享」，或 RealVNC / TigerVNC 等 |
| RDP 密碼自動填入 | 為 OpenNodeDesk 開啟「輔助使用」權限 |
| 從原始碼建置 | Xcode 16 或更新版本（Swift 6 工具鏈） |

## 安裝

1. 到 [Releases](https://github.com/OpenNodeSaas/OpenNodeDesk-macos/releases) 頁面下載
   `OpenNodeDesk-<版本>-macos.zip`。
2. 解壓縮後把 `OpenNodeDesk.app` 拖進 `/Applications`。
3. 本建置未經 Apple 公證，首次啟動可能被 Gatekeeper 攔下——在應用程式上按右鍵並選擇「打開」，或在
   「系統設定 → 隱私權與安全性」中放行。

## 從原始碼建置

```bash
git clone https://github.com/OpenNodeSaas/OpenNodeDesk-macos.git
cd OpenNodeDesk-macos
make bundle   # release 建置 + dist/OpenNodeDesk.app
make run      # 建置、打包並啟動
```

常用目標：`make check`（編譯並輸出診斷）、`make clean`（清除 `.build` 與 `dist`）、
`make reset`（刪除 `~/Library/Application Support/RemotePilot` 中的本地資料）。

## 目錄結構

```
Sources/RemotePilot/
├── App/            應用程式進入點、全域模型、選單與命令
├── Core/           SSH/SFTP、鑰匙圈、探測、匯入匯出、同步、用戶端探測、RDP 自動填入
├── Design/         設計權杖與共用元件
├── Localization/   中文原文與英文語料表
├── Models/         資產、範本、設定與執行階段模型
├── Views/          側邊欄、資產中心、工作台、工作階段、設定、說明、對話框
└── main.swift      進入點（同時充當 SSH_ASKPASS 輔助程式）
Resources/          Info.plist 與應用程式圖示
docs/               設計文件與各語言 README
```

## 資料與隱私

- 資產、範本與設定存放在 `~/Library/Application Support/RemotePilot`
  （`assets.json`、`settings.json`）。
- 密碼與金鑰密語只寫入 macOS 系統鑰匙圈，不會出現在匯出檔案或同步內容中；因此換機後需要重新輸入。
- 應用程式可完全離線使用；雲端同步網址由使用者自行填寫，屬於選用項目。

## 說明與限制

- macOS 上的 Windows App 不支援在單一視窗內以分頁承載多個工作階段；選擇「分頁」模式時會以一般
  視窗開啟，多工作階段請使用「工作階段工作台」。
- 未偵測到 RDP 承載用戶端時，連線失敗會就地說明需要安裝什麼、到哪裡安裝。
- 更名後仍刻意保留內部識別 `com.remotepilot.macos` 與資料目錄 `RemotePilot`，以便升級後原有資產、
  設定與鑰匙圈項目繼續可用。

## 文件

- [產品與互動設計](PRODUCT_UX_DESIGN.md)
- [設計增量說明](PRODUCT_UX_DESIGN_DELTA.md)
- [保護密語與閒置自動鎖定](../.trae/documents/保护口令与空闲自动锁定-macOS.md)
