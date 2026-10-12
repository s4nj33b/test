# Builds the menu bar app and the SMC helper. Requires Xcode Command Line Tools.
BUILD   := build
APP     := $(BUILD)/MonitorPower.app
HELPER  := $(BUILD)/smc-power
SOURCES := $(wildcard App/Sources/*.swift)
ARCH    := $(shell uname -m)
TARGET  := $(ARCH)-apple-macos12.0

.PHONY: all app helper clean install uninstall

all: app helper

app: $(APP)

helper: $(HELPER)

$(APP): $(SOURCES) App/Info.plist
	mkdir -p $(APP)/Contents/MacOS
	swiftc -O -target $(TARGET) -o $(APP)/Contents/MacOS/MonitorPower $(SOURCES)
	cp App/Info.plist $(APP)/Contents/Info.plist
	codesign --force --sign - $(APP)

$(HELPER): helper/smc-power.c
	mkdir -p $(BUILD)
	clang -O2 -Wall -Wextra -mmacosx-version-min=12.0 -framework IOKit -o $@ $<
	codesign --force --sign - $@

install: all
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

clean:
	rm -rf $(BUILD)
