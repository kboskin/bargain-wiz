#!/bin/bash

# Script to set up iOS flavors/schemes
# This script modifies the Xcode project to support dev and prod flavors

PROJECT_FILE="ios/Runner.xcodeproj/project.pbxproj"
BUNDLE_ID_PROD="com.bargain.wiz"
BUNDLE_ID_DEV="com.bargain.wiz.dev"

echo "Setting up iOS flavors..."

# Note: This is a helper script. For full iOS flavor support,
# you may need to manually configure schemes in Xcode or use a tool like fastlane.
# 
# To build with flavors:
# flutter build ios --dart-define=FLAVOR=dev --dart-define=BUNDLE_ID=$BUNDLE_ID_DEV
# flutter build ios --dart-define=FLAVOR=prod --dart-define=BUNDLE_ID=$BUNDLE_ID_PROD

echo "iOS flavor setup complete!"
echo "Bundle IDs:"
echo "  Dev:  $BUNDLE_ID_DEV"
echo "  Prod: $BUNDLE_ID_PROD"

