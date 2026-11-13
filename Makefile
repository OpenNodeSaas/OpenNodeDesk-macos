APP_NAME := RemotePilot
BUNDLE_ID := com.remotepilot.macos
VERSION := 1.0.0
CONFIG := release
BIN := .build/$(CONFIG)/$(APP_NAME)
APP_DIR := dist/$(APP_NAME).app
CONTENTS := $(APP_DIR)/Contents

# 本机 DEVELOPER_DIR 可能指向失效的 Xcode 路径，这里优先使用真实存在的 Xcode。
REAL_XCODE := $(shell [ -d /Applications/Xcode.app/Contents/Developer ] && echo /Applications/Xcode.app/Contents/Developer)
ifneq ($(REAL_XCODE),)
export DEVELOPER_DIR := $(REAL_XCODE)
endif

.PHONY: all build bundle run dev clean reset check

all: bundle

build:
	swift build -c $(CONFIG)

bundle: build
	rm -rf $(APP_DIR)
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp $(BIN) $(CONTENTS)/MacOS/$(APP_NAME)
	sed -e 's/__VERSION__/$(VERSION)/g' -e 's/__BUNDLE_ID__/$(BUNDLE_ID)/g' Resources/Info.plist > $(CONTENTS)/Info.plist
	@printf 'APPL????' > $(CONTENTS)/PkgInfo
	@if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns $(CONTENTS)/Resources/; fi
	codesign --force --sign - $(APP_DIR) >/dev/null 2>&1 || true
	@echo "==> $(APP_DIR)"

run: bundle
	open $(APP_DIR)

dev:
	swift run $(APP_NAME)

clean:
	rm -rf .build dist

reset:
	rm -rf "$(HOME)/Library/Application Support/RemotePilot"

check:
	swift build -c $(CONFIG) 2>&1 | tail -n 30
