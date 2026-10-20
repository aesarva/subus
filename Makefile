export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

.PHONY: test
test:
	cd Packages/SubusCore && swift test
	plutil -lint App/Resources/Info.plist App/Resources/Subus.entitlements

.PHONY: generate build run
generate:
	xcodegen generate

build: generate
	xcodebuild -project Subus.xcodeproj -scheme Subus -configuration Debug -derivedDataPath build build

# make run ARGS='-SeedDemoData -OpenPanelOnLaunch'
# quoted form for values with spaces: make run ARGS='-AppleLanguages "(ru)"'
run: build
	pkill -x Subus || true
	open build/Build/Products/Debug/Subus.app --args $(ARGS)
