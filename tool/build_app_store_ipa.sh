#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> flutter pub get"
flutter pub get

echo "==> prepare iOS vendor deps (if needed)"
bash "$ROOT/tool/prepare_ios_build.sh"

echo "==> pod install"
(
  cd ios
  if ! pod install; then
    CERT_FILE="$(mktemp)"
    security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain > "$CERT_FILE"
    SSL_CERT_FILE="$CERT_FILE" pod install
    rm -f "$CERT_FILE"
  fi
)

echo "==> archive (Release)"
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist || true

ARCHIVE="$ROOT/build/ios/archive/Runner.xcarchive"
IPA_DIR="$ROOT/build/ios/ipa"

if [[ -d "$ARCHIVE" ]]; then
  echo "==> export App Store IPA"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$ROOT/ios/ExportOptions.plist" \
    -exportPath "$IPA_DIR" \
    -allowProvisioningUpdates
fi

echo
echo "IPA: $IPA_DIR/GRB Link.ipa"
echo "Upload: bash tool/upload_app_store_ipa.sh"
echo "  or install Transporter from Mac App Store and drag the IPA in."
