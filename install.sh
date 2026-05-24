#!/bin/zsh
# Build and install ShiWuZhi.app to ~/Applications
set -e

swift build -c release

APP=~/Applications/ShiWuZhi.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/ShiWuZhi "$APP/Contents/MacOS/"
cp Info.plist               "$APP/Contents/Info.plist"
cp AppIcon.icns             "$APP/Contents/Resources/AppIcon.icns"

xattr -cr "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
touch "$APP"
killall Dock 2>/dev/null || true

echo "✓ 安装完成：$APP"
