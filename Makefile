.PHONY: build app xcode clean icon test

PROJECT := RimeManager
APP_DIR := $(PROJECT).app
BINARY := .build/arm64-apple-macosx/release/$(PROJECT)

build:
	swift build -c release

test:
	swift test

icon:
	@echo "Using official Rime icon (scripts/AppIcon.icns)"
	@test -f scripts/AppIcon.icns || (echo "ERROR: icon missing" && exit 1)

app: build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	mkdir -p "$(APP_DIR)/Contents/Resources"
	cp "$(BINARY)" "$(APP_DIR)/Contents/MacOS/"
	echo "APPL????" > "$(APP_DIR)/Contents/PkgInfo"
	plutil -create xml1 "$(APP_DIR)/Contents/Info.plist"
	plutil -replace CFBundleName -string "Rime Manager" "$(APP_DIR)/Contents/Info.plist"
	plutil -replace CFBundleDisplayName -string "Rime Manager" "$(APP_DIR)/Contents/Info.plist"
	plutil -replace CFBundleIdentifier -string "com.rimemanager.app" "$(APP_DIR)/Contents/Info.plist"
	plutil -replace CFBundleVersion -string "1" "$(APP_DIR)/Contents/Info.plist"
	plutil -replace CFBundleShortVersionString -string "1.3.0" "$(APP_DIR)/Contents/Info.plist"
	plutil -replace CFBundlePackageType -string "APPL" "$(APP_DIR)/Contents/Info.plist"
	plutil -replace CFBundleExecutable -string "$(PROJECT)" "$(APP_DIR)/Contents/Info.plist"
	plutil -replace LSMinimumSystemVersion -string "14.0" "$(APP_DIR)/Contents/Info.plist"
	plutil -replace NSHighResolutionCapable -bool YES "$(APP_DIR)/Contents/Info.plist"
	plutil -replace CFBundleIconFile -string "AppIcon" "$(APP_DIR)/Contents/Info.plist"
	if [ -f scripts/AppIcon.icns ]; then cp scripts/AppIcon.icns "$(APP_DIR)/Contents/Resources/AppIcon.icns"; fi
	@echo "App size: $$(du -sh "$(APP_DIR)" | awk '{print $$1}')"
	@echo "Launching $(APP_DIR)..."
	open "$(APP_DIR)"

release: icon app

xcode:
	open Package.swift

clean:
	swift package clean
	rm -rf $(APP_DIR) .build scripts/rime_icon.iconset
