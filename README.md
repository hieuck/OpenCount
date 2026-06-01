# OpenCount

[![CI — Build & Test](https://github.com/opencount-app/opencount/actions/workflows/ci.yml/badge.svg)](https://github.com/opencount-app/opencount/actions/workflows/ci.yml)
[![Build IPA](https://github.com/opencount-app/opencount/actions/workflows/build-ipa.yml/badge.svg)](https://github.com/opencount-app/opencount/actions/workflows/build-ipa.yml)

**The most powerful free, open-source iOS counting app.** Surpasses ZapCount and CountThings with more features, better UX, and zero paywalls.

## Why OpenCount?

| Feature | OpenCount | ZapCount | CountThings |
|---------|-----------|----------|-------------|
| AI Object Detection | ✅ On-device YOLOv8 | ✅ | ✅ |
| Voice Counting | ✅ | ❌ | ❌ |
| Count Formulas | ✅ | ❌ | ❌ |
| Session Tags | ✅ | ❌ | ❌ |
| Bulk ZIP Export | ✅ | ❌ | ❌ |
| Cross-session Dashboard | ✅ | ❌ | ❌ |
| Smart Suggestions | ✅ | ❌ | ❌ |
| Apple Watch | ✅ | ❌ | ❌ |
| AR Counting | ✅ | ❌ | ❌ |
| Collaboration | ✅ CloudKit | ❌ | ❌ |
| COCO Export | ✅ | ❌ | ✅ |
| App Clip | ✅ | ❌ | ❌ |
| macOS Catalyst | ✅ | ❌ | ❌ |
| Open Source | ✅ MIT | ❌ | ❌ |
| **Price** | **Free** | Paid | Freemium |

## Features

### Core Counting
- Tap-to-place markers with undo/redo (50 levels)
- Multi-class counting with custom colors, icons, and target counts
- Distraction-free Tally Counter mode
- **Voice Counting** — hands-free counting via speech recognition
- Review Mode — step through all markers one by one
- Duplicate detection with smart warnings
- Fatigue warning for high-velocity counting

### AI Detection
- On-device YOLOv8-nano via CoreML/Vision (no internet required)
- Zero-shot similarity detection using VNFeaturePrintObservation
- Adjustable confidence threshold
- "Find Missed Objects" secondary AI pass
- Batch processing for multiple images
- Custom CoreML model import

### Organization
- **Session Tags** — color-coded tags with emoji for quick organization
- **Smart Suggestions** — recommends object types from past sessions
- Search and filter sessions
- Session templates (private library + community marketplace)
- iCloud sync via CloudKit

### Analytics
- **Cross-session Dashboard** — activity timeline, top object types, trends
- **Count Formulas** — custom expressions like "Males / (Males + Females)"
- Per-session statistics with pie charts, bar charts, density analysis
- Tally change history (audit log)
- Cross-session comparison charts

### Export
- CSV (RFC 4180 compliant, localized headers)
- JSON (structured, ISO 8601 dates)
- COCO JSON (compatible with Roboflow, CVAT, Label Studio)
- Annotated Image (PNG with markers, regions, annotations)
- PDF report (image + tally table + metadata)
- **Bulk ZIP Export** — export multiple sessions at once

### Platform
- iPhone + iPad (adaptive layout, Stage Manager support)
- Apple Watch companion app with complications
- WidgetKit home screen widget
- App Clip for quick counting via NFC/QR
- macOS Catalyst support
- AR counting via ARKit
- Live camera counting
- Handoff between devices
- Siri Shortcuts integration
- Local REST API for automation (localhost:47200)

## Requirements

- iOS 16.0+
- Xcode 16.0+
- Swift 5.9+
- xcodegen (`brew install xcodegen`)

## Quick Start

```bash
# Clone the repo
git clone https://github.com/opencount-app/opencount.git
cd opencount

# Generate the Xcode project
make generate

# Build for simulator
make build

# Run tests
make test
```

## Building an IPA

```bash
# Set your Apple Developer Team ID
export DEVELOPMENT_TEAM=YOUR_TEAM_ID

# Archive and export IPA
make ipa
```

The IPA will be at `.build/OpenCount.ipa`.

## Adding the AI Model

```bash
pip install coremltools ultralytics
python -c "from ultralytics import YOLO; YOLO('yolov8n.pt').export(format='coreml', nms=True)"
```

Drag `yolov8n.mlpackage` into the Xcode project (OpenCount target). Without the model, the app runs in mock mode with synthetic detections.

## Architecture

```
SwiftUI Views
    ↓ @StateObject / @ObservedObject
ViewModels (SessionListVM, CountingVM, LiveCountVM, AnnotationLayerVM, ...)
    ↓ async/await
Services (AIService, ExportService, StorageService, CollaborationService,
          VoiceCountingService, BulkExportService, SmartSuggestionsService, ...)
    ↓
Data / Infrastructure (SwiftData, CloudKit, CoreML/Vision, Speech, ARKit)
```

## Project Structure

```
OpenCount/
├── Models/          — SwiftData models + in-memory structs
├── Views/           — SwiftUI views (40+ screens)
├── ViewModels/      — ObservableObject view models
├── Services/        — Business logic and platform integrations
├── Intents/         — App Intents for Siri Shortcuts
└── Resources/       — Localizable strings, sample data

OpenCountWatch/      — watchOS companion app
OpenCountWidget/     — WidgetKit extension
OpenCountClip/       — App Clip (< 15 MB)
OpenCountTests/      — Unit + property-based tests
OpenCountUITests/    — UI tests with accessibility audit
```

## License

MIT License — free forever, no paywalls, no subscriptions.
