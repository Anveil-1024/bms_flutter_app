#!/bin/sh
# Xcode Cloud: runs after the repository is cloned, before Xcode builds.
# Installs Flutter, resolves Dart/CocoaPods deps, and patches file_picker SPM.
set -e

echo "==> Install Flutter (stable)"
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

echo "==> Flutter setup"
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter --version
flutter precache --ios
flutter pub get

echo "==> Prepare iOS vendor deps (DKImagePickerController)"
bash tool/prepare_ios_build.sh

echo "==> CocoaPods"
cd ios
pod install

echo "==> ci_post_clone done"
