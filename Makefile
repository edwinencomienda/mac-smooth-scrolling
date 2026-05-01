APP_NAME = MacSmoothScroll
BUNDLE_ID = com.edwinencomienda.macsmoothscroll
BUILD_DIR = .build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
DEBUG_BIN = $(BUILD_DIR)/debug/macsmoothscroll
RELEASE_BIN = $(BUILD_DIR)/release/macsmoothscroll
INSTALL_DIR = /Applications
PLIST = Sources/MacSmoothScroll/Resources/Info.plist
ENTITLEMENTS = Sources/MacSmoothScroll/Resources/MacSmoothScroll.entitlements

# Load .env file if it exists (for development signing configuration)
ifneq (,$(wildcard .env))
    include .env
    export
endif

# Code signing identity for development builds (self-signed cert)
# Override via .env file or environment variable
# Default: MacSmoothScroll Dev
CODESIGN_IDENTITY ?= MacSmoothScroll Dev

.PHONY: build release bundle run run-app install sign dmg clean

build:
	@echo "Building $(APP_NAME) (debug)..."
	@swift build
	@codesign --force --sign - --identifier $(BUNDLE_ID) $(DEBUG_BIN) 2>/dev/null || true

release:
	@echo "Building $(APP_NAME) (release)..."
	@swift build -c release

bundle: release
	@echo "Creating $(APP_NAME).app bundle..."
	@echo "Using code signing identity: '$(CODESIGN_IDENTITY)'"
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(RELEASE_BIN) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@cp $(PLIST) $(APP_BUNDLE)/Contents/Info.plist
	@if [ -d "$(BUILD_DIR)/release/MacSmoothScroll_MacSmoothScroll.bundle" ]; then \
		rsync -a "$(BUILD_DIR)/release/MacSmoothScroll_MacSmoothScroll.bundle" $(APP_BUNDLE)/Contents/Resources/; \
	fi
	@cp Sources/MacSmoothScroll/Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	@codesign --force --deep --sign "$(CODESIGN_IDENTITY)" --identifier $(BUNDLE_ID) --entitlements $(ENTITLEMENTS) $(APP_BUNDLE)
	@echo "Created $(APP_BUNDLE)"

run: build
	@$(DEBUG_BIN)

install: bundle
	@echo "Installing to $(INSTALL_DIR)..."
	@echo "Using code signing identity: '$(CODESIGN_IDENTITY)'"
	@mkdir -p "$(INSTALL_DIR)/$(APP_NAME).app"
	@rsync -a --delete $(APP_BUNDLE)/ "$(INSTALL_DIR)/$(APP_NAME).app/"
	@codesign --force --deep --sign "$(CODESIGN_IDENTITY)" --identifier $(BUNDLE_ID) --entitlements $(ENTITLEMENTS) "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed $(APP_NAME).app to $(INSTALL_DIR)"

# Code sign with Developer ID + notarize for distribution
# Requires .env.prod file with SIGN_IDENTITY, APPLE_API_KEY, APPLE_API_KEY_ID, APPLE_API_ISSUER, APPLE_TEAM_ID
sign: release
	@# Load .env.prod for production signing
	@if [ ! -f .env.prod ]; then \
		echo "Error: .env.prod file not found. Copy .env.example to .env.prod and fill in your credentials."; \
		exit 1; \
	fi
	$(eval include .env.prod)
	$(eval export)
	@echo "==> Creating signed $(APP_NAME).app bundle..."
	@# Validate required env vars
	@if [ -z "$(SIGN_IDENTITY)" ]; then \
		echo "Error: SIGN_IDENTITY not set in .env.prod"; \
		exit 1; \
	fi
	@if [ -z "$(APPLE_API_KEY)" ] || [ -z "$(APPLE_API_KEY_ID)" ] || [ -z "$(APPLE_API_ISSUER)" ]; then \
		echo "Error: Notarization env vars not set in .env.prod (APPLE_API_KEY, APPLE_API_KEY_ID, APPLE_API_ISSUER)"; \
		exit 1; \
	fi
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(RELEASE_BIN) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@cp $(PLIST) $(APP_BUNDLE)/Contents/Info.plist
	@if [ -d "$(BUILD_DIR)/release/MacSmoothScroll_MacSmoothScroll.bundle" ]; then \
		rsync -a "$(BUILD_DIR)/release/MacSmoothScroll_MacSmoothScroll.bundle" $(APP_BUNDLE)/Contents/Resources/; \
	fi
	@cp Sources/MacSmoothScroll/Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	@echo "==> Signing with Developer ID..."
	@codesign --force --deep --options runtime \
		--sign "$(SIGN_IDENTITY)" \
		--identifier $(BUNDLE_ID) \
		--entitlements $(ENTITLEMENTS) \
		--timestamp \
		$(APP_BUNDLE)
	@echo "==> Verifying signature..."
	@codesign --verify --deep --strict --verbose=2 $(APP_BUNDLE)
	@echo "==> Creating ZIP for notarization..."
	@rm -f $(BUILD_DIR)/$(APP_NAME).zip
	@ditto -c -k --keepParent $(APP_BUNDLE) $(BUILD_DIR)/$(APP_NAME).zip
	@echo "==> Submitting for notarization..."
	@xcrun notarytool submit $(BUILD_DIR)/$(APP_NAME).zip \
		--key "$(APPLE_API_KEY)" \
		--key-id "$(APPLE_API_KEY_ID)" \
		--issuer "$(APPLE_API_ISSUER)" \
		--wait
	@echo "==> Stapling notarization ticket..."
	@xcrun stapler staple $(APP_BUNDLE)
	@echo "==> Done! Signed and notarized: $(APP_BUNDLE)"
	@echo "==> Run 'make dmg' to create a distributable DMG."

dmg:
	@if [ ! -d "$(APP_BUNDLE)" ]; then \
		echo "Error: $(APP_BUNDLE) not found. Run 'make sign' first."; \
		exit 1; \
	fi
	@echo "==> Creating DMG..."
	@rm -rf $(BUILD_DIR)/dmg-staging
	@mkdir -p $(BUILD_DIR)/dmg-staging
	@cp -R $(APP_BUNDLE) $(BUILD_DIR)/dmg-staging/
	@ln -s /Applications $(BUILD_DIR)/dmg-staging/Applications
	@rm -f $(BUILD_DIR)/$(APP_NAME).dmg
	@hdiutil create -volname "$(APP_NAME)" \
		-srcfolder $(BUILD_DIR)/dmg-staging \
		-ov -format UDZO \
		$(BUILD_DIR)/$(APP_NAME).dmg
	@rm -rf $(BUILD_DIR)/dmg-staging
	@echo "==> Created $(BUILD_DIR)/$(APP_NAME).dmg"

run-app: bundle
	@open $(APP_BUNDLE)

clean:
	@swift package clean
	@rm -rf $(APP_BUNDLE) $(BUILD_DIR)/$(APP_NAME).zip $(BUILD_DIR)/$(APP_NAME).dmg
