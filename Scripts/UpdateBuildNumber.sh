#!/bin/sh
set -eu

BUILD_DATE="$(date +%Y%m%d)"
PLIST_PATH="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [ -f "$PLIST_PATH" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_DATE}" "$PLIST_PATH"
fi
