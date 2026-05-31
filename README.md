# OpenCount 📸

Ứng dụng iOS **miễn phí, mã nguồn mở** để đếm vật thể bằng AI — thay thế mã nguồn mở cho [ZapCount](https://zapcount.com).

## Tính năng

- 📷 **Chụp ảnh hoặc chọn từ thư viện**
- 🤖 **AI tự động phát hiện** và đếm vật thể (Core ML + Vision)
- 📊 **Thống kê theo nhóm** — xem số lượng từng loại vật thể
- 🎨 **Overlay trực quan** — bounding box + label cho mỗi vật thể
- 📤 **Chia sẻ kết quả** — export text + thống kê
- 🌙 **Haptic feedback** khi có kết quả
- 🔒 **100% offline** — model chạy trên thiết bị, không cần internet
- 📜 **Lịch sử đếm** — xem lại các lần đếm trước
- ⚙️ **Tùy chỉnh độ nhạy** — điều chỉnh ngưỡng confidence

## Cài đặt

### Yêu cầu

- macOS 14+
- Xcode 15+
- iOS 17+ (simulator hoặc device)

### 1. Clone repo

```bash
git clone https://github.com/your-org/OpenCount.git
cd OpenCount
```

### 2. Tải model AI

```bash
cd Scripts
./download_model.sh
```

### 3. Mở trong Xcode

```bash
open OpenCount_iOS/OpenCount.xcodeproj
```

### 4. Build & Run

Nhấn `Cmd+R` hoặc chọn Product → Run

## Hướng dẫn Build IPA

Xem [**BUILD.md**](BUILD.md) — hướng dẫn chi tiết từ clone → build → IPA → phân phối.

Bao gồm:
- Cài đặt môi trường
- Tải model
- Cấu hình signing
- Build cho simulator & device
- Export IPA
- Troubleshooting

## Hướng dẫn Cài đặt IPA

Xem [**DISTRIBUTION.md**](DISTRIBUTION.md) — các cách cài đặt OpenCount trên thiết bị iOS.

- Qua Xcode
- Qua Apple Configurator 2
- Qua TestFlight
- Qua Safari (OTA install)

## Cấu trúc project

```
OpenCount_iOS/
├── OpenCountApp.swift           # Entry point
├── OpenCount/
│   ├── Models/
│   │   └── DetectedObject.swift # Data models
│   ├── Views/
│   │   ├── ContentView.swift    # Màn hình chính
│   │   ├── CameraView.swift     # Camera wrapper
│   │   ├── CountResultView.swift# Kết quả đếm
│   │   ├── DetectionOverlay.swift # Bounding box overlay
│   │   ├── HistoryView.swift    # Lịch sử đếm
│   │   ├── HistoryDetailView.swift # Chi tiết lịch sử
│   │   ├── SettingsView.swift   # Cài đặt
│   │   ├── StatisticsView.swift # Thống kê
│   │   └── ModelGuideView.swift # Hướng dẫn model
│   ├── ViewModels/
│   │   └── CountViewModel.swift # MVVM state
│   ├── Services/
│   │   ├── DetectionService.swift # Core ML + Vision
│   │   ├── ExportService.swift  # Export CSV/JSON/PDF
│   │   ├── HistoryService.swift # Lịch sử
│   │   └── StatisticsService.swift # Thống kê
│   ├── Utils/
│   │   └── Constants.swift      # Cấu hình
│   └── Resources/               # Model, storyboard
├── Assets.xcassets/             # App icons, images
└── Scripts/
    └── download_model.sh        # Tải YOLOv3 model
```

## Kiến trúc

```
┌─────────────────────────────────────────────┐
│                   UI Layer                   │
│  ContentView → CameraView → CountResultView  │
├─────────────────────────────────────────────┤
│                ViewModel Layer               │
│           CountViewModel (MVVM)              │
├─────────────────────────────────────────────┤
│                 Service Layer                │
│        DetectionService (Core ML)            │
├─────────────────────────────────────────────┤
│                   Data Layer                 │
│     DetectedObject, DetectionResult          │
└─────────────────────────────────────────────┘
```

## Model AI

OpenCount sử dụng **YOLOv3** được convert sang Core ML format. Model chạy hoàn toàn **on-device** — không cần internet, không gửi dữ liệu ra ngoài.

### Model thay thế

Bạn có thể dùng model khác bằng cách:
1. Download `.mlmodel` hoặc `.mlpackage`
2. Đặt vào thư mục `OpenCount/Resources/`
3. Sửa `Constants.modelName` thành tên model mới

## So sánh với ZapCount

- **Miễn phí**: OpenCount hoàn toàn free, ZapCount iOS có phí
- **Mã nguồn mở**: OpenCount MIT License, ZapCount đóng
- **Offline**: OpenCount 100% on-device, ZapCount cần internet
- **Privacy**: Ảnh không rời máy

## Phát triển

### Build IPA

```bash
# 1. Build archive
cd OpenCount_iOS
xcodebuild -project OpenCount.xcodeproj \
  -scheme OpenCount \
  -configuration Release \
  -derivedDataPath build \
  -arch arm64 \
  -sdk iphoneos \
  -allowProvisioningUpdates \
  archive -archivePath build/OpenCount.xcarchive

# 2. Export IPA
xcodebuild -exportArchive \
  -archivePath build/OpenCount.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/
```

### CI/CD

GitHub Actions tự động build IPA khi push lên `main`:
- **Platform**: `macos-latest`
- **Model**: YOLOv3 được tải tự động
- **Output**: IPA artifact, sẵn sàng tải về trong 30 ngày
- **Release**: Tự động tạo release cho tag

## Đóng góp

Pull requests được chào đón! Các hướng cần giúp:
- [x] Hoàn thiện SwiftUI views
- [x] CI/CD GitHub Actions
- [x] Hướng dẫn build và cài đặt
- [ ] Port model YOLOv8 sang Core ML
- [ ] Thêm Apple Vision (iOS 17+)
- [ ] Hỗ trợ iPad multi-window
- [ ] Widget đếm nhanh từ Home Screen
- [ ] Export kết quả PDF/CSV
- [ ] Dark mode support

## License

MIT — Tự do sử dụng, chỉnh sửa, phân phối

---

*Được tạo bởi AI, dành cho cộng đồng. Không giới hạn, không quảng cáo, không tracking.*
