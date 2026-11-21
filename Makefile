# 显示名（.app 包名 / 可执行名）。内部标识保持不变：
# BUNDLE_ID 与数据目录沿用旧名，保证升级后本地资产与钥匙串密码不失效。
APP_NAME := OpenNodeDesk
BUNDLE_ID := com.remotepilot.macos
VERSION := 2.3.6
CONFIG := release
BIN := .build/$(CONFIG)/$(APP_NAME)
APP_DIR := dist/$(APP_NAME).app
CONTENTS := $(APP_DIR)/Contents

# 本机 DEVELOPER_DIR 可能指向失效的 Xcode 路径，这里优先使用真实存在的 Xcode。
REAL_XCODE := $(shell [ -d /Applications/Xcode.app/Contents/Developer ] && echo /Applications/Xcode.app/Contents/Developer)
ifneq ($(REAL_XCODE),)
export DEVELOPER_DIR := $(REAL_XCODE)
endif

# 固定签名的本地自签名身份：每次构建的代码哈希不变，系统「辅助功能」等授权不会失效。
# 缺失时回退到 ad-hoc 签名。证书位于 ~/.opennodedesk-signing。
SIGN_IDENTITY := OpenNodeDesk Local Signing
HAS_SIGN_IDENTITY := $(shell security find-identity -v -p codesigning 2>/dev/null | grep -c "$(SIGN_IDENTITY)")

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
	@if [ "$(HAS_SIGN_IDENTITY)" != "0" ]; then \
		codesign --force --sign "$(SIGN_IDENTITY)" $(APP_DIR) >/dev/null 2>&1 || codesign --force --sign - $(APP_DIR); \
	else \
		codesign --force --sign - $(APP_DIR) >/dev/null 2>&1 || true; \
	fi
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
