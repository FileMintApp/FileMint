-include .local/signing.mk

.PHONY: verify verify-appcast verify-sparkle-driver verify-context verify-harness-cli verify-updates update-sandbox-harness test harness project build dmg package release-local publish-local doctor icon clean

DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR
export DEVELOPMENT_TEAM

verify: verify-context test harness verify-harness-cli verify-appcast

verify-context:
	python3 scripts/verify_context.py

verify-harness-cli:
	swift build --package-path CorePackage --product filemint-harness
	python3 scripts/test_harness_cli.py --binary "$$(swift build --package-path CorePackage --show-bin-path)/filemint-harness"

verify-sparkle-driver:
	bash scripts/verify_sparkle_driver.sh

verify-appcast:
	python3 scripts/test_update_appcast.py

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
