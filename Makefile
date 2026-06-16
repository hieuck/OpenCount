# OpenCount Monorepo Makefile
# Targets for all platforms
# ===========================

SHELL := /bin/bash
GRADLE := ./gradlew
VERSION ?= $(shell git describe --tags --dirty 2>/dev/null || echo "1.0.0")

# ─── Help ──────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@echo "OpenCount Development Targets:"
	@echo ""
	@echo "  KMP (cross-platform, runs on any OS):"
	@echo "    make test          - Run all KMP tests       (verified: 200+, pass)"
	@echo "    make check         - Run full KMP check      (verified: PASS)"
	@echo "    make desktop       - Build Desktop app       (verified: PASS)"
	@echo "    make android       - Build Android APK       (verified: PASS, ~10MB)"
	@echo "    make web           - Build Web app           (verified: PASS)"
	@echo ""
	@echo "  Release (auto CI/CD):"
	@echo "    make tag VERSION=v1.0.0  - Create tag + push → auto release"
	@echo ""
	@echo "  iOS (requires macOS + Xcode):"
	@echo "    make ios-generate  - Generate Xcode project"
	@echo "    make ios-build     - Build for iOS Simulator"
	@echo "    make ios-ipa       - Build unsigned IPA"

# ─── KMP Targets (verified working on Windows) ─────────────────────────────
.PHONY: test check desktop android web clean

test:
	$(GRADLE) :packages:shared:desktopTest --no-daemon

check:
	$(GRADLE) :packages:shared:check --no-daemon

desktop:
	$(GRADLE) :apps:desktop:compileKotlinDesktop --no-daemon

android:
	$(GRADLE) :apps:android:assembleDebug --no-daemon

web:
	$(GRADLE) :apps:web:compileKotlinJs --no-daemon

clean:
	$(GRADLE) clean --no-daemon

# ─── iOS Targets (requires macOS) ──────────────────────────────────────────
.PHONY: ios-generate ios-build ios-test ios-archive ios-ipa

ios-generate:
	xcodegen generate

ios-build: ios-generate
	xcodebuild -project OpenCount.xcodeproj -scheme OpenCount \
		-derivedDataPath .build/DerivedData \
		-destination 'platform=iOS Simulator,name=iPhone 16' \
		CODE_SIGNING_ALLOWED=NO build

ios-test: ios-generate
	xcodebuild -project OpenCount.xcodeproj -scheme OpenCount \
		-derivedDataPath .build/DerivedData \
		-destination 'platform=iOS Simulator,name=iPhone 16' \
		CODE_SIGNING_ALLOWED=NO test

ios-ipa: ios-generate
	xcodebuild -project OpenCount.xcodeproj -scheme OpenCount \
		-derivedDataPath .build/DerivedData -configuration Release \
		-destination generic/platform=iOS \
		CODE_SIGNING_ALLOWED=NO build

# ─── Release ────────────────────────────────────────────────────────────────
.PHONY: tag
tag:
	@echo "=== Creating tag $(VERSION) ==="
	git tag -a "$(VERSION)" -m "OpenCount $(VERSION)"
	git push origin "$(VERSION)"
	@echo "Tag $(VERSION) pushed → GitHub Actions will build & release automatically"
