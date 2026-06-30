#!/bin/sh
# Xcode Cloud: runs before xcodebuild Archive, syncs Flutter build settings.
set -e

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-${CI_WORKSPACE:-.}}"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"

if [ -f "$REPO_ROOT/ios/ci_scripts/ci_env.sh" ]; then
  # shellcheck source=/dev/null
  . "$REPO_ROOT/ios/ci_scripts/ci_env.sh"
fi

export PATH="$PATH:$FLUTTER_HOME/bin"

echo "==> Environment"
echo "REPO_ROOT=$REPO_ROOT"
echo "FLUTTER_HOME=$FLUTTER_HOME"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  echo "ERROR: flutter not found at $FLUTTER_HOME/bin/flutter"
  echo "ci_post_clone.sh may have failed or FLUTTER_HOME was not preserved."
  exit 1
fi

cd "$REPO_ROOT"

echo "==> Sync Flutter iOS build configuration"
# --no-codesign: Xcode Cloud has no dev cert during this step; signing is done by xcodebuild Archive.
flutter build ios --config-only --release --no-codesign

echo "==> ci_pre_xcodebuild done"
