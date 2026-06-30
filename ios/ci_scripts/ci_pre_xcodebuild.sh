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

echo "==> Sync Flutter iOS build configuration"
if ! command -v flutter >/dev/null 2>&1; then
  echo "==> Flutter not found, installing stable channel"
  rm -rf "$FLUTTER_HOME"
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_HOME"
  export PATH="$PATH:$FLUTTER_HOME/bin"
fi

flutter --version

# --no-codesign avoids prebuild signing checks in cloud pre-build stage.
flutter build ios --config-only --release --no-codesign

echo "==> ci_pre_xcodebuild done"
