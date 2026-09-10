#!/bin/bash

set -e

APP_NAME="AlertTimer"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

echo "Building ${APP_NAME}..."

# Create the app bundle structure
mkdir -p "${MACOS_DIR}"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
mkdir -p "${RESOURCES_DIR}"

if [ -f "icon.png" ]; then
    echo "Generating AppIcon.icns..."
    mkdir -p MyIcon.iconset
    sips -z 16 16     icon.png --out MyIcon.iconset/icon_16x16.png > /dev/null
    sips -z 32 32     icon.png --out MyIcon.iconset/icon_16x16@2x.png > /dev/null
    sips -z 32 32     icon.png --out MyIcon.iconset/icon_32x32.png > /dev/null
    sips -z 64 64     icon.png --out MyIcon.iconset/icon_32x32@2x.png > /dev/null
    sips -z 128 128   icon.png --out MyIcon.iconset/icon_128x128.png > /dev/null
    sips -z 256 256   icon.png --out MyIcon.iconset/icon_128x128@2x.png > /dev/null
    sips -z 256 256   icon.png --out MyIcon.iconset/icon_256x256.png > /dev/null
    sips -z 512 512   icon.png --out MyIcon.iconset/icon_256x256@2x.png > /dev/null
    sips -z 512 512   icon.png --out MyIcon.iconset/icon_512x512.png > /dev/null
    sips -z 1024 1024 icon.png --out MyIcon.iconset/icon_512x512@2x.png > /dev/null
    iconutil -c icns MyIcon.iconset -o "${RESOURCES_DIR}/AppIcon.icns"
    rm -rf MyIcon.iconset
fi

# Compile the Swift files
swiftc -module-cache-path .module-cache -o "${MACOS_DIR}/${APP_NAME}" \
    main.swift \
    AppDelegate.swift \
    CaptureTimerViewModel.swift \
    NotificationManager.swift \
    CaptureEvent.swift \
    HistoryView.swift \
    TeamLoggerWatcher.swift

# Create Info.plist
cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.ashish.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# Code sign the app bundle so macOS grants it permissions
echo "Signing the app bundle..."
codesign --force --deep -s - "${APP_DIR}"

echo "Build complete: ${APP_DIR}"
