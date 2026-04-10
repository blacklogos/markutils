#!/bin/bash

# Configuration
APP_NAME="Clip"
BUILD_DIR=".build/release"
VERSION="1.4.0"
BUILD_NUMBER="5"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
APP_BUNDLE="${APP_NAME}.app"
DMG_STAGING="dmg_staging"
BUNDLE_ID="io.blacklogos.clip"

# Ensure we are in the project root
cd "$(dirname "$0")/.."

echo "🚀 Starting build process for ${APP_NAME} v${VERSION}..."

# 0. Resolve dependencies (Sparkle framework)
echo "📦 Resolving dependencies..."
swift package resolve

if [ $? -ne 0 ]; then
    echo "❌ Package resolution failed."
    exit 1
fi

# Find Sparkle.framework in resolved artifacts
SPARKLE_FRAMEWORK=$(find .build -path "*/Sparkle.framework" -type d | head -1)
if [ -z "${SPARKLE_FRAMEWORK}" ]; then
    echo "❌ Sparkle.framework not found in .build artifacts."
    exit 1
fi
echo "   Found Sparkle at: ${SPARKLE_FRAMEWORK}"

# 1. Build the release binaries (app + CLI)
echo "🛠️  Building Swift package (Clip + clip CLI)..."
swift build -c release --product "${APP_NAME}"
swift build -c release --product "clip-tool"

if [ $? -ne 0 ]; then
    echo "❌ Build failed."
    exit 1
fi

# NOTE: Quick Look extension (.appex) requires Developer ID signing.
# Sources are in Sources/ClipQLPreview/ and Sources/ClipQLGenerator/ for when
# a Developer ID is available. Skipped for ad-hoc builds.

# 2. Create App Bundle Structure
echo "📦 Creating App Bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
mkdir -p "${APP_BUNDLE}/Contents/Frameworks"

# 3. Copy App Binary + Icon + CLI binary + Sparkle Framework
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
cp "${BUILD_DIR}/clip-tool" "${APP_BUNDLE}/Contents/Resources/clip"
cp -R "${SPARKLE_FRAMEWORK}" "${APP_BUNDLE}/Contents/Frameworks/"

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
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/blacklogos/markutils/main/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>RW+dYl0koHbGSchUeD80V0ALWoSDMDdbXlkl0iofeDQ=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
    <key>SUAllowsAutomaticUpdates</key>
    <true/>
</dict>
</plist>
EOF

# 5. Fix rpath so the binary finds Sparkle.framework at runtime
echo "🔗 Fixing rpath for Sparkle..."
install_name_tool -add_rpath @executable_path/../Frameworks "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

# 6. Ad-hoc Signing — sign framework first, then outer bundle
echo "🔏 Signing app (Ad-hoc)..."
codesign --force --deep --sign - "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework" 2>/dev/null
codesign --force --deep --sign - "${APP_BUNDLE}"

# 7. Stage DMG contents: app only (CLI is bundled inside Clip.app/Contents/Resources/clip)
echo "📁 Staging DMG contents..."
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"
cp -r "${APP_BUNDLE}" "${DMG_STAGING}/"

# 8. Strip quarantine from all staged files (prevents Gatekeeper blocks on DMG contents)
echo "🛡️  Stripping quarantine attributes..."
xattr -rc "${DMG_STAGING}"

# 9. Create DMG
echo "💿 Creating DMG..."
rm -f "${DMG_NAME}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_STAGING}" -ov -format UDZO "${DMG_NAME}"

if [ $? -eq 0 ]; then
    rm -rf "${DMG_STAGING}"
    echo "✅ DMG created successfully: ${DMG_NAME}"
    echo "   Contents: Clip.app (Sparkle + bundled CLI)"
else
    echo "❌ DMG creation failed."
    exit 1
fi
