#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
python3 scripts/native_qa.py check-stopped access-migration
swift build --package-path CorePackage --product filemint-harness
ACCESS_QA_CORE="$(swift build --package-path CorePackage --show-bin-path)"
ACCESS_QA_SPARKLE="$PWD/build/SourcePackages/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
[[ -d "$ACCESS_QA_SPARKLE/Sparkle.framework" ]] || { echo 'Resolve the project Sparkle dependency first.' >&2; exit 2; }
mkdir -p build/access-migration-harness.noindex
ACCESS_QA_RUN="$(mktemp -d "$PWD/build/access-migration-harness.noindex/run.XXXXXXXX")"
if [[ -f "$ACCESS_QA_CORE/libFileMintCore.a" ]]; then
  ACCESS_QA_LINK=(-I "$ACCESS_QA_CORE" "$ACCESS_QA_CORE/libFileMintCore.a")
else
  ACCESS_QA_LINK=(-I "$ACCESS_QA_CORE/Modules" "$ACCESS_QA_CORE"/FileMintCore.build/*.o)
fi
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.0 \
  scripts/access_migration_support.swift scripts/access_migration_smoke.swift \
  App/FileMint/OpenWithFolderAccess.swift SharedUI/FolderAccess.swift \
  "${ACCESS_QA_LINK[@]}" -F "$ACCESS_QA_SPARKLE" -framework Sparkle \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks -o "$ACCESS_QA_RUN/FileMintAccessQA"
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos13.0 -module-name AccessFinderSync \
  -Xlinker -e -Xlinker _NSExtensionMain \
  scripts/access_migration_support.swift scripts/access_migration_finder.swift \
  "${ACCESS_QA_LINK[@]}" -framework FinderSync -o "$ACCESS_QA_RUN/AccessFinderSync"
python3 scripts/access_migration_fixture.py assemble "$ACCESS_QA_RUN" "$ACCESS_QA_SPARKLE"
swift scripts/sign_access_migration_fixture.swift "$ACCESS_QA_RUN"
python3 scripts/native_qa.py publish access-migration "$ACCESS_QA_RUN/installation/FileMintAccessQA.app" "$ACCESS_QA_RUN" --already-signed
printf 'Run configuration: %s/fixture.json\n' "$ACCESS_QA_RUN"
