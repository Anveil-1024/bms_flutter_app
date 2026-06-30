#!/bin/bash
# 修复 iOS SPM：file_picker 依赖 GitHub 上的 DKImagePickerController，
# 国内网络常失败。改为使用本地 Vendor 副本。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/ios/Vendor/DKImagePickerController"
PKG="$ROOT/ios/Flutter/ephemeral/Packages/.packages/file_picker-"*/Package.swift

clone_vendor() {
  mkdir -p "$ROOT/ios/Vendor"
  echo "Cloning DKImagePickerController to ios/Vendor..."
  # Prefer GitHub (works on Xcode Cloud / overseas); fall back to gitee mirror for China.
  if git clone --depth 1 --branch 4.3.9 \
      https://github.com/zhangao0086/DKImagePickerController.git "$VENDOR"; then
    return 0
  fi
  echo "GitHub clone failed, trying gitee mirror..."
  rm -rf "$VENDOR"
  git clone --depth 1 --branch 4.3.9 \
    https://gitee.com/mirrors/DKImagePickerController.git "$VENDOR"
}

if [ ! -d "$VENDOR" ]; then
  clone_vendor
fi

shopt -s nullglob
files=($PKG)
shopt -u nullglob

if [ ${#files[@]} -eq 0 ]; then
  echo "file_picker Package.swift not found; run 'flutter pub get' first."
  exit 1
fi

for f in "${files[@]}"; do
  if grep -q 'github.com/zhangao0086/DKImagePickerController' "$f"; then
    sed -i '' 's|.package(url: "https://github.com/zhangao0086/DKImagePickerController", branch: "4.3.9")|.package(path: "../../../../../Vendor/DKImagePickerController")|' "$f"
    echo "Patched: $f"
  fi
done
