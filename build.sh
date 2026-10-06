#!/bin/zsh
# Baut "MD Viewer.app" nach build/. Mit "./build.sh install" zusätzlich nach ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/MD Viewer.app"

swift build -c release

if [[ ! -f build/AppIcon.icns ]]; then
  mkdir -p build
  swift Support/make-icon.swift build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
  rm -rf build/AppIcon.iconset
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MDViewer "$APP/Contents/MacOS/"
cp Support/Info.plist "$APP/Contents/"
cp build/AppIcon.icns "$APP/Contents/Resources/"
cp -R Resources/Web "$APP/Contents/Resources/"
cp Resources/Hilfe.md "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

if [[ "${1:-}" == "install" ]]; then
  DEST="$HOME/Applications/MD Viewer.app"
  mkdir -p "$HOME/Applications"
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
  echo "Installiert: $DEST"
else
  echo "Gebaut: $APP"
fi
