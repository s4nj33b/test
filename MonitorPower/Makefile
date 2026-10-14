# Builds the menu bar app, the SMC helper and the distributable DMG.
# Requires macOS with the Xcode Command Line Tools.
VERSION ?= 0.02
BUILD   := build
APP     := $(BUILD)/MonitorPower.app
HELPER  := $(BUILD)/smc-power
DMG     := $(BUILD)/MonitorPower-$(VERSION).dmg
SOURCES := $(wildcard App/Sources/*.swift)
ARCH    := $(shell uname -m)
TARGET  := $(ARCH)-apple-macos12.0
ENTITLEMENTS := App/MonitorPower.entitlements

# "-" = ad-hoc signature (local builds). Set SIGN_IDENTITY to a
# "Developer ID Application: Name (TEAMID)" identity for notarizable builds.
SIGN_IDENTITY ?= -
ifeq ($(SIGN_IDENTITY),-)
CODESIGN := codesign --force --sign -
else
CODESIGN := codesign --force --sign "$(SIGN_IDENTITY)" --options runtime --timestamp
endif

.PHONY: all app helper dmg notarize clean install uninstall

all: app

app: $(APP)

helper: $(HELPER)

dmg: $(DMG)

$(HELPER): helper/smc-power.c
	mkdir -p $(BUILD)
	clang -O2 -Wall -Wextra -arch $(ARCH) -mmacosx-version-min=12.0 -framework IOKit -o $@ $<
	$(CODESIGN) $@

# The helper and its install script ship inside the app so it can set itself up.
$(APP): $(SOURCES) App/Info.plist $(ENTITLEMENTS) $(HELPER) scripts/helper-install.sh
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	swiftc -O -target $(TARGET) -o $(APP)/Contents/MacOS/MonitorPower $(SOURCES)
	cp App/Info.plist $(APP)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(APP)/Contents/Info.plist
	cp $(HELPER) scripts/helper-install.sh $(APP)/Contents/Resources/
	$(CODESIGN) --entitlements $(ENTITLEMENTS) $(APP)

$(DMG): $(APP) scripts/make-dmg.sh
	./scripts/make-dmg.sh $(APP) $@ "Monitor Power $(VERSION)"
	if [ "$(SIGN_IDENTITY)" != "-" ]; then codesign --force --sign "$(SIGN_IDENTITY)" --timestamp $@; fi

# Uploads the DMG to Apple's notary service, waits for the verdict and staples
# the ticket. Needs a Developer ID build plus these environment variables:
#   APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD (app-specific password)
notarize: $(DMG)
	@test "$(SIGN_IDENTITY)" != "-" || { echo "notarize needs SIGN_IDENTITY set to a Developer ID identity" >&2; exit 1; }
	xcrun notarytool submit $(DMG) --apple-id "$$APPLE_ID" --team-id "$$APPLE_TEAM_ID" --password "$$APPLE_APP_PASSWORD" --wait
	xcrun stapler staple $(DMG)
	xcrun stapler validate $(DMG)
	spctl --assess --type open --context context:primary-signature --verbose $(DMG)

install: app
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

clean:
	rm -rf $(BUILD)
