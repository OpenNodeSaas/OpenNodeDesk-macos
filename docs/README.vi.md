# OpenNodeDesk cho macOS

**Trung tâm kết nối từ xa ưu tiên cục bộ (local-first) dành cho macOS.** Gom mọi máy chủ, tài khoản và
tham số kết nối vào một danh sách có thể tìm kiếm, tái sử dụng và mang đi được — và đi từ "tôi cần máy
đó" đến một phiên làm việc trực tiếp chỉ trong ba bước.

[English](../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português](README.pt.md) · [Русский](README.ru.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · **[Tiếng Việt]**

Phiên bản hiện tại: **v2.3.5**

---

## Đây là gì

OpenNodeDesk không phải là một ứng dụng khách (client) điều khiển từ xa kiểu mới khác. Việc hiển thị
màn hình từ xa, chuyển tiếp thiết bị ngoại vi và âm thanh/hình ảnh đều bám theo ứng dụng khách trưởng
thành nhất của nền tảng — Microsoft Windows App cho RDP, tính năng chia sẻ màn hình (Screen Sharing)
tích hợp cho VNC, và terminal tích hợp cho SSH. OpenNodeDesk sở hữu **90% còn lại**: danh mục tài sản,
các tham số, thông tin đăng nhập, nhắc nhở hết hạn và lịch sử kết nối.

Nguyên tắc thiết kế:

- **Kết nối trong ba giây** — tìm kiếm, nhấn Return, phiên làm việc mở ra.
- **Ưu tiên cục bộ, hoạt động ngoại tuyến, không cần tài khoản** — mở, tìm kiếm, chỉnh sửa và kết nối mà
  không cần mạng.
- **Không dựng lại bánh xe** — việc hiển thị từ xa thuộc về ứng dụng khách tốt nhất của nền tảng.
- **Tham số có thể giải thích** — mỗi giá trị hiệu lực đều được gắn nhãn *tùy chỉnh / template / mặc định*.
- **Thất bại có thể giải thích** — lỗi đi kèm nguyên nhân và gợi ý có thể hành động, không bao giờ chỉ là
  một mã lỗi thô.
- **Dữ liệu có thể mang đi** — xuất và nhập chỉ bằng một cú nhấp; chuyển máy chỉ với một tệp duy nhất.
- **Ưu tiên bàn phím** — mọi thao tác cốt lõi đều có phím tắt.

## Tính năng

### Trung tâm tài sản
- Bố cục dạng bảng và dạng lưới; tìm kiếm theo tên, host, nhóm, người phụ trách và ghi chú.
- Mục yêu thích, kết nối gần đây và các nhóm có thể thu gọn ở thanh bên.
- Ẩn/hiện và sắp xếp lại theo từng cột, cùng cỡ chữ chung cho danh sách.
- Nhắc nhở hết hạn: các tài sản sắp hết hạn trong vòng 30 ngày (hoặc đã hết hạn) được đánh dấu ngay tại chỗ.
- Phát hiện trùng lặp theo **host + port** khi nhập.

### RDP / SSH / VNC
- Cổng mặc định theo từng giao thức (3389 / 22 / 5900) và có thể tùy ý ghi đè.
- **RDP** — tạo một tệp `.rdp` tạm thời cho Microsoft Windows App; chế độ cửa sổ, độ sâu màu, chuyển
  tiếp ổ đĩa/âm thanh/clipboard và độ phân giải đều có thể cấu hình. Các tệp nhị phân (binary) của
  FreeRDP được phát hiện và khởi chạy trực tiếp bằng mật khẩu đã lưu, bỏ qua hộp thoại nhập thông tin
  đăng nhập. Tính năng tự động điền mật khẩu cho hộp thoại đăng nhập của Windows App sử dụng API
  Accessibility của macOS.
- **VNC** — mặc định dùng tính năng chia sẻ màn hình tích hợp; các trình xem bên ngoài (RealVNC,
  TigerVNC…) có thể được cấu hình bằng một template đối số khởi chạy hỗ trợ
  `{host} {port} {display} {user} {password}`.
- **SSH** — một terminal thực sự được nhúng trong ứng dụng (SwiftTerm), với jump host (`-J`), xác thực
  bằng khóa riêng, hỗ trợ cụm mật khẩu khóa (key passphrase) và các đối số `ssh` bổ sung có thể cấu hình.

### Template kết nối
Các bộ tham số có thể tái sử dụng (giao thức, cổng, tên người dùng, chuyển tiếp, chế độ cửa sổ, độ sâu
màu, kích thước cửa sổ SSH). Mỗi tham số sau khi được phân giải đều hiển thị giá trị hiện tại **và
nguồn gốc của nó**.

### Không gian làm việc phiên
- Nhiều phiên làm việc nằm cạnh nhau với các bố cục chia khung có thể chuyển đổi, và tối đa hóa từng phiên.
- Một ô "mở tài sản" trên thanh công cụ: gõ tên hoặc host rồi nhấn Return, hoặc chọn từ danh sách.
- Hỗ trợ các cửa sổ SSH riêng khi bạn muốn chúng tách khỏi không gian làm việc.

### Truyền tệp SFTP
- Trình duyệt tệp từ xa đầy đủ cho từng tài sản: thư mục, kích thước, quyền, thời gian sửa đổi.
- Tải lên và tải xuống tệp hoặc cả thư mục, có thể tiếp tục (`reput` / `reget`).
- Tạo thư mục, xóa tệp hoặc thư mục rỗng, kéo thả tệp vào thư mục hiện tại.
- Có thể truy cập từ thanh công cụ của phiên và từ menu ngữ cảnh của terminal SSH.

### Menu ngữ cảnh của terminal SSH
Sao chép, dán, chọn tất cả và "truyền tệp" ngay tại nơi bạn đang gõ. Khi một chương trình từ xa chiếm
chuột (vim, tmux), thao tác nhấp chuột phải được chuyển tiếp đến chương trình từ xa như mong đợi.

### Thông tin đăng nhập
- Mật khẩu và cụm mật khẩu khóa **chỉ** được lưu trong Keychain của macOS, không bao giờ nằm trong các
  tệp dữ liệu.
- Xóa một tài sản hoặc bỏ chọn "ghi nhớ mật khẩu" sẽ xóa mục tương ứng trong Keychain.

### Nhập, xuất và đồng bộ
- Nhập từ CSV hoặc Excel (`.xlsx`) với tính năng ánh xạ cột tự động và bản xem trước kiểm tra hợp lệ.
- Xuất sang CSV hoặc JSON, với lựa chọn theo từng trường; các trường nhạy cảm mặc định được bỏ chọn.
- Đồng bộ đám mây tải bản xem trước trước và chỉ hợp nhất những gì bạn chọn — chỉ tài sản và template,
  không bao giờ có mật khẩu.

### Kiểm tra khả năng kết nối
Kiểm tra TCP cho từng tài sản, cho vùng chọn hoặc cho toàn bộ danh mục, theo yêu cầu hoặc theo hẹn giờ.

### Khóa ứng dụng (mật khẩu bảo vệ)
- Khóa bằng cụm mật khẩu tùy chọn kèm tự động khóa khi không hoạt động (1–60 phút).
- Băm cụm mật khẩu bằng **PBKDF2-SHA256**, 100 000 vòng lặp và một muối (salt) ngẫu nhiên 128-bit.
- Một mã khôi phục được cấp một lần khi thiết lập (Crockford Base32, chấp nhận cả `O/0`, `I/L/1`).
- Có thể cấu hình: sau 5 lần nhập sai liên tiếp, tự động xóa dữ liệu cục bộ, hoặc vẫn khóa và yêu cầu
  xóa thủ công.

### Giao diện và trợ giúp
- Chủ đề Theo hệ thống / Sáng / Tối; giao diện tiếng Trung giản thể và tiếng Anh.
- Sách hướng dẫn trợ giúp ngay trong ứng dụng, bao gồm cách dùng VNC, xử lý sự cố theo từng giao thức,
  vị trí dữ liệu và quyền riêng tư của thông tin đăng nhập.

## Yêu cầu

| Hạng mục | Yêu cầu |
| --- | --- |
| macOS | 14.0 (Sonoma) trở lên |
| Trình chạy RDP | Microsoft Windows App (từ App Store) |
| Trình chạy VNC | Tính năng chia sẻ màn hình tích hợp, hoặc RealVNC / TigerVNC và tương tự |
| Tự động điền mật khẩu RDP | Quyền Accessibility cho OpenNodeDesk |
| Biên dịch từ mã nguồn | Xcode 16 trở lên (bộ công cụ Swift 6) |

## Cài đặt

1. Tải xuống `OpenNodeDesk-<version>-macos.zip` từ trang
   [Releases](https://github.com/OpenNodeSaas/OpenNodeDesk-macos/releases).
2. Giải nén và kéo `OpenNodeDesk.app` vào `/Applications`.
3. Bản dựng này chưa được Apple công chứng (notarise), nên Gatekeeper có thể cảnh báo trong lần khởi
   chạy đầu tiên — nhấp chuột phải vào ứng dụng và chọn **Mở (Open)**, hoặc cho phép ứng dụng trong
   *System Settings → Privacy & Security*.

## Biên dịch từ mã nguồn

```bash
git clone https://github.com/OpenNodeSaas/OpenNodeDesk-macos.git
cd OpenNodeDesk-macos
make bundle   # release build + dist/OpenNodeDesk.app
make run      # build, bundle and launch
```

Các lệnh hữu ích: `make check` (biên dịch và hiển thị chẩn đoán), `make clean` (xóa `.build` và
`dist`), `make reset` (xóa dữ liệu cục bộ khỏi `~/Library/Application Support/RemotePilot`).

## Cấu trúc dự án

```
Sources/RemotePilot/
├── App/            Điểm khởi chạy ứng dụng, mô hình toàn cục, lệnh và menu
├── Core/           SSH/SFTP, Keychain, kiểm tra kết nối, nhập/xuất, đồng bộ, phát hiện trình chạy, tự động điền RDP
├── Design/         Token thiết kế và các thành phần dùng chung
├── Localization/   Chuỗi nguồn tiếng Trung + bảng chuỗi tiếng Anh
├── Models/         Mô hình tài sản, template, cài đặt và runtime
├── Views/          Thanh bên, trung tâm tài sản, không gian làm việc, phiên, cài đặt, trợ giúp, hộp thoại
└── main.swift      Điểm khởi chạy (cũng đóng vai trò trợ giúp SSH_ASKPASS)
Resources/          Info.plist và biểu tượng ứng dụng
docs/              Tài liệu thiết kế và các bản README đã dịch
```

## Dữ liệu và quyền riêng tư

- Tài sản, template và cài đặt nằm trong `~/Library/Application Support/RemotePilot`
  (`assets.json`, `settings.json`).
- Mật khẩu và cụm mật khẩu khóa chỉ được ghi vào Keychain của macOS; chúng không bao giờ là một phần
  của bản xuất hay payload đồng bộ. Do đó, chuyển sang máy khác sẽ cần nhập lại chúng.
- Ứng dụng hoạt động hoàn toàn ngoại tuyến; điểm cuối đồng bộ đám mây là tùy chọn và do người dùng tự
  cung cấp.

## Lưu ý và giới hạn

- Windows App trên macOS không thể chứa nhiều phiên dưới dạng tab trong một cửa sổ; nếu chọn chế độ cửa
  sổ dạng tab, nó sẽ mở một cửa sổ bình thường thay vào đó. Hãy dùng không gian làm việc phiên cho nhiều
  phiên.
- Nếu chưa cài trình chạy RDP nào, khi thử kết nối sẽ giải thích cần cài gì và ở đâu.
- Định danh bundle nội bộ `com.remotepilot.macos` và thư mục dữ liệu `RemotePilot` được giữ nguyên có
  chủ đích kể từ sau khi đổi tên, để các tài sản, cài đặt và mục Keychain hiện có vẫn hoạt động sau khi
  nâng cấp.

## Tài liệu

- [Thiết kế sản phẩm & UX](PRODUCT_UX_DESIGN.md)
- [Chênh lệch thiết kế](PRODUCT_UX_DESIGN_DELTA.md)
- [Khóa bằng cụm mật khẩu và tự động khóa khi nhàn rỗi](../.trae/documents/保护口令与空闲自动锁定-macOS.md)
