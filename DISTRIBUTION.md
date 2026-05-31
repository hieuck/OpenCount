# OpenCount — Hướng dẫn Cài đặt IPA

Tài liệu này hướng dẫn cách cài đặt ứng dụng OpenCount trên thiết bị iOS.

## Phương pháp 1: Qua Xcode (Khuyến nghị cho Developer)

### Bước 1: Kết nối thiết bị

- Kết nối iPhone/iPad qua USB
- Mở Xcode → Window → Devices and Simulators
- Đảm bảo thiết bị xuất hiện trong danh sách

### Bước 2: Build & Run

```bash
cd OpenCount_iOS
xcodebuild -project OpenCount.xcodeproj \
  -scheme OpenCount \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  install
```

Hoặc dùng Xcode UI:
1. Mở `OpenCount.xcodeproj`
2. Chọn thiết bị ở thanh toolbar
3. Nhấn **Cmd+R** để build & run

### Bước 3: Tin cậy thiết bị

Sau khi cài đặt:
1. Mở **Cài đặt** → **Cài đặt chung** → **Quản lý thiết bị**
2. Tìm "Apple Development: [Email của bạn]"
3. Nhấn **Tin cậy**

## Phương pháp 2: Qua Apple Configurator 2 (Không cần Developer Account)

### Bước 1: Tải Apple Configurator 2

- Mở App Store
- Tìm "Apple Configurator 2"
- Tải và cài đặt

### Bước 2: Kết nối thiết bị

- Kết nối iPhone/iPad qua USB
- Mở Apple Configurator 2
- Thiết bị sẽ xuất hiện trong danh sách

### Bước 3: Cài đặt IPA

1. Kéo file `OpenCount.ipa` vào cửa sổ Configurator
2. Chọn thiết bị
3. Nhấn **Add**
4. Chờ quá trình cài đặt hoàn tất

### Bước 4: Tin cậy ứng dụng

1. Mở **Cài đặt** → **Cài đặt chung** → **Quản lý thiết bị**
2. Tìm "Apple Development: [Email của bạn]"
3. Nhấn **Tin cậy**

## Phương pháp 3: Qua TestFlight (Phân phối nội bộ)

### Bước 1: Upload IPA lên App Store Connect

```bash
xcrun altool --upload-app \
  -f OpenCount.ipa \
  -t ios \
  -u your-apple-id@example.com \
  -p your-app-specific-password
```

### Bước 2: Cấu hình TestFlight

1. Mở [App Store Connect](https://appstoreconnect.apple.com)
2. Chọn app **OpenCount**
3. Đi tới **TestFlight**
4. Thêm người dùng test nội bộ
5. Nhấn **Gửi đến những người dùng này**

### Bước 3: Cài đặt từ TestFlight

1. Người dùng nhận email mời test
2. Nhấn **Accept** trong email
3. Mở link trong TestFlight app
4. Nhấn **Install**

## Phương pháp 4: Qua Safari (Over-the-Air)

### Bước 1: Tải IPA lên server HTTPS

File `manifest.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>items</key>
    <array>
        <dict>
            <key>assets</key>
            <array>
                <dict>
                    <key>kind</key>
                    <string>software-package</string>
                    <key>url</key>
                    <string>https://your-server.com/OpenCount.ipa</string>
                </dict>
            </array>
            <key>metadata</key>
            <dict>
                <key>bundle-identifier</key>
                <string>com.openproblem.openCount</string>
                <key>bundle-version</key>
                <string>1.0.0</string>
                <key>kind</key>
                <string>software</string>
                <key>title</key>
                <string>OpenCount</string>
            </dict>
        </dict>
    </array>
</dict>
</plist>
```

### Bước 2: Tạo link install

```html
<a href="itms-services://?action=download-manifest&url=https://your-server.com/manifest.plist">
  Install OpenCount
</a>
```

### Bước 3: Mở link trên iPhone

- Mở Safari trên iPhone
- Truy cập trang có link install
- Nhấn **Install**

**Lưu ý:** Server phải có HTTPS và chứng chỉ hợp lệ.

## Troubleshooting

### Lỗi: "Không thể cài đặt ứng dụng"

**Nguyên nhân:** Chưa tin cậy nhà phát triển

**Giải pháp:**
1. Mở **Cài đặt** → **Cài đặt chung** → **Quản lý thiết bị**
2. Tìm nhà phát triển
3. Nhấn **Tin cậy**

### Lỗi: "Không đủ dung lượng"

**Giải pháp:**
1. Xóa ứng dụng cũ (nếu có)
2. Giải phóng dung lượng
3. Thử lại

### Lỗi: "Không thể xác minh nhà phát triển"

**Giải pháp:**
1. Mở **Cài đặt** → **Cài đặt chung** → **Quản lý thiết bị**
2. Chờ vài phút để Apple xác minh
3. Nhấn **Tin cậy**

### Lỗi: "Phiên bản iOS không hỗ trợ"

**Giải pháp:**
- OpenCount yêu cầu iOS 17+
- Cập nhật iOS lên phiên bản mới nhất

## Cập nhật ứng dụng

### Qua Xcode
- Build & run lại ứng dụng mới

### Qua TestFlight
- Người dùng nhận thông báo cập nhật
- Nhấn **Update** trong TestFlight

### Qua OTA
- Mở lại link install
- Ứng dụng sẽ tự động cập nhật

## Hỗ trợ

- 📖 Xem [BUILD.md](BUILD.md) để biết cách build IPA
- 🐛 Báo cáo lỗi: https://github.com/your-org/OpenCount/issues
- 💬 Thảo luận: https://github.com/your-org/OpenCount/discussions

---

**Ghi chú:** OpenCount là ứng dụng mã nguồn mở (MIT License). Bạn có thể tự do cài đặt, chỉnh sửa, và phân phối.
