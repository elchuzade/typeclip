#!/usr/bin/env bash
# Builds TypeClip.app (universal: Apple Silicon + Intel) into ./build
# Usage: ./build.sh            -> build/TypeClip.app
#        ./build.sh --zip      -> also build/TypeClip.zip (for GitHub Releases)
set -euo pipefail

APP_NAME="TypeClip"
VERSION="${VERSION:-1.0.0}"
MIN_MACOS="13.0"
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/build"
APP="$OUT/$APP_NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 \
    -target "$arch-apple-macos$MIN_MACOS" \
    "$ROOT"/Sources/*.swift \
    -o "$OUT/$APP_NAME-$arch"
done
lipo -create "$OUT/$APP_NAME-arm64" "$OUT/$APP_NAME-x86_64" -output "$APP/Contents/MacOS/$APP_NAME"
rm "$OUT/$APP_NAME-arm64" "$OUT/$APP_NAME-x86_64"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>io.github.typeclip</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature (free). Not notarized, see README for how users open it.
codesign --force --deep --sign - "$APP"

echo "Built $APP"

if [[ "${1:-}" == "--zip" ]]; then
  (cd "$OUT" && rm -f "$APP_NAME.zip" && ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME.zip")
  echo "Zipped $OUT/$APP_NAME.zip"
fi
