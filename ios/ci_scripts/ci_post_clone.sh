#!/bin/sh
# Xcode Cloud: runs after the repository is cloned, before Xcode builds.
set -e

echo "==> Environment"
echo "CI_PRIMARY_REPOSITORY_PATH=${CI_PRIMARY_REPOSITORY_PATH:-<unset>}"
echo "CI_XCODECLOUD=${CI_XCODECLOUD:-<unset>}"
echo "CI_XCODE_CLOUD=${CI_XCODE_CLOUD:-<unset>}"
echo "CI_WORKSPACE=${CI_WORKSPACE:-<unset>}"

# --- Install Flutter ---
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
if [ ! -f "$FLUTTER_HOME/bin/flutter" ]; then
  echo "==> Install Flutter (stable)"
  rm -rf "$FLUTTER_HOME"
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_HOME"
else
  echo "==> Flutter already present at $FLUTTER_HOME"
fi
export PATH="$PATH:$FLUTTER_HOME/bin"

# --- Flutter setup ---
echo "==> Flutter setup"
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter --version
# Force CocoaPods plugin integration for this project in cloud CI.
flutter config --no-enable-swift-package-manager
flutter precache --ios
flutter pub get

# --- Vendor patch (local/China only; skip on Xcode Cloud) ---
# prepare_ios_build.sh may clone mirror repos; avoid that on cloud builders.
IS_XCODE_CLOUD="false"
if [ -n "${CI_XCODE_CLOUD:-}" ] || [ "${CI_XCODECLOUD:-}" = "TRUE" ] || [ -n "${CI_WORKSPACE:-}" ]; then
  IS_XCODE_CLOUD="true"
fi

if [ "$IS_XCODE_CLOUD" = "true" ]; then
  echo "==> Xcode Cloud: skip Vendor patch (GitHub SPM)"
else
  echo "==> Prepare iOS vendor deps"
  bash tool/prepare_ios_build.sh
fi

# --- CocoaPods ---
echo "==> CocoaPods"
cd ios
pod install

echo "==> ci_post_clone done"
