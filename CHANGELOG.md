# Changelog

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
