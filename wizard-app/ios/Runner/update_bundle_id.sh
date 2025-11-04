#!/bin/bash

# Script to update bundle ID based on flavor
# This script is called during the iOS build process

PLIST_FILE="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
BUNDLE_ID="${PRODUCT_BUNDLE_IDENTIFIER}"

# If FLAVOR is set via dart-define, use it
if [ -n "$FLAVOR" ] && [ "$FLAVOR" == "dev" ]; then
    BUNDLE_ID="com.bargain.wiz.dev"
fi

# Update the bundle ID in Info.plist if it exists
if [ -f "$PLIST_FILE" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST_FILE" 2>/dev/null || true
fi

echo "Bundle ID set to: $BUNDLE_ID"

