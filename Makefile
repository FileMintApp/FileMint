-include .local/signing.mk

.PHONY: verify verify-native-qa verify-favorite-model verify-appcast verify-release-metadata verify-release-notarization verify-release-publication verify-signing-entitlements verify-sparkle-driver verify-context verify-harness-cli verify-updates update-sandbox-harness test harness project build dmg zip package release-local publish-local doctor icon clean

DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR
export DEVELOPMENT_TEAM

verify: verify-context verify-image-compression test harness verify-harness-cli verify-appcast verify-release-metadata verify-release-notarization verify-release-publication verify-signing-entitlements verify-native-qa

verify-native-qa:
	python3 scripts/test_native_qa.py

.PHONY: verify-image-compression
verify-image-compression:
	python3 scripts/verify_image_compression.py

verify-context:
	python3 scripts/verify_context.py

verify-favorite-model:
	bash scripts/verify_favorite_model.sh

verify-harness-cli:
	swift build --package-path CorePackage --product filemint-harness
	python3 scripts/test_harness_cli.py --binary "$$(swift build --package-path CorePackage --show-bin-path)/filemint-harness"

verify-sparkle-driver:
	bash scripts/verify_sparkle_driver.sh

verify-appcast:
	python3 scripts/test_update_appcast.py

verify-release-metadata:
	python3 scripts/test_release_metadata.py

verify-release-notarization:
	python3 scripts/test_notarize_dmg.py
	python3 scripts/test_release_zip.py
	python3 scripts/test_release_resume.py

verify-release-publication:
	python3 scripts/test_publish_release.py

verify-signing-entitlements:
	python3 scripts/test_signing_entitlements.py

verify-updates:
	bash scripts/verify_updates.sh

update-sandbox-harness:
	bash scripts/build_update_sandbox_harness.sh

test:
	swift test --package-path CorePackage

harness:
	swift run --package-path CorePackage filemint-harness specs/harness/cases/file_creation_cases.json

project:
	./scripts/bootstrap_project.sh

build:
	./scripts/build_release.sh

dmg:
	./scripts/make_dmg.sh

zip:
	bash scripts/make_zip.sh

package:
	./scripts/package_release.sh

release-local:
	bash scripts/release_local.sh

publish-local:
	bash scripts/publish_local.sh

doctor:
	./scripts/doctor.sh

icon:
	swift scripts/generate_app_icon.swift

clean:
	rm -rf .build CorePackage/.build build FileMint.xcodeproj
