# OpenCount Monorepo Makefile
# ===========================
# Targets for all platforms

# ─── iOS (XcodeGen) ──────────────────────────────────────────────────────────
IOS_PROJECT = OpenCount.xcodeproj

.PHONY: ios-generate ios-build ios-test ios-archive ios-ipa

ios-generate:
	xcodegen generate

ios-build:
	xcodegen generate && \
	xcodebuild -project $(IOS_PROJECT) -scheme OpenCount \
		-derivedDataPath .build/DerivedData \
		-destination 'platform=iOS Simulator,name=iPhone 16' build

ios-test:
	xcodegen generate && \
	xcodebuild -project $(IOS_PROJECT) -scheme OpenCount \
		-derivedDataPath .build/DerivedData \
		-destination 'platform=iOS Simulator,name=iPhone 16' test

ios-archive:
	xcodegen generate && \
	xcodebuild -project $(IOS_PROJECT) -scheme OpenCountIPA \
		-derivedDataPath .build/DerivedData \
		-archivePath .build/OpenCount.xcarchive archive

ios-ipa:
	xcodegen generate && \
	xcodebuild -project $(IOS_PROJECT) -scheme OpenCountIPA \
		-derivedDataPath .build/DerivedData \
		-archivePath .build/OpenCount.xcarchive archive && \
	xcodebuild -exportArchive -archivePath .build/OpenCount.xcarchive \
		-exportPath .build/OpenCount.ipa \
		-exportOptionsPlist ExportOptions.plist

# ─── KMP / Gradle (Android + Desktop + Web + Shared) ─────────────────────────
GRADLE = ./gradlew

.PHONY: kmp-build kmp-test kmp-check

kmp-build:
	$(GRADLE) build

kmp-test:
	$(GRADLE) :packages:shared:check

kmp-check:
	$(GRADLE) check

kmp-shared-publish:
	$(GRADLE) :packages:shared:publishToMavenLocal

# ─── Platform-specific KMP ───────────────────────────────────────────────────
.PHONY: android-build android-install desktop-run desktop-package

android-build:
	$(GRADLE) :apps:android:assembleDebug

android-install:
	$(GRADLE) :apps:android:installDebug

desktop-run:
	$(GRADLE) :apps:desktop:run --no-daemon

desktop-package:
	$(GRADLE) :apps:desktop:createRuntimeImage --no-daemon

# ─── All Tests ───────────────────────────────────────────────────────────────
.PHONY: test-all

test-all: ios-test kmp-test

# ─── Clean ───────────────────────────────────────────────────────────────────
.PHONY: clean clean-all

clean:
	$(GRADLE) clean
	rm -rf .build/DerivedData
	rm -rf $(IOS_PROJECT)

clean-all: clean
	rm -rf .build
	rm -rf ~/.gradle/caches/

# ─── Help ────────────────────────────────────────────────────────────────────
.PHONY: help

help:
	@echo "OpenCount Monorepo Targets:"
	@echo "  iOS:"
	@echo "    ios-generate  - Generate Xcode project"
	@echo "    ios-build     - Build for iOS Simulator"
	@echo "    ios-test      - Run iOS tests"
	@echo "    ios-archive   - Archive for App Store"
	@echo "    ios-ipa       - Build unsigned IPA"
	@echo ""
	@echo "  KMP (Cross-Platform):"
	@echo "    kmp-build     - Build all KMP targets"
	@echo "    kmp-test      - Run KMP tests"
	@echo "    kmp-check     - Run all checks"
	@echo ""
	@echo "  Platform-Specific:"
	@echo "    android-build - Build Android APK"
	@echo "    android-install - Install on connected device"
	@echo "    desktop-run   - Run Desktop app"
	@echo "    desktop-package - Package Desktop distributable"
	@echo ""
	@echo ""
	@echo "  Release:"
	@echo "    release          - Tag and verify production release"
	@echo ""
	@echo "  All: test-all   - Run all tests (iOS + KMP)"

# ─── Release ─────────────────────────────────────────────────────────────────
.PHONY: release

VERSION ?= $(shell git describe --tags --dirty 2>/dev/null || echo "1.0.0")

release:
	@echo "=== OpenCount Release $(VERSION) ==="
	$(GRADLE) :packages:shared:desktopTest
	$(GRADLE) :apps:desktop:compileKotlinDesktop
	$(GRADLE) :apps:web:compileKotlinJs
	@echo "=== All builds passed ==="
	git tag -a "v$(VERSION)" -m "Release v$(VERSION)"
	@echo "Tagged v$(VERSION). Push with: git push origin v$(VERSION)"
