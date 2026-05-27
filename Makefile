APP_NAME = LiveWallpaper
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

# Detect SDK path using xcrun
SDK_PATH = $(shell xcrun --show-sdk-path)
SWIFT_FLAGS = -sdk $(SDK_PATH)

all: $(APP_BUNDLE)

$(APP_BUNDLE): Sources/main.swift Resources/Info.plist
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)
	swiftc $(SWIFT_FLAGS) -o $(MACOS_DIR)/$(APP_NAME) Sources/main.swift
	cp Resources/Info.plist $(CONTENTS_DIR)/Info.plist
	cp Resources/app_icon.webp $(RESOURCES_DIR)/app_icon.webp
	@echo "Built successfully at $(APP_BUNDLE)"

run: all
	open $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all run clean
