#!/bin/sh
# Xcode Cloud: runs after the repository is cloned, before Xcode builds.
set -e

echo "==> Environment"
echo "CI_PRIMARY_REPOSITORY_PATH=${CI_PRIMARY_REPOSITORY_PATH:-<unset>}"
echo "CI_XCODECLOUD=${CI_XCODECLOUD:-<unset>}"

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
flutter precache --ios
flutter pub get

# --- Vendor patch (local/China only; skip on Xcode Cloud) ---
# prepare_ios_build.sh clones from gitee.com which fails on Apple CI (git exit 128).
# Xcode Cloud can reach GitHub directly, so file_picker SPM deps work without patching.
if [ "${CI_XCODECLOUD:-}" = "TRUE" ]; then
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
