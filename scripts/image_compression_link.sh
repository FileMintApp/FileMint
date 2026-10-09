#!/usr/bin/env bash
# Shared by fixtures which directly link FileMintImages' Swift object files.
FILEMINT_COMPRESSION_SLICE="$PWD/CorePackage/Artifacts/FileMintCompression.xcframework/macos-arm64"
FILEMINT_COMPRESSION_LINK=(-F "$FILEMINT_COMPRESSION_SLICE" -framework FileMintCompression
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks)
filemint_embed_compression() {
  local app="$1"
  mkdir -p "$app/Contents/Frameworks"
  ditto "$FILEMINT_COMPRESSION_SLICE/FileMintCompression.framework" \
    "$app/Contents/Frameworks/FileMintCompression.framework"
}
