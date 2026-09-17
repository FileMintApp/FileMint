#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
products="${FILEMINT_DERIVED_DATA_PATH:-$PWD/build/DerivedData}/Build/Products/Release"
[[ -f "$products/FileMintCore.o" && -d "$products/Sparkle.framework" ]] || {
  echo 'Run the unsigned make build first.' >&2; exit 2;
}
work="$(mktemp -d /private/tmp/filemint-sparkle-driver.XXXXXX)"
trap 'rm -f "$work/smoke"; rmdir "$work"' EXIT
xcrun swiftc -swift-version 6 -parse-as-library -target "$(uname -m)-apple-macos13.0" \
  -I "$products" -F "$products" -framework Sparkle \
  -Xlinker -rpath -Xlinker "$products" "$products/FileMintCore.o" \
  App/FileMint/SparkleInstaller.swift scripts/sparkle_driver_smoke.swift -o "$work/smoke"
"$work/smoke"
