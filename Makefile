FLUTTER ?= /Users/interlinkmac/Public/flutter/bin/flutter
DIST_DIR ?= dist/apk

MAIN_VERSION := $(shell awk -F': ' '/^version:/ {print $$2; exit}' pubspec.yaml)
REPAIRING_VERSION := $(shell awk -F': ' '/^version:/ {print $$2; exit}' sk_bags_repairing/pubspec.yaml)

MAIN_APK := $(DIST_DIR)/SKBagsStaff-v$(MAIN_VERSION).apk
REPAIRING_APK := $(DIST_DIR)/SkBagsRepairing-v$(REPAIRING_VERSION).apk

.PHONY: build-apks build-main-apk build-repairing-apk clean-apks versions

build-apks: build-main-apk build-repairing-apk
	@echo "Built release APKs:"
	@echo "  $(MAIN_APK)"
	@echo "  $(REPAIRING_APK)"

build-main-apk:
	$(FLUTTER) pub get
	$(FLUTTER) build apk --release
	mkdir -p "$(DIST_DIR)"
	cp "build/app/outputs/flutter-apk/app-release.apk" "$(MAIN_APK)"
	@echo "Main app APK: $(MAIN_APK)"

build-repairing-apk:
	cd sk_bags_repairing && $(FLUTTER) pub get
	cd sk_bags_repairing && $(FLUTTER) build apk --release
	mkdir -p "$(DIST_DIR)"
	cp "sk_bags_repairing/build/app/outputs/flutter-apk/app-release.apk" "$(REPAIRING_APK)"
	@echo "Repairing app APK: $(REPAIRING_APK)"

clean-apks:
	mkdir -p "$(DIST_DIR)"
	find "$(DIST_DIR)" -name "*.apk" -delete

versions:
	@echo "SKBagsStaff: $(MAIN_VERSION)"
	@echo "SkBagsRepairing: $(REPAIRING_VERSION)"
