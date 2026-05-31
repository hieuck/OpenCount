# OpenCount — Hướng dẫn Build IPA

Tài liệu này hướng dẫn cách build ứng dụng OpenCount thành file IPA sẵn sàng phân phối.

## Yêu cầu

- **macOS 14+** (Sonoma hoặc mới hơn)
- **Xcode 15+** (cài đặt từ App Store hoặc developer.apple.com)
- **iOS 17+** (deployment target)
- **Git** (để clone repo)

## Bước 1: Chuẩn bị môi trường

### 1.1 Cài đặt Xcode Command Line Tools

```bash
xcode-select --install
```

Nếu đã cài Xcode, bỏ qua bước này.

### 1.2 Kiểm tra phiên bản

```bash
xcodebuild -version
swift --version
```

## Bước 2: Clone repository

```bash
git clone https://github.com/your-org/OpenCount.git
cd OpenCount
```

## Bước 3: Tải YOLOv3 Model

Model AI (~200MB) cần được tải về trước khi build.

```bash
cd Scripts
chmod +x download_model.sh
./download_model.sh
```

**Kết quả mong đợi:**
```
🤖 OpenCount - Tải YOLOv3 Core ML Model
=========================================
📥 Đang tải model...
✅ Tải xong!
📍 Model: .../OpenCount_iOS/OpenCount/Resources/YOLOv3.mlmodel
```

Nếu tải thất bại, tải thủ công:
```bash
cd OpenCount_iOS/OpenCount/Resources
curl -fSL -o YOLOv3.mlmodel \
  "https://docs-assets.developer.apple.com/coreml/models/Image/ObjectDetection/YOLOv3.mlmodel"
```

## Bước 4: Mở project trong Xcode

```bash
cd OpenCount_iOS
open OpenCount.xcodeproj
```

## Bước 5: Cấu hình Signing

1. Chọn **OpenCount** project ở sidebar
2. Chọn **OpenCount** target
3. Đi tới tab **Signing & Capabilities**
4. Chọn team của bạn (hoặc tạo mới)
5. Xcode sẽ tự động cấu hình provisioning profile

## Bước 6: Build cho Simulator (Test)

```bash
cd OpenCount_iOS
xcodebuild -project OpenCount.xcodeproj \
  -scheme OpenCount \
  -configuration Debug \
  -sdk iphonesimulator \
  -derivedDataPath build
```

Hoặc dùng Xcode UI:
- Chọn simulator (ví dụ: iPhone 15 Pro)
- Nhấn **Cmd+R** để build & run

## Bước 7: Build cho Device (Release)

### 7.1 Build archive

```bash
cd OpenCount_iOS
xcodebuild -project OpenCount.xcodeproj \
  -scheme OpenCount \
  -configuration Release \
  -derivedDataPath build \
  -arch arm64 \
  -sdk iphoneos \
  -allowProvisioningUpdates \
  archive -archivePath build/OpenCount.xcarchive
```

### 7.2 Export IPA

```bash
xcodebuild -exportArchive \
  -archivePath build/OpenCount.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/
```

**Tạo ExportOptions.plist:**

```bash
cat > ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
EOF
```

Thay `YOUR_TEAM_ID` bằng Apple Team ID của bạn.

### 7.3 Kết quả

IPA file sẽ được tạo tại:
```
build/OpenCount.ipa
```

## Bước 8: Cài đặt IPA trên Device

### Cách 1: Dùng Xcode

```bash
xcodebuild -project OpenCount.xcodeproj \
  -scheme OpenCount \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  install
```

### Cách 2: Dùng Apple Configurator 2

1. Mở **Apple Configurator 2** (từ App Store)
2. Kết nối iPhone
3. Kéo file IPA vào cửa sổ Configurator
4. Chọn device và nhấn **Add**

### Cách 3: Dùng Transporter

1. Tải **Transporter** từ App Store
2. Mở Transporter
3. Kéo file IPA vào
4. Nhấn **Deliver**

## Bước 9: Phân phối (TestFlight / App Store)

### TestFlight (Internal Testing)

```bash
# Upload IPA lên TestFlight
xcrun altool --upload-app \
  -f build/OpenCount.ipa \
  -t ios \
  -u your-apple-id@example.com \
  -p your-app-specific-password
```

### App Store

1. Mở **App Store Connect** (appstoreconnect.apple.com)
2. Tạo app mới
3. Upload IPA qua Transporter
4. Điền thông tin app (description, screenshots, etc.)
5. Submit for Review

## Troubleshooting

### Lỗi: "Model not found"

```bash
# Kiểm tra model đã tải
ls -la OpenCount_iOS/OpenCount/Resources/YOLOv3.mlmodel

# Nếu không có, tải lại
cd Scripts && ./download_model.sh
```

### Lỗi: "Code signing failed"

```bash
# Reset signing
rm -rf ~/Library/Developer/Xcode/DerivedData/OpenCount*
xcodebuild clean -project OpenCount_iOS/OpenCount.xcodeproj
```

### Lỗi: "Provisioning profile not found"

1. Mở Xcode Preferences: **Cmd+,**
2. Đi tới **Accounts**
3. Chọn Apple ID
4. Nhấn **Manage Certificates**
5. Tạo certificate mới nếu cần

### Build quá lâu

```bash
# Xóa derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/OpenCount*

# Build lại
xcodebuild clean -project OpenCount_iOS/OpenCount.xcodeproj
```

## Tự động build với GitHub Actions

Xem `.github/workflows/build-ipa.yml` để cấu hình CI/CD tự động.

Khi push lên `main` branch, GitHub Actions sẽ:
1. Tải model YOLOv3
2. Build IPA
3. Upload artifact
4. Tạo release (nếu là tag)

## Hỗ trợ

- 📖 Xem README.md để biết thêm thông tin
- 🐛 Báo cáo lỗi: https://github.com/your-org/OpenCount/issues
- 💬 Thảo luận: https://github.com/your-org/OpenCount/discussions

---

**Ghi chú:** OpenCount là ứng dụng mã nguồn mở (MIT License). Bạn có thể tự do build, chỉnh sửa, và phân phối.
