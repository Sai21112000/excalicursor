APP_NAME = ExcaliCursor
BUILD_DIR = .build/release
APP_BUNDLE = build/$(APP_NAME).app
DMG_STAGING = build/dmg-staging
DMG_PATH = build/$(APP_NAME).dmg
CONTENTS_DIR = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

.PHONY: all build app dmg install run clean

all: app

build:
	swift build -c release

app: build
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(MACOS_DIR)/$(APP_NAME)"
	cp Info.plist "$(CONTENTS_DIR)/Info.plist"
	if [ -d "$(BUILD_DIR)/$(APP_NAME)_$(APP_NAME).bundle" ]; then \
		cp -R "$(BUILD_DIR)/$(APP_NAME)_$(APP_NAME).bundle" "$(RESOURCES_DIR)/"; \
	fi
	cp Sources/ExcaliCursor/Resources/* "$(RESOURCES_DIR)/"
	codesign --force --deep --sign - "$(APP_BUNDLE)" 2>/dev/null || true
	@echo "Built $(APP_BUNDLE)"

dmg: app
	rm -rf "$(DMG_STAGING)" "$(DMG_PATH)"
	mkdir -p "$(DMG_STAGING)"
	cp -R "$(APP_BUNDLE)" "$(DMG_STAGING)/"
	ln -s /Applications "$(DMG_STAGING)/Applications"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DMG_STAGING)" -ov -format UDZO "$(DMG_PATH)"
	rm -rf "$(DMG_STAGING)"
	@echo "Built $(DMG_PATH)"

install: app
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" "/Applications/$(APP_NAME).app"
	@echo "Installed to /Applications/$(APP_NAME).app"

run: app
	open "$(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf build
