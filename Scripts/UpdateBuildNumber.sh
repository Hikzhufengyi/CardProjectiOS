#!/bin/sh
set -eu

BUILD_NUMBER="${CURRENT_PROJECT_VERSION:-$(date +%Y%m%d)01}"
PLIST_PATH="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [ -f "$PLIST_PATH" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "$PLIST_PATH"
fi
