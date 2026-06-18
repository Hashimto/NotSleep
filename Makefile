.PHONY: build app run clean

APP_NAME := NotSleep
CONFIG := release
BUILD_DIR := .build/$(CONFIG)
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources

build:
	swift build -c $(CONFIG)

app: build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(MACOS_DIR)/$(APP_NAME)"
	plutil -create xml1 "$(CONTENTS_DIR)/Info.plist"
	plutil -insert CFBundleName -string "$(APP_NAME)" "$(CONTENTS_DIR)/Info.plist"
	plutil -insert CFBundleDisplayName -string "$(APP_NAME)" "$(CONTENTS_DIR)/Info.plist"
	plutil -insert CFBundleIdentifier -string "local.notsleep.app" "$(CONTENTS_DIR)/Info.plist"
	plutil -insert CFBundleExecutable -string "$(APP_NAME)" "$(CONTENTS_DIR)/Info.plist"
	plutil -insert CFBundlePackageType -string "APPL" "$(CONTENTS_DIR)/Info.plist"
	plutil -insert CFBundleVersion -string "1" "$(CONTENTS_DIR)/Info.plist"
	plutil -insert CFBundleShortVersionString -string "1.0" "$(CONTENTS_DIR)/Info.plist"
	plutil -insert LSMinimumSystemVersion -string "13.0" "$(CONTENTS_DIR)/Info.plist"
	plutil -insert NSAppleEventsUsageDescription -string "スリープ設定を管理者権限で切り替えるために使用します。" "$(CONTENTS_DIR)/Info.plist"

run: app
	open "$(APP_DIR)"

clean:
	rm -rf .build
