# AGENTS.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

## 5. OpenCount Project Conventions

### Monorepo Structure
```
apps/ios/          - iOS native (Swift/SwiftUI, Mac Catalyst planned)
apps/android/      - Android native (Kotlin/Jetpack Compose)
apps/desktop/      - Compose Desktop (Kotlin)
packages/shared/   - KMP shared module
```

### Build Commands
- `./gradlew :packages:shared:desktopTest` - Run cross-platform tests
- `./gradlew :packages:shared:check` - Build + check shared module
- `make ios-test` - Run iOS tests
- `make ios-generate` - Generate Xcode project

### KMP Shared Module
- `commonMain/` - All shared business logic (models, services, i18n)
- `iosMain/` - iOS-specific implementations (expect/actual)
- `androidMain/` - Android-specific implementations
- `desktopMain/` - Desktop (JVM) implementations
- `jsMain/` - Web (JS) implementations

### i18n
- All strings in `packages/shared/.../i18n/LocalizedStrings.kt`
- 8 languages: en, vi, ja, ko, zh, fr, de, es
- Access via `Strings.addMarker`, `Strings.sessions`, etc.

### Testing Layers
- **Unit tests**: `commonTest/` (pure model/utility logic)
- **Integration tests**: `commonTest/` (cross-service workflows)
- **E2E tests**: `commonTest/e2e/` (full user workflow simulation)
- **Property tests**: `apps/ios/tests/` (SwiftCheck)
- **UI tests**: `apps/ios/uitests/` (XCUITest)

### Model Migration (iOS → KMP)
- `Codable` → `@Serializable`
- `Date` → `kotlinx.datetime.Instant`
- `ObservableObject` → `data class`
- New models in KMP first, then Swift bridge
