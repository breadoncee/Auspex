#!/bin/bash
# Build a runnable bundle using Command Line Tools when full Xcode is absent.
set -euo pipefail
cd "$(dirname "$0")/.."
SDK_PATH="$(xcrun --show-sdk-path)"
OUTPUT="build/Local/Auspex.app"
mkdir -p "$OUTPUT/Contents/MacOS" "$OUTPUT/Contents/Resources" build/ModuleCache
swiftc -swift-version 6 -O -sdk "$SDK_PATH" -target arm64-apple-macosx26.0 \
    -module-cache-path build/ModuleCache \
    -import-objc-header Sources/Bridging/IOHID-Bridging.h \
    Sources/AuspexApp.swift Sources/Model/*.swift Sources/Collectors/*.swift \
    Sources/Services/*.swift Sources/Views/*.swift Sources/Views/Components/*.swift \
    -framework IOKit -framework ServiceManagement -o "$OUTPUT/Contents/MacOS/Auspex"
cp Sources/Info.plist "$OUTPUT/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable Auspex' "$OUTPUT/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.local.auspex' "$OUTPUT/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDevelopmentRegion en' "$OUTPUT/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 1.3.2' "$OUTPUT/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 7' "$OUTPUT/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$OUTPUT/Contents/Info.plist"
cp Sources/Assets.xcassets/MenuBarGlyph.imageset/glyph_18.png "$OUTPUT/Contents/Resources/MenuBarGlyph.png"
cp Sources/Assets.xcassets/MenuBarGlyph.imageset/glyph_36.png "$OUTPUT/Contents/Resources/MenuBarGlyph@2x.png"
cp Sources/Assets.xcassets/MenuBarGlyph.imageset/glyph_54.png "$OUTPUT/Contents/Resources/MenuBarGlyph@3x.png"
ICONSET=build/Local/AppIcon.iconset
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    cp "Sources/Assets.xcassets/AppIcon.appiconset/icon_$size.png" "$ICONSET/icon_${size}x${size}.png"
    double=$((size * 2))
    cp "Sources/Assets.xcassets/AppIcon.appiconset/icon_$double.png" "$ICONSET/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$ICONSET" -o "$OUTPUT/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$OUTPUT"
echo "Built: $OUTPUT"
