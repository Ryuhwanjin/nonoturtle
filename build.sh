#!/bin/bash
set -e

APP_NAME="NoNoTurtle"
BUNDLE_DIR="$APP_NAME.app"
MACOS_DIR="$BUNDLE_DIR/Contents/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Contents/Resources"

echo "🔨 Compiling $APP_NAME..."
clang -O2 -fobjc-arc \
    -framework Cocoa \
    -framework WebKit \
    -framework UserNotifications \
    Sources/main.m -o "$APP_NAME"

echo "📦 Packaging $BUNDLE_DIR..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 바이너리 및 리소스 복사
cp "$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp Sources/Info.plist "$BUNDLE_DIR/Contents/Info.plist"
echo -n "APPL????" > "$BUNDLE_DIR/Contents/PkgInfo"

# 웹 리소스 복사
cp -R Sources/web "$RESOURCES_DIR/"

# Ad-hoc 코드서명
codesign --force --deep --sign - "$BUNDLE_DIR" 2>/dev/null || true

echo "✅ Successfully built $BUNDLE_DIR in under 2 seconds!"
