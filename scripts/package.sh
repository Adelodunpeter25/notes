#!/usr/bin/env bash
set -euo pipefail

# Directories
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP_DIR="${PROJECT_ROOT}/note-desktop"
BUILD_DIR="${DESKTOP_DIR}/.build/release"
DIST_DIR="${PROJECT_ROOT}/dist"
APP_NAME="Notes"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
ICON_PNG="${PROJECT_ROOT}/assets/icon.png"

echo "==> 1. Building release binary with SwiftPM..."
cd "${DESKTOP_DIR}"
swift build -c release

echo "==> 2. Preparing output bundle layout..."
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "==> 3. Copying executable..."
cp "${BUILD_DIR}/Note" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "==> 4. Creating Info.plist..."
cat <<EOF > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.notes.desktop</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "==> 5. Generating .icns icon from assets/icon.png..."
if [ -f "${ICON_PNG}" ]; then
    ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "${ICONSET_DIR}"
    
    sips -z 16 16     "${ICON_PNG}" --out "${ICONSET_DIR}/icon_16x16.png" > /dev/null
    sips -z 32 32     "${ICON_PNG}" --out "${ICONSET_DIR}/icon_16x16@2x.png" > /dev/null
    sips -z 32 32     "${ICON_PNG}" --out "${ICONSET_DIR}/icon_32x32.png" > /dev/null
    sips -z 64 64     "${ICON_PNG}" --out "${ICONSET_DIR}/icon_32x32@2x.png" > /dev/null
    sips -z 128 128   "${ICON_PNG}" --out "${ICONSET_DIR}/icon_128x128.png" > /dev/null
    sips -z 256 256   "${ICON_PNG}" --out "${ICONSET_DIR}/icon_128x128@2x.png" > /dev/null
    sips -z 256 256   "${ICON_PNG}" --out "${ICONSET_DIR}/icon_256x256.png" > /dev/null
    sips -z 512 512   "${ICON_PNG}" --out "${ICONSET_DIR}/icon_256x256@2x.png" > /dev/null
    sips -z 512 512   "${ICON_PNG}" --out "${ICONSET_DIR}/icon_512x512.png" > /dev/null
    sips -z 1024 1024 "${ICON_PNG}" --out "${ICONSET_DIR}/icon_512x512@2x.png" > /dev/null
    
    iconutil -c icns "${ICONSET_DIR}" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    rm -rf "${ICONSET_DIR}"
fi

echo "==> 6. Creating DMG image with hdiutil..."
DMG_STAGE_DIR="$(mktemp -d)/dmg_stage"
mkdir -p "${DMG_STAGE_DIR}"
cp -R "${APP_BUNDLE}" "${DMG_STAGE_DIR}/"
ln -s /Applications "${DMG_STAGE_DIR}/Applications"

rm -f "${DMG_PATH}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_STAGE_DIR}" -ov -format UDZO "${DMG_PATH}"
rm -rf "${DMG_STAGE_DIR}"

echo "==> Packaging complete! Output available at: ${DMG_PATH}"
