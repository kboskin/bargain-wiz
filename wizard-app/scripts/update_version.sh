#!/bin/bash

# Script to update version across all platforms
# Usage: ./scripts/update_version.sh <version> <build_number>
# Example: ./scripts/update_version.sh 1.0.1 2

set -e

VERSION_NAME="${1:-1.0.0}"
VERSION_CODE="${2:-1}"

if [ -z "$1" ]; then
    echo "Usage: $0 <version_name> <version_code>"
    echo "Example: $0 1.0.1 2"
    exit 1
fi

echo "Updating version to $VERSION_NAME ($VERSION_CODE)..."

# Update pubspec.yaml (source of truth)
sed -i '' "s/^version: .*/version: $VERSION_NAME+$VERSION_CODE/" pubspec.yaml

# Update iOS xcconfig files
sed -i '' "s/FLUTTER_BUILD_NAME=.*/FLUTTER_BUILD_NAME=$VERSION_NAME/" ios/Flutter/Prod.xcconfig
sed -i '' "s/FLUTTER_BUILD_NUMBER=.*/FLUTTER_BUILD_NUMBER=$VERSION_CODE/" ios/Flutter/Prod.xcconfig
sed -i '' "s/FLUTTER_BUILD_NAME=.*/FLUTTER_BUILD_NAME=$VERSION_NAME-dev/" ios/Flutter/Dev.xcconfig
sed -i '' "s/FLUTTER_BUILD_NUMBER=.*/FLUTTER_BUILD_NUMBER=$VERSION_CODE/" ios/Flutter/Dev.xcconfig

echo "✅ Version updated successfully!"
echo "   Version Name: $VERSION_NAME"
echo "   Version Code: $VERSION_CODE"
echo "   Dev Version: $VERSION_NAME-dev"
echo "   Prod Version: $VERSION_NAME"

