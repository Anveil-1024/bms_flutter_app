#!/bin/sh
# Xcode Cloud: runs before xcodebuild Archive, syncs Flutter build settings.
set -e

FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
export PATH="$PATH:$FLUTTER_HOME/bin"
cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "==> Sync Flutter iOS build configuration"
if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found in PATH ($PATH)"
  exit 1
fi

flutter --version

# --no-codesign avoids prebuild signing checks in cloud pre-build stage.
flutter build ios --config-only --release --no-codesign

echo "==> ci_pre_xcodebuild done"
