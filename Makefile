-include .local/signing.mk

.PHONY: verify test harness project build dmg package doctor icon clean

DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR
export DEVELOPMENT_TEAM

verify: test harness

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

doctor:
	./scripts/doctor.sh

icon:
	swift scripts/generate_app_icon.swift

clean:
	rm -rf .build CorePackage/.build build FileMint.xcodeproj
