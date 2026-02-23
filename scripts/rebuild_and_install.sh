#!/usr/bin/env bash
# Rebuild release and install on Samsung SM-T585 and iPhone 13.
# Prerequisites: USB debugging on tablet, iPhone connected and trusted.

set -e
cd "$(dirname "$0")/.."

# Device IDs (run: adb devices / flutter devices to confirm)
SAMSUNG_ID="52001c52494e6747"
IPHONE_ID="00008110-001905EC0EEB601E"

echo "=== 1. Building release APK ==="
flutter build apk --release

APK="build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -f "$APK" ]]; then
  echo "Error: APK not found at $APK"
  exit 1
fi

echo ""
echo "=== 2. Installing on Samsung SM-T585 ($SAMSUNG_ID) ==="
adb -s "$SAMSUNG_ID" install -r "$APK"
echo "Done. App installed on tablet."

echo ""
echo "=== 3. Building iOS release ==="
flutter build ios --release

echo ""
echo "=== 4. Installing on iPhone 13 ($IPHONE_ID) ==="
echo "Ensure iPhone is connected via USB and trusted."
flutter install --release -d "$IPHONE_ID"
echo "Done. App installed on iPhone."

echo ""
echo "=== Rebuild and install complete ==="
