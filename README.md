# OpenCount

> AI-powered object counting for every platform. Native. Private. Open source.

OpenCount is a free, open-source, cross-platform AI-powered object counter that surpasses commercial alternatives (CountThings, Zap Count) with on-device AI detection, voice counting, AR counting, collaboration, and extensive export capabilities.

## Architecture

```
OpenCount/
├── apps/
│   ├── ios/                 # iOS/iPadOS native app (SwiftUI)
│   │   ├── app/             # Main target
│   │   ├── watch/           # watchOS companion
│   │   ├── widget/          # WidgetKit extension
│   │   ├── clip/            # App Clip
│   │   ├── tests/           # Property-based tests (SwiftCheck)
│   │   └── uitests/         # XCUITest smoke tests
│   ├── android/             # Android native app (Jetpack Compose)
│   ├── desktop/             # Desktop app (Compose for Desktop - Win/Mac/Linux)
│   └── web/                 # Web app (Kotlin/JS, scaffold)
├── packages/
│   └── shared/              # KMP shared module (cross-platform core)
│       └── src/
│           ├── commonMain/  # Shared business logic
│           ├── iosMain/     # iOS-specific implementations
│           ├── androidMain/ # Android-specific implementations
│           ├── desktopMain/ # Desktop-specific implementations
│           └── jsMain/      # Web-specific implementations
├── docs/                    # Documentation
├── project.yml              # XcodeGen project spec (iOS)
├── build.gradle.kts         # Gradle root (Android/Desktop/Web)
└── settings.gradle.kts      # Gradle settings
```

## Platform Coverage

| Platform | Tech Stack | Status |
|----------|------------|--------|
| iOS 16+ / iPadOS | SwiftUI, Vision, CoreML, ARKit | ✅ **Stable** |
| watchOS 9+ | SwiftUI, WCSession | ✅ **Stable** |
| macOS (Mac Catalyst) | SwiftUI (shared iOS code) | 🔄 Planned |
| Android | Kotlin, Jetpack Compose | ✅ **Stable** (APK ~10MB) |
| Desktop (Win/Mac/Linux) | Kotlin, Compose for Desktop | ✅ **Stable** |
| Web | Kotlin/JS | 🚧 Interactive prototype |

## Features

- **AI-Powered Detection**: On-device YOLOv8 via CoreML/Vision (iOS), ML Kit (Android)
- **Manual Counting**: Tap-to-count with multi-type categorization
- **Voice Counting**: Speech-to-text hands-free counting (multi-language)
- **Live Camera Counting**: Real-time object detection
- **AR Counting**: Augmented reality overlay counting (iOS ARKit)
- **Video Counting**: Frame-by-frame video analysis
- **Multi-Image Sessions**: Organize multiple images per session
- **Regions**: Define rectangular, elliptical, or polygonal count zones
- **Formulas**: Custom expressions for derived metrics
- **Tags & Search**: Color-coded tags with full-text search
- **Collaboration**: Real-time sync via CloudKit
- **Apple Pencil / Stylus**: Precision marking with hover ghost
- **Tally Mode**: Distraction-free counting interface
- **Heatmap**: Density visualization of markers
- **Export**: CSV, XLSX, JSON, COCO JSON, PDF, Annotated Image
- **Bulk Export**: Multi-session ZIP export
- **i18n**: 8 languages (English, Vietnamese, Japanese, Korean, Chinese, French, German, Spanish)
- **Templates**: Private template library + public marketplace

## AI Engine

- **On-device**: All AI runs locally — zero data leaves the device
- **Default Model**: YOLOv8-nano via CoreML (iOS) / TensorFlow Lite (Android)
- **Custom Models**: Import CoreML (.mlpackage) / TFLite models
- **Smart Counting**: Duplicate detection, clustering, fatigue warnings
- **Panorama Support**: Auto-tiling for large images with NMS dedup

## Quick Start

### Prerequisites

- **iOS**: Xcode 16+, CocoaPods or SPM (automatic)
- **Android/Desktop**: JDK 17+, Gradle 8.9+
- **All Platforms**: Git

### iOS

```bash
make ios-generate     # Generate Xcode project
make ios-build        # Build for simulator
make ios-test         # Run iOS tests
make ios-ipa          # Build unsigned IPA
```

### Android, Desktop & Shared (KMP)

```bash
./gradlew :packages:shared:check   # Build + test shared module
./gradlew :apps:android:assembleDebug  # Build Android APK
./gradlew :apps:desktop:run            # Run Desktop app
```

### All Tests

```bash
# KMP (cross-platform) — 200+ tests
./gradlew :packages:shared:desktopTest

# Android build
./gradlew :apps:android:assembleDebug

# Desktop build
./gradlew :apps:desktop:compileKotlinDesktop

# Web build
./gradlew :apps:web:compileKotlinJs

# iOS (requires macOS)
make ios-test
```

## Testing Strategy

| Layer | Type | Framework | Location |
|-------|------|-----------|----------|
| **Unit** | Model & utility tests | kotlin.test | `packages/shared/src/commonTest/` |
| **Integration** | Cross-service workflows | kotlin.test | `packages/shared/src/commonTest/` |
| **E2E** | Full user workflow simulation | kotlin.test | `packages/shared/src/commonTest/e2e/` |
| **Thread Safety** | Concurrent access & race conditions | kotlin.test | `packages/shared/src/commonTest/` |
| **Stress** | Large datasets (10K+ markers) | kotlin.test | `packages/shared/src/commonTest/` |
| **Property** | Invariant verification | kotlin.test | `packages/shared/src/commonTest/` |
| **i18n** | Multi-language string validation (8 langs) | kotlin.test | `packages/shared/src/commonTest/i18n/` |
| **SwiftCheck** | iOS property invariants | SwiftCheck | `apps/ios/tests/` |
| **UI** | XCUITest smoke & accessibility | XCTest | `apps/ios/uitests/` |

## Internationalization

8 languages built into the shared KMP module:

- English (default), Vietnamese, Japanese, Korean, Chinese
- French, German, Spanish

Switch at runtime via `Strings.language = "vi"`.

## License

Open source. Free forever. No telemetry, no accounts required.

## Comparison

| Feature | OpenCount | CountThings | Zap Count |
|---------|-----------|-------------|-----------|
| Native iOS | ✅ SwiftUI | ✅ | ✅ |
| Native Android | 🚧 Jetpack Compose | ❌ | ❌ |
| Desktop App | 🚧 Compose Desktop | ❌ | ❌ |
| Web App | 🗺️ Planned | ❌ | ❌ |
| On-device AI | ✅ YOLOv8 | ❌ (cloud) | ❌ (cloud) |
| Voice Counting | ✅ | ❌ | ❌ |
| AR Mode | ✅ (ARKit) | ❌ | ❌ |
| Video Analysis | ✅ | ❌ | ❌ |
| Bulk Export | ✅ | ❌ | ❌ |
| Collaboration | ✅ (CloudKit) | ❌ | ❌ |
| Custom AI Models | ✅ | ❌ | ❌ |
| Open Source | ✅ | ❌ | ❌ |
| Privacy (no cloud) | ✅ | ❌ | ❌ |
| Price | Free | $$$ | $$$ |
