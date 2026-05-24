# Auspex — build & packaging
# Common tasks:
#   make run       build (Debug) and launch
#   make build     build the Debug .app
#   make release   build the optimized Release .app
#   make dist      package a Release .zip into dist/ (for GitHub Releases)
#   make install   copy the Release build into /Applications
#   make icon      regenerate the app icon + menu bar glyph from Tools/
#   make clean     remove build artifacts and the generated Xcode project

APP_NAME  = Auspex
SCHEME    = Auspex
PROJECT   = Auspex.xcodeproj
CONFIG   ?= Debug
BUILD_DIR = build
DIST_DIR  = dist
VERSION  ?= 1.0
PRODUCT   = $(BUILD_DIR)/Build/Products/$(CONFIG)/$(APP_NAME).app
RELEASE_PRODUCT = $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app

# Ad-hoc sign ("Sign to Run Locally") — no Apple Developer account required.
SIGN_FLAGS = CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

.PHONY: all build run release dist install clean icon project check-tools

all: build

check-tools:
	@command -v xcodegen >/dev/null 2>&1 || { \
	  echo "error: xcodegen not found. Install it with:  brew install xcodegen"; exit 1; }

project: check-tools
	xcodegen generate

build: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
	  -derivedDataPath $(BUILD_DIR) $(SIGN_FLAGS) build
	@echo "\nBuilt: $(PRODUCT)"

run: build
	open "$(PRODUCT)"

release:
	$(MAKE) build CONFIG=Release

dist: release
	@mkdir -p $(DIST_DIR)
	@rm -f "$(DIST_DIR)/$(APP_NAME)-$(VERSION).zip" "$(DIST_DIR)/$(APP_NAME).zip"
	ditto -c -k --keepParent "$(RELEASE_PRODUCT)" "$(DIST_DIR)/$(APP_NAME)-$(VERSION).zip"
	@# Stable filename so README's "latest release" download link never changes.
	cp "$(DIST_DIR)/$(APP_NAME)-$(VERSION).zip" "$(DIST_DIR)/$(APP_NAME).zip"
	@echo "\nPackaged: $(DIST_DIR)/$(APP_NAME)-$(VERSION).zip and $(DIST_DIR)/$(APP_NAME).zip"
	@echo "Upload BOTH to the GitHub Release (the stable $(APP_NAME).zip powers the latest-download link)."

install: release
	@pkill -f "/Applications/$(APP_NAME).app" 2>/dev/null || true
	@rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(RELEASE_PRODUCT)" /Applications/
	@echo "Installed to /Applications/$(APP_NAME).app"

icon: check-tools
	swift Tools/makeicon.swift /tmp/auspex_icon.png
	@for s in 16 32 64 128 256 512 1024; do \
	  sips -z $$s $$s /tmp/auspex_icon.png --out Sources/Assets.xcassets/AppIcon.appiconset/icon_$$s.png >/dev/null; done
	swift Tools/makeglyph.swift Sources/Assets.xcassets/MenuBarGlyph.imageset/glyph_18.png 18 15
	swift Tools/makeglyph.swift Sources/Assets.xcassets/MenuBarGlyph.imageset/glyph_36.png 36 30
	swift Tools/makeglyph.swift Sources/Assets.xcassets/MenuBarGlyph.imageset/glyph_54.png 54 45
	@echo "Regenerated app icon + menu bar glyph"

clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR) $(PROJECT)
