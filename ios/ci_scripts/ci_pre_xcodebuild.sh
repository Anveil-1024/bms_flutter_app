#!/bin/sh
# Xcode Cloud: runs before xcodebuild Archive, syncs Flutter build settings.
set -e

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-${CI_WORKSPACE:-$PWD}}"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
export PATH="$PATH:$FLUTTER_HOME/bin"

echo "==> Environment"
echo "REPO_ROOT=$REPO_ROOT"
echo "FLUTTER_HOME=$FLUTTER_HOME"
echo "CI_XCODECLOUD=${CI_XCODECLOUD:-<unset>}"

if [ ! -d "$REPO_ROOT" ]; then
  echo "error: repository path not found: $REPO_ROOT"
  exit 1
fi
cd "$REPO_ROOT"

echo "==> Validate Flutter environment"
if ! command -v flutter >/dev/null 2>&1; then
  echo "==> Flutter not found, installing stable channel"
  rm -rf "$FLUTTER_HOME"
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_HOME"
  export PATH="$PATH:$FLUTTER_HOME/bin"
fi

flutter --version

# Keep Generated.xcconfig in sync without invoking flutter iOS build.
# In Xcode Cloud, `flutter build ios --config-only` may trigger experimental
# SPM integration and fail when automatic package resolution is disabled.
flutter pub get
if [ ! -f "ios/Flutter/Generated.xcconfig" ]; then
  echo "error: ios/Flutter/Generated.xcconfig not found after flutter pub get"
  exit 1
fi

echo "==> ci_pre_xcodebuild done"
