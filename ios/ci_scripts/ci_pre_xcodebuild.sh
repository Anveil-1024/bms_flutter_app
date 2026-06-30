#!/bin/sh
# Xcode Cloud: runs before xcodebuild Archive, syncs Flutter build settings.
set -e

export PATH="$PATH:$HOME/flutter/bin"
cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "==> Sync Flutter iOS build configuration"
flutter build ios --config-only --release

echo "==> ci_pre_xcodebuild done"
