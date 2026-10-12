# Builds the menu bar app, the SMC helper and the distributable DMG.
# Requires macOS with the Xcode Command Line Tools.
VERSION ?= 0.01
BUILD   := build
APP     := $(BUILD)/MonitorPower.app
HELPER  := $(BUILD)/smc-power
DMG     := $(BUILD)/MonitorPower-$(VERSION).dmg
SOURCES := $(wildcard App/Sources/*.swift)
ARCH    := $(shell uname -m)
TARGET  := $(ARCH)-apple-macos12.0

.PHONY: all app helper dmg clean install uninstall

all: app

app: $(APP)

helper: $(HELPER)

dmg: $(DMG)

$(HELPER): helper/smc-power.c
	mkdir -p $(BUILD)
	clang -O2 -Wall -Wextra -arch $(ARCH) -mmacosx-version-min=12.0 -framework IOKit -o $@ $<
	codesign --force --sign - $@

# The helper and its install script ship inside the app so it can set itself up.
$(APP): $(SOURCES) App/Info.plist $(HELPER) scripts/helper-install.sh
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	swiftc -O -target $(TARGET) -o $(APP)/Contents/MacOS/MonitorPower $(SOURCES)
	cp App/Info.plist $(APP)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(APP)/Contents/Info.plist
	cp $(HELPER) scripts/helper-install.sh $(APP)/Contents/Resources/
	codesign --force --sign - $(APP)

$(DMG): $(APP)
	rm -rf $(BUILD)/dmg $@
	mkdir -p $(BUILD)/dmg
	cp -R $(APP) $(BUILD)/dmg/
	ln -s /Applications $(BUILD)/dmg/Applications
	hdiutil create -volname "Monitor Power $(VERSION)" -srcfolder $(BUILD)/dmg -ov -format UDZO $@
	rm -rf $(BUILD)/dmg

install: app
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

clean:
	rm -rf $(BUILD)
