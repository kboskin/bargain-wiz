# Versioning Guide

This project uses **symmetric versioning** for both Android and iOS platforms.

## Version Format

- **Base Version**: `MAJOR.MINOR.PATCH` (e.g., `1.0.0`)
- **Build Number**: Integer that increments with each build (e.g., `1`)
- **Full Version**: `1.0.0+1` (version+build)

## Flavor-Specific Versions

### Dev Flavor
- **Version Name**: `1.0.0-dev` (adds `-dev` suffix)
- **Version Code/Build**: `1`
- **Full Version**: `1.0.0-dev+1`

### Prod Flavor
- **Version Name**: `1.0.0` (no suffix)
- **Version Code/Build**: `1`
- **Full Version**: `1.0.0+1`

## Version Files

The version is managed in multiple places to ensure consistency:

1. **`pubspec.yaml`** - Source of truth for base version and build number
   ```yaml
   version: 1.0.0+1
   ```

2. **Android** (`android/app/build.gradle.kts`)
   - Base version from `pubspec.yaml` (via Flutter plugin)
   - Dev flavor adds `versionNameSuffix = "-dev"`

3. **iOS** (`ios/Flutter/Dev.xcconfig` and `ios/Flutter/Prod.xcconfig`)
   - Dev: `FLUTTER_BUILD_NAME=1.0.0-dev`
   - Prod: `FLUTTER_BUILD_NAME=1.0.0`

## Updating Version

### Option 1: Manual Update (Recommended)

1. Update `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2
   ```

2. Update iOS config files:
   - `ios/Flutter/Prod.xcconfig`: `FLUTTER_BUILD_NAME=1.0.1` and `FLUTTER_BUILD_NUMBER=2`
   - `ios/Flutter/Dev.xcconfig`: `FLUTTER_BUILD_NAME=1.0.1-dev` and `FLUTTER_BUILD_NUMBER=2`

3. Android will automatically pick up the version from `pubspec.yaml`

### Option 2: Using Script

```bash
# Update version to 1.0.1 with build number 2
./scripts/update_version.sh 1.0.1 2
```

This script updates:
- `pubspec.yaml` (source of truth)
- iOS Dev and Prod xcconfig files

## Version Synchronization

Both platforms follow the same rules:

| Platform | Dev Flavor | Prod Flavor |
|----------|-----------|-------------|
| **Android** | `versionName` + `-dev` suffix | `versionName` (no suffix) |
| **iOS** | `FLUTTER_BUILD_NAME` with `-dev` | `FLUTTER_BUILD_NAME` (no suffix) |
| **Build Number** | Same for both flavors | Same for both flavors |

## Versioning Rules

1. **Version Name** (`versionName` / `FLUTTER_BUILD_NAME`):
   - Prod: Base version (e.g., `1.0.0`)
   - Dev: Base version + `-dev` suffix (e.g., `1.0.0-dev`)

2. **Version Code** (`versionCode` / `FLUTTER_BUILD_NUMBER`):
   - Same integer for both flavors
   - Must increment for each release
   - Used for app store submission

3. **Synchronization**:
   - Both platforms use the same base version
   - Both platforms add the same `-dev` suffix for dev flavor
   - Build numbers are identical across platforms and flavors

## Examples

### Example 1: Initial Release
- Base: `1.0.0+1`
- Dev: `1.0.0-dev+1`
- Prod: `1.0.0+1`

### Example 2: Patch Update
- Base: `1.0.1+2`
- Dev: `1.0.1-dev+2`
- Prod: `1.0.1+2`

### Example 3: Minor Update
- Base: `1.1.0+3`
- Dev: `1.1.0-dev+3`
- Prod: `1.1.0+3`

## Verification

To verify versions are synchronized:

```bash
# Check Android version
grep "versionName" android/app/build.gradle.kts

# Check iOS versions
grep "FLUTTER_BUILD_NAME" ios/Flutter/*.xcconfig

# Check pubspec version
grep "^version:" pubspec.yaml
```

All should reflect the same base version, with dev flavor having the `-dev` suffix.

