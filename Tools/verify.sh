#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/verification build/ModuleCache
swiftc -D DEBUG -swift-version 6 -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macosx26.0 \
    -module-cache-path build/ModuleCache \
    -import-objc-header Sources/Bridging/IOHID-Bridging.h \
    Sources/Model/*.swift Sources/Collectors/*.swift Sources/Services/UpdateChecker.swift \
    Tests/RegressionTests.swift Tests/ReliabilityTests.swift Tests/HistoryTests.swift \
    Tests/PreferencesTests.swift Tests/UpdateTests.swift \
    -framework IOKit -o build/verification/regressions
build/verification/regressions "$@"
swiftc -swift-version 6 -parse-as-library -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macosx26.0 \
    -module-cache-path build/ModuleCache \
    Sources/Views/MenuBarIcon.swift Tests/MenuBarIconTests.swift \
    -o build/verification/menu-bar-icon-tests
build/verification/menu-bar-icon-tests
