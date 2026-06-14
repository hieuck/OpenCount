# Contributing to OpenCount

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/OpenCount.git`
3. Set up development environment:
   - **iOS**: Xcode 16+, run `make ios-generate` to generate the Xcode project
   - **Android/Desktop**: JDK 17+, run `./gradlew :packages:shared:desktopTest` to verify
   - **All platforms**: Git, Make

## Development Workflow

### Code Organization

```
OpenCount/
├── apps/              # Platform-specific apps
│   ├── ios/           # SwiftUI (requires macOS)
│   ├── android/       # Jetpack Compose
│   ├── desktop/       # Compose Desktop
│   └── web/           # Kotlin/JS
└── packages/
    └── shared/        # KMP shared business logic
```

### Shared Module (KMP)

All business logic goes in `packages/shared/src/commonMain/`. Platform-specific code goes in `iosMain/`, `androidMain/`, `desktopMain/`, `jsMain/`.

**Patterns:**
- Models: `data class` with `@Serializable` annotation
- Services: Plain Kotlin classes, no platform dependencies
- Platform abstraction: `expect`/`actual` with interface delegation
- i18n: Add strings to `LocalizedStrings.kt` for all 8 languages

### Testing

- **Unit tests**: `commonTest/` — pure logic tests
- **Integration tests**: `commonTest/` — cross-service workflows
- **E2E tests**: `commonTest/e2e/` — full user workflow simulation
- Run: `./gradlew :packages:shared:desktopTest`

**Guidelines:**
- Target 200+ tests maintained
- Add tests for every new public function
- Include edge cases, null safety, and thread safety tests
- Use `FakePlatformStorage` for storage integration tests

### Pull Requests

1. Create a feature branch: `git checkout -b feat/your-feature`
2. Make changes with tests
3. Run all tests: `./gradlew :packages:shared:desktopTest`
4. Commit with conventional commits (feat:, fix:, test:, docs:, chore:)
5. Push and create a PR

### Commit Messages

```
feat: add new feature
fix: correct bug in service
test: add tests for component
docs: update documentation
chore: build/config changes
```

## Adding a New Language

1. Add strings to `LocalizedStrings.kt` following existing bundle format
2. Add language to `Desktop Main.kt` language switcher
3. Add language to `I18nTests.kt` test validation

## Release Process

1. Update `CHANGELOG.md`
2. Update version numbers across all `build.gradle.kts` files
3. Tag release: `git tag v1.0.0`
4. Push tag: `git push origin v1.0.0`
