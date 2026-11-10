#!/usr/bin/env bash
# One-line installer for TypeClip:
#   curl -fsSL https://raw.githubusercontent.com/elchuzade/typeclip/main/install.sh | bash
set -euo pipefail

REPO="elchuzade/typeclip"
URL="https://github.com/$REPO/releases/latest/download/TypeClip.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading TypeClip..."
curl -fsSL "$URL" -o "$TMP/TypeClip.zip"
ditto -x -k "$TMP/TypeClip.zip" "$TMP"

echo "Installing to /Applications..."
pkill -x TypeClip 2>/dev/null || true
rm -rf /Applications/TypeClip.app
mv "$TMP/TypeClip.app" /Applications/

# The app is open source but not notarized by Apple, so remove the
# "downloaded from the internet" flag so macOS lets it open.
xattr -dr com.apple.quarantine /Applications/TypeClip.app 2>/dev/null || true

open /Applications/TypeClip.app
echo
echo "Done! Look for the keyboard icon in your menu bar."
echo "macOS will ask for Accessibility permission: allow it so TypeClip can type for you."
