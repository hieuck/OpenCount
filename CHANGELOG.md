# Changelog

## [5.0.0] — 2026-06-15

### Added
- **ZapCount clone**: Complete image-first counting flow (pick → count → done)
- **Vision AI detection**: VNDetectRectanglesRequest for real object detection
- **Image cropping**: Drag-to-select area before counting
- **Multi-object counting**: Count different object types simultaneously
- **Object presets**: Quick-select common objects to count
- **Count history**: Auto-saved history of recent counts
- **CSV export**: Share count results as CSV files
- **Auto Release**: Push tag → build IPA → create GitHub Release automatically

### Fixed
- iOS crash: Simulator build → device build (arm64)
- Version number: 1.1 → 4.0.0
- Parse errors: Wrong Vision API → VNDetectRectanglesRequest
- CI: Missing simulator detection, YAML parsing, token permissions

### Platforms
- **iOS**: v4.5.0 IPA with Release configuration, device arm64
- **Android**: Full Jetpack Compose app with theme, splash, nav
- **Desktop**: Compose Desktop app with image counting
- **Web**: Kotlin/JS interactive counter

## [1.0.0] — 2026-06-14

### Added
- **Initial release**: OpenCount monorepo with KMP shared module
- **Cross-platform**: iOS (SwiftUI), Android (Jetpack Compose), Desktop (Compose Desktop), Web (Kotlin/JS)
- **Core models**: CountSession, ObjectType, CountMarker, CountRegion, SessionImage, VideoFrameCount, CountFormula, AIDetection, SessionTag, AnnotationLayer
- **Services**: Storage, Export (CSV/JSON/COCO), SmartCount (clustering, velocity, fatigue), SmartSuggestions, AI/NMS, CrashRecovery, PanoramaTiler, TemplateLibrary, SampleSessionSeeder
- **i18n**: 8 languages (EN, VI, JA, KO, ZH, FR, DE, ES) with 36 keys each
- **Testing**: 200+ unit/integration/e2e tests, 0 failures
- **CI/CD**: GitHub Actions workflows for KMP matrix + iOS

### Fixed
- Thread safety: uuid() uses Random instead of shared counter
- Thread safety: FormulaEvaluator uses per-call parser (no shared state)
- iOS build: Added all 4 missing Info.plist files
- JS/web: Fixed dynamic type issues, Compose plugin config
- Gradle: Removed duplicate version catalog entries
- Build: Added ProGuard rules, aligned Android Compose versions

### Notes
- See README.md for full architecture and setup guide
- See AGENTS.md for development conventions
