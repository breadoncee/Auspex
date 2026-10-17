#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/verification build/ModuleCache
developer_path="${DEVELOPER_DIR:-$(xcode-select -p)}"
plugin_path="$developer_path/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins#$developer_path/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server"
swiftc -D DEBUG -swift-version 6 -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macosx26.0 \
    -module-cache-path build/ModuleCache -external-plugin-path "$plugin_path" \
    -import-objc-header Sources/Bridging/IOHID-Bridging.h \
    Sources/Model/*.swift Sources/Collectors/*.swift Sources/Services/*.swift \
    Sources/Views/*.swift Sources/Views/Components/*.swift Tests/VisualTests.swift Tests/AppearanceTests.swift \
    -framework IOKit -framework ServiceManagement -o build/verification/visual-tests
build/verification/visual-tests
