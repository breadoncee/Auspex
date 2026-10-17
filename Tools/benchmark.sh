#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Respect an explicitly selected Xcode. The standalone Command Line Tools may
# omit SwiftUI's SDK macro plugins, so prefer installed full Xcode otherwise.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
mkdir -p build/verification build/ModuleCache
xcrun swiftc -O -swift-version 6 -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macosx26.0 \
    -module-cache-path build/ModuleCache \
    -import-objc-header Sources/Bridging/IOHID-Bridging.h \
    Sources/Model/*.swift Sources/Collectors/*.swift Tools/benchmark.swift \
    -framework AppKit -framework IOKit -o build/verification/benchmark
exec build/verification/benchmark "$@"
