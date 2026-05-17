#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Murmur"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

if [ -e "$BUILD_DIR" ]; then
    if command -v trash >/dev/null 2>&1; then
        trash "$BUILD_DIR"
    else
        mv "$BUILD_DIR" "$HOME/.Trash/murmur-build-$(date +%s)" 2>/dev/null || true
    fi
fi

mkdir -p "$MACOS_DIR" "$RES_DIR"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

# Copy menu bar template if present
if [ -f "Resources/menubar_banana.png" ]; then
    cp Resources/menubar_banana.png "$RES_DIR/menubar_banana.png"
fi

# Copy sound assets if present
for snd in start.mp3 end.mp3; do
    if [ -f "Resources/$snd" ]; then cp "Resources/$snd" "$RES_DIR/$snd"; fi
done

# Build icon if 1024 PNG is present
if [ -f "Resources/icon_1024.png" ]; then
    echo "→ generating AppIcon.icns from icon_1024.png"
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for SZ in 16 32 64 128 256 512; do
        sips -z $SZ $SZ Resources/icon_1024.png --out "$ICONSET/icon_${SZ}x${SZ}.png" >/dev/null
        sips -z $((SZ*2)) $((SZ*2)) Resources/icon_1024.png --out "$ICONSET/icon_${SZ}x${SZ}@2x.png" >/dev/null
    done
    cp Resources/icon_1024.png "$ICONSET/icon_512x512@2x.png"
    iconutil -c icns -o "$RES_DIR/AppIcon.icns" "$ICONSET"
    rm -rf "$ICONSET"
fi

echo "→ swiftc compiling..."
swiftc \
    -O \
    -framework AppKit \
    -framework AVFoundation \
    -framework CoreGraphics \
    -framework Foundation \
    -o "$MACOS_DIR/$APP_NAME" \
    Sources/*.swift

echo "→ ad-hoc codesign with entitlements..."
codesign --force --sign - --deep --options runtime \
    --entitlements Resources/Murmur.entitlements \
    "$APP_DIR"

echo
echo "✓ Built: $APP_DIR"
echo
echo "Run: open '$APP_DIR'"
