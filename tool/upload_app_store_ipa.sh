#!/bin/bash
# Upload GRB Link IPA to App Store Connect.
# Option A: App Store Connect API Key (recommended for CI)
#   export APP_STORE_CONNECT_API_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXXXXX.p8
#   export APP_STORE_CONNECT_KEY_ID=XXXXXX
#   export APP_STORE_CONNECT_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#
# Option B: Apple ID app-specific password
#   export APPLE_ID=your@email.com
#   export APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IPA="$ROOT/build/ios/ipa/GRB Link.ipa"

if [[ ! -f "$IPA" ]]; then
  echo "IPA not found: $IPA"
  echo "Run: bash tool/build_app_store_ipa.sh"
  exit 1
fi

if [[ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
  xcrun altool --upload-app --type ios --file "$IPA" \
    --apiKey "$APP_STORE_CONNECT_KEY_ID" \
    --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
elif [[ -n "${APPLE_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" ]]; then
  xcrun altool --upload-app --type ios --file "$IPA" \
    --username "$APPLE_ID" --password "$APP_SPECIFIC_PASSWORD"
else
  echo "No upload credentials configured."
  echo
  echo "Install Transporter from Mac App Store, then drag this file into it:"
  echo "  $IPA"
  echo
  echo "Or open Xcode Organizer:"
  echo "  open $ROOT/build/ios/archive/Runner.xcarchive"
  echo "  → Distribute App → App Store Connect → Upload"
  exit 1
fi

echo "Upload submitted. Check App Store Connect → TestFlight / App Store."
