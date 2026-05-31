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
│   │   └── DetectionOverlay.swift # Bounding box overlay
│   ├── ViewModels/
│   │   └── CountViewModel.swift # MVVM state
│   ├── Services/
│   │   └── DetectionService.swift # Core ML + Vision
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

| Tính năng | ZapCount | OpenCount |
|-----------|----------|-----------|
| Miễn phí | Web free, iOS 10 free/tháng | ✅ Hoàn toàn free |
| Mã nguồn mở | ❌ | ✅ MIT License |
| Offline | ❌ Cần internet | ✅ 100% on-device |
| Privacy | Ảnh gửi lên server | ✅ Ảnh không rời máy |

## Đóng góp

Pull requests được chào đón! Các hướng cần giúp:
- [ ] Port model YOLOv8 sang Core ML
- [ ] Thêm Apple Vision (iOS 17+)
- [ ] Hỗ trợ iPad multi-window
- [ ] Widget đếm nhanh từ Home Screen
- [ ] Export kết quả PDF/CSV

## License

MIT — Tự do sử dụng, chỉnh sửa, phân phối

---

*Được tạo bởi AI, dành cho cộng đồng. Không giới hạn, không quảng cáo, không tracking.*
