# OpenCount — Makefile
# Convenience targets for local development and CI.
#
# Prerequisites (macOS only):
#   brew install xcodegen
#   brew install xcbeautify   (optional, prettier build output)

SCHEME        := OpenCount
PROJECT       := OpenCount.xcodeproj
WORKSPACE     := OpenCount.xcworkspace
SIMULATOR     := platform=iOS Simulator,name=iPhone 16,OS=latest
DERIVED_DATA  := $(PWD)/.build/DerivedData
ARCHIVE_PATH  := $(PWD)/.build/OpenCount.xcarchive
IPA_PATH      := $(PWD)/.build/OpenCount.ipa

# ─── Project generation ───────────────────────────────────────────────────────

.PHONY: generate
generate:
	xcodegen generate --spec project.yml
	@echo "✅  $(PROJECT) generated"

# ─── Build (Simulator — no signing required) ──────────────────────────────────

.PHONY: build
build: generate
	set -o pipefail && xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination "$(SIMULATOR)" \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		build \
	| xcbeautify || xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination "$(SIMULATOR)" \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		build

# ─── Test (Simulator) ─────────────────────────────────────────────────────────

.PHONY: test
test: generate
	set -o pipefail && xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination "$(SIMULATOR)" \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		test \
	| xcbeautify || xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination "$(SIMULATOR)" \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		test

# ─── Archive + IPA (requires signing — set DEVELOPMENT_TEAM) ─────────────────

.PHONY: archive
archive: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH) \
		-derivedDataPath $(DERIVED_DATA) \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) \
		CODE_SIGN_STYLE=Automatic \
		archive

.PHONY: ipa
ipa: archive
	xcodebuild \
		-exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(IPA_PATH) \
		-exportOptionsPlist ExportOptions.plist
	@echo "✅  IPA exported to $(IPA_PATH)"

# ─── Clean ────────────────────────────────────────────────────────────────────

.PHONY: clean
clean:
	rm -rf $(DERIVED_DATA) $(ARCHIVE_PATH) $(IPA_PATH)
	@echo "✅  Build artifacts cleaned"

.PHONY: clean-all
clean-all: clean
	rm -rf $(PROJECT)
	@echo "✅  Generated project removed"
