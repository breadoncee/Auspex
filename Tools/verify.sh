#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/verification build/ModuleCache
swiftc -swift-version 6 -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macosx26.0 \
    -module-cache-path build/ModuleCache \
    -import-objc-header Sources/Bridging/IOHID-Bridging.h \
    Sources/Model/*.swift Sources/Collectors/*.swift Tests/RegressionTests.swift \
    -framework IOKit -o build/verification/regressions
build/verification/regressions "$@"
