#!/bin/bash

# Configuration
APP_NAME="Clip"
BUILD_DIR=".build/release"
VERSION="1.1.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
APP_BUNDLE="${APP_NAME}.app"

# Ensure we are in the project root
cd "$(dirname "$0")/.."

echo "🚀 Starting build process for ${APP_NAME}..."

# 1. Build the release binary
echo "🛠️  Building Swift package..."
swift build -c release --product "${APP_NAME}"

if [ $? -ne 0 ]; then
    echo "❌ Build failed."
    exit 1
fi

# 2. Create App Bundle Structure
echo "📦 Creating App Bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 3. Copy Binary
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# 4. Create Info.plist
echo "📝 Generating Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/> <!-- This hides the app from the Dock, suitable for menu bar apps -->
</dict>
</plist>
EOF

# 5. Ad-hoc Signing (Fixes "Run Locally" issues on ARM Macs)
echo "🔏 Signing app (Ad-hoc)..."
codesign --force --deep --sign - "${APP_BUNDLE}"

# 6. Create DMG
echo "💿 Creating DMG..."
rm -f "${DMG_NAME}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${APP_BUNDLE}" -ov -format UDZO "${DMG_NAME}"

if [ $? -eq 0 ]; then
    echo "✅ DMG created successfully: ${DMG_NAME}"
else
    echo "❌ DMG creation failed."
    exit 1
fi
