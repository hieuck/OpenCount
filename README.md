# OpenCount

[![CI — Build & Test](https://github.com/opencount-app/opencount/actions/workflows/ci.yml/badge.svg)](https://github.com/opencount-app/opencount/actions/workflows/ci.yml)
[![Build IPA](https://github.com/opencount-app/opencount/actions/workflows/build-ipa.yml/badge.svg)](https://github.com/opencount-app/opencount/actions/workflows/build-ipa.yml)

A free, open-source, native iOS application for AI-powered object counting in photos and live camera feeds.

## Features

- Zero-shot on-device AI detection (no templates required)
- Manual tap-to-count with undo/redo
- Multi-class counting with custom object types
- Region-of-interest filtering (rectangle, ellipse, polygon)
- Live camera counting
- Batch processing
- Rich export (CSV, JSON, annotated image, PDF)
- iCloud sync via CloudKit

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

---

## Project Setup

### 1. Create the Xcode Project

1. Open Xcode and choose **File → New → Project**.
2. Select **iOS → App** and click **Next**.
3. Fill in the fields:
   - **Product Name:** `OpenCount`
   - **Team:** Your Apple Developer team
   - **Organization Identifier:** e.g. `com.yourname`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** SwiftData
4. Uncheck "Include Tests" (we add the test target manually below).
5. Choose `e:\GitHub\OpenCount` as the save location and click **Create**.

### 2. Add Source Files

All Swift source files are already created in this repository. Add them to the Xcode project:

1. In the Xcode Project Navigator, right-click the `OpenCount` group and choose **Add Files to "OpenCount"**.
2. Select all files under `OpenCount/` and `OpenCount/Models/`, making sure **"Copy items if needed"** is unchecked (files are already in place).

### 3. Add the Test Target

1. In Xcode, go to **File → New → Target**.
2. Select **iOS → Unit Testing Bundle** and click **Next**.
3. Name it `OpenCountTests`, set the **Target to be Tested** to `OpenCount`, and click **Finish**.
4. Add the files under `OpenCountTests/` to the new test target.

### 4. Add SwiftCheck via Swift Package Manager

SwiftCheck is used for property-based testing.

1. In Xcode, go to **File → Add Package Dependencies…**
2. Enter the package URL:
   ```
   https://github.com/typelift/SwiftCheck
   ```
3. Select **Up to Next Major Version** starting from `0.12.0`.
4. Add the `SwiftCheck` library to the **`OpenCountTests`** target only (not the main app target).

### 5. Configure Deployment Target

1. Select the `OpenCount` project in the Navigator.
2. Under **Targets → OpenCount → General → Minimum Deployments**, set **iOS 16.0**.

### 6. Add the CoreML Model (Task 11)

The AI counting feature requires a YOLOv8-nano CoreML model:

```bash
# Install coremltools
pip install coremltools ultralytics

# Export YOLOv8n to CoreML
python -c "from ultralytics import YOLO; YOLO('yolov8n.pt').export(format='coreml', nms=True)"
```

Drag the resulting `yolov8n.mlpackage` into the Xcode project, adding it to the `OpenCount` app target.

---

## Project Structure

```
OpenCount/
├── OpenCountApp.swift          # @main App struct, ModelContainer setup
├── ContentView.swift           # Root view (replaced by SessionListView in Task 3)
└── Models/
    ├── CountSession.swift      # SwiftData model: counting session
    ├── ObjectType.swift        # SwiftData model: object type definition
    ├── CountMarker.swift       # SwiftData model: placed count marker
    ├── CountRegion.swift       # SwiftData model: ROI region + RegionShapeType enum
    ├── SessionImage.swift      # SwiftData model: imported image reference
    ├── VideoFrameCount.swift   # SwiftData model: per-frame video count
    ├── AIDetection.swift       # In-memory struct: AI detection result
    └── AppError.swift          # Typed error enum conforming to LocalizedError

OpenCountTests/
└── PropertyTests/
    └── SessionPersistenceTests.swift  # PBT: Property 8 — session round-trip
```

---

## Architecture

MVVM + Coordinator pattern:

```
SwiftUI Views
    ↓ @StateObject / @ObservedObject
ViewModels (SessionListVM, CountingVM, LiveCountVM, ExportVM)
    ↓ async/await
Services (CountingService, AIService, ExportService, StorageService)
    ↓
Data / Infrastructure (SwiftData, CloudKit, CoreML/Vision)
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.
