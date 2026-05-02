SCHEME  = Daily Kairos
PROJECT = ios/Bible Reference/Daily Kairos.xcodeproj
BUILD   = .build/Build/Products/Debug-maccatalyst
APP     = Daily Kairos.app

.PHONY: build run clean

build:
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination "platform=macOS,variant=Mac Catalyst" \
		-derivedDataPath .build \
		build

run: build
	open "$(BUILD)/$(APP)"

clean:
	rm -rf .build
