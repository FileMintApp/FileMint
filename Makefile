-include .local/signing.mk

.PHONY: verify verify-native-qa verify-favorite-model verify-appcast verify-release-metadata verify-release-notarization verify-release-publication verify-signing-entitlements verify-sparkle-driver verify-context verify-harness-cli verify-updates update-sandbox-harness test harness project build dmg zip package release-local publish-local doctor icon clean

DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR
export DEVELOPMENT_TEAM

verify: verify-context verify-fork-sync verify-github-token verify-image-compression test harness verify-harness-cli verify-appcast verify-release-metadata verify-release-notarization verify-release-publication verify-homebrew verify-signing-entitlements verify-native-qa verify-native-checks-runner verify-launcher-probe verify-batch-rename-capture verify-batch-rename-access verify-file-info-capture verify-file-visibility

.PHONY: verify-launcher-probe
verify-launcher-probe:
	python3 scripts/launcher_integration/test_url_probe.py
	python3 scripts/launcher_product/test_metadata.py

.PHONY: verify-file-visibility
verify-file-visibility:
	bash scripts/verify_file_visibility.sh

.PHONY: verify-file-info-capture
verify-file-info-capture:
	bash scripts/verify_file_info_capture.sh

.PHONY: native-qa-plan verify-native-affected verify-native-checks-runner
export NATIVE_QA_BASE NATIVE_QA_SUITES

native-qa-plan:
	python3 scripts/native_checks.py plan

verify-native-affected:
	python3 scripts/native_checks.py run

verify-native-checks-runner:
	python3 scripts/test_native_checks.py

.PHONY: verify-batch-rename-capture
verify-batch-rename-capture:
	bash scripts/verify_batch_rename_capture.sh

.PHONY: verify-batch-rename-access
verify-batch-rename-access:
	bash scripts/verify_batch_rename_access.sh

.PHONY: verify-homebrew homebrew-prepare homebrew-publish
verify-homebrew:
	python3 scripts/test_homebrew_tap.py

homebrew-prepare:
	@test -n "$(MANIFEST)" -a -n "$(OUTPUT_DIR)" || { echo 'Set MANIFEST and OUTPUT_DIR'; exit 2; }
	python3 scripts/homebrew_tap.py prepare --manifest "$(MANIFEST)" --output-dir "$(OUTPUT_DIR)"

homebrew-publish:
	@test -n "$(MANIFEST)" || { echo 'Set MANIFEST'; exit 2; }
	python3 scripts/homebrew_tap.py publish --manifest "$(MANIFEST)"

.PHONY: verify-fork-sync
verify-fork-sync:
	python3 scripts/test_fork_sync.py

.PHONY: verify-github-token verify-github-token-live
verify-github-token:
	python3 scripts/test_github_token.py

verify-github-token-live:
	python3 scripts/verify_github_token.py

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
