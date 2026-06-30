#!/bin/sh
# Xcode Cloud: runs before xcodebuild Archive, syncs Flutter build settings.
set -e

FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
export PATH="$PATH:$FLUTTER_HOME/bin"
cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "==> Sync Flutter iOS build configuration"
flutter build ios --config-only --release

echo "==> ci_pre_xcodebuild done"
