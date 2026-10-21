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

# Renders the full state matrix (light/dark x en/ru) into build/snapshots/.
SNAPSHOT_BIN = build/Build/Products/Debug/Subus.app/Contents/MacOS/Subus
SNAPSHOT_SRC = $(HOME)/Library/Containers/io.github.aesarva.Subus/Data/tmp/Snapshots
# appicon.png is language-independent: both runs write the same file, so it counts once (168 localized + 1).
SNAPSHOT_EXPECTED = 181

.PHONY: snapshots
snapshots: build
	rm -rf build/snapshots "$(SNAPSHOT_SRC)"
	mkdir -p build/snapshots
	$(SNAPSHOT_BIN) -Snapshots -AppleLanguages "(en)" -AppleLocale en_US
	cp "$(SNAPSHOT_SRC)"/*.png build/snapshots/
	rm -rf "$(SNAPSHOT_SRC)"
	$(SNAPSHOT_BIN) -Snapshots -AppleLanguages "(ru)" -AppleLocale ru_RU
	cp "$(SNAPSHOT_SRC)"/*.png build/snapshots/
	@count=$$(ls build/snapshots/*.png 2>/dev/null | wc -l | tr -d ' '); \
	empty=$$(find build/snapshots -name '*.png' -size 0); \
	ls build/snapshots; \
	if [ -n "$$empty" ]; then echo "empty snapshots:"; echo "$$empty"; exit 1; fi; \
	if [ "$$count" -ne $(SNAPSHOT_EXPECTED) ]; then echo "expected $(SNAPSHOT_EXPECTED) snapshots, got $$count"; exit 1; fi; \
	echo "$$count snapshots in build/snapshots"

.PHONY: app dmg
# Release universal build → build/Subus.app (ad-hoc unless SIGN_IDENTITY is set).
app:
	scripts/build-app.sh

# DMG without Developer ID: make dmg VERSION=0.1.0 → dist/Subus-0.1.0.dmg.
# Signed + notarized release: scripts/release.sh <version>.
VERSION ?= 0.1.0
dmg:
	scripts/release.sh $(VERSION) --unsigned
